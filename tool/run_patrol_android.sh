#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tool/run_patrol_android.sh [--device DEVICE_ID] [Patrol arguments...]

Wakes one Android device, temporarily prevents its display timeout during the
Patrol run, and restores the original timeout on every exit. Without
--device, exactly one connected Android device must be available.
EOF
}

requested_device=""
if [[ "${1:-}" == "--device" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "Error: --device requires a device id." >&2
    usage >&2
    exit 64
  fi
  requested_device="$2"
  shift 2
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "Error: adb is required." >&2
  exit 69
fi
if ! command -v patrol >/dev/null 2>&1; then
  echo "Error: Patrol CLI is required." >&2
  exit 69
fi

if [[ -n "$requested_device" ]]; then
  device_state="$(adb -s "$requested_device" get-state 2>/dev/null || true)"
  if [[ "$device_state" != "device" ]]; then
    echo "Error: requested Android device '$requested_device' is not connected and ready." >&2
    exit 69
  fi
  device="$requested_device"
else
  connected_devices=()
  connected_device_count=0
  while IFS=$'\t' read -r device_id device_state _; do
    if [[ "$device_state" == "device" ]]; then
      connected_devices+=("$device_id")
      connected_device_count=$((connected_device_count + 1))
    fi
  done < <(adb devices)

  case "$connected_device_count" in
    0)
      echo "Error: no connected Android device is available." >&2
      exit 69
      ;;
    1)
      device="${connected_devices[0]}"
      ;;
    *)
      echo "Error: multiple Android devices are connected; select one with --device." >&2
      printf '  %s\n' "${connected_devices[@]}" >&2
      exit 69
      ;;
  esac
fi

original_timeout="$(adb -s "$device" shell settings get system screen_off_timeout | tr -d '\r')"
if [[ ! "$original_timeout" =~ ^[0-9]+$ ]]; then
  echo "Error: could not read screen_off_timeout from '$device' (got '$original_timeout')." >&2
  exit 69
fi

patrol_pid=""
patrol_timeout=2147483647

read_timeout() {
  adb -s "$device" shell settings get system screen_off_timeout | tr -d '\r'
}

write_timeout() {
  adb -s "$device" shell settings put system screen_off_timeout "$1" >/dev/null
}

stop_test_processes() {
  for package in \
    com.sarbaa.cbk \
    com.sarbaa.cbk.test \
    androidx.test.orchestrator \
    androidx.test.services; do
    adb -s "$device" shell am force-stop "$package" >/dev/null 2>&1 || true
  done
}

cleanup() {
  local exit_code=$?
  local cleanup_failed=0
  trap - EXIT INT TERM HUP
  if [[ -n "$patrol_pid" ]] && kill -0 "$patrol_pid" >/dev/null 2>&1; then
    kill "$patrol_pid" >/dev/null 2>&1 || true
    wait "$patrol_pid" 2>/dev/null || true
  fi
  stop_test_processes
  if ! write_timeout "$original_timeout"; then
    echo "Error: failed to restore screen_off_timeout on $device." >&2
    cleanup_failed=1
  else
    local restored_timeout=""
    restored_timeout="$(read_timeout 2>/dev/null || true)"
    if [[ "$restored_timeout" != "$original_timeout" ]]; then
      echo "Error: timeout restoration read back '$restored_timeout' (expected '$original_timeout') on $device." >&2
      cleanup_failed=1
    else
      echo "Restored screen_off_timeout=$original_timeout on $device."
    fi
  fi
  if [[ "$exit_code" -eq 0 && "$cleanup_failed" -ne 0 ]]; then
    exit 74
  fi
  # A Patrol failure remains the primary status even when cleanup also fails.
  exit "$exit_code"
}
trap cleanup EXIT INT TERM HUP

# Clear instrumentation left behind by an interrupted earlier run before Patrol
# installs and starts a fresh orchestrated test session.
stop_test_processes
adb -s "$device" shell input keyevent KEYCODE_WAKEUP
# Android only dismisses an insecure keyguard through this request. A secure
# lock remains present and is rejected by the bounded trust-state check below.
adb -s "$device" shell wm dismiss-keyguard >/dev/null
if ! write_timeout "$patrol_timeout"; then
  echo "Error: failed to set screen_off_timeout on $device." >&2
  exit 69
fi
written_timeout="$(read_timeout 2>/dev/null || true)"
if [[ "$written_timeout" != "$patrol_timeout" ]]; then
  echo "Error: timeout write read back '$written_timeout' (expected '$patrol_timeout') on $device." >&2
  exit 69
fi

wakefulness=""
focus=""
device_locked=""
for _ in {1..20}; do
  wakefulness="$(adb -s "$device" shell dumpsys power | grep -m1 'mWakefulness=' | tr -d '\r' || true)"
  focus="$(adb -s "$device" shell dumpsys window | grep -m1 'mCurrentFocus=' | tr -d '\r' || true)"
  device_locked="$(adb -s "$device" shell dumpsys trust 2>/dev/null | grep -m1 -oE 'deviceLocked=[01]' | tr -d '\r' || true)"
  if [[ "$wakefulness" == *=Awake* && ! "$focus" =~ (Keyguard|LockScreen) && "$device_locked" == "deviceLocked=0" ]]; then
    break
  fi
  sleep 0.25
done
if [[ "$wakefulness" != *=Awake* || "$focus" =~ (Keyguard|LockScreen) || "$device_locked" != "deviceLocked=0" ]]; then
  echo "Error: '$device' did not reach an awake, unlocked state (${wakefulness:-unknown wakefulness}; ${focus:-unknown focus}; ${device_locked:-unknown trust state})." >&2
  echo "Unlock it manually; this script will not bypass a secure lock." >&2
  exit 69
fi

device_api="$(adb -s "$device" shell getprop ro.build.version.sdk | tr -d '\r')"
android_release="$(adb -s "$device" shell getprop ro.build.version.release | tr -d '\r')"
echo "Running Patrol on $device (Android $android_release, API $device_api)."
echo "Screen timeout changed from $original_timeout to $patrol_timeout for this run only."

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
patrol test --device "$device" "$@" &
patrol_pid=$!
wait "$patrol_pid"
patrol_pid=""
