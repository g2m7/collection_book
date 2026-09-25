# cbk-edge VPS deployment (version 1)

Example deployment assets for hosting `cbk.sarbaa.com` on the existing Linode
VPS with nginx and Bun, **without** moving the `sarbaa.com` zone to Cloudflare.

Nothing in this directory has been applied to any machine. Every command below
is an operator action that still has to be run, reviewed, and approved.

- `cbk-edge.service` — systemd unit for the Bun adapter (`vps_server.ts`).
- `cbk-edge.env.example` — non-secret environment template.
- `nginx/cbk.sarbaa.com.http.conf` — stage 1, plain HTTP only.
- `nginx/cbk.sarbaa.com.https.conf.template` — stage 2, placeholders only.

## Shape of the deployment

```text
browser --HTTPS--> nginx (public :80/:443) --HTTP--> Bun on 127.0.0.1:8787 --> handleRequest
```

The Bun process binds loopback only, is reached through the system nginx, and
runs exactly the same `handleRequest` code path as the Cloudflare Worker, so
route behavior, security headers, and cache policy are identical.

## Prerequisites (all currently pending)

1. Bun 1.3.4 installed at `/opt/cbk-edge/runtime/bun-1.3.4/bun`, matching
   the pinned `ExecStart`. Download the official `bun-linux-x64.zip` and
   `SHASUMS256.txt` release assets, verify the archive checksum, extract it to
   a temporary directory, install the binary mode `0755`, then verify
   `/opt/cbk-edge/runtime/bun-1.3.4/bun --version` prints `1.3.4`. Do not
   replace the VPS-wide Bun runtime used by unrelated applications.
2. An A record for `cbk` in the Linode-hosted `sarbaa.com` zone pointing at the
   VPS address. The zone stays on its current authoritative DNS; only this one
   subdomain is added. `dig cbk.sarbaa.com` must resolve before Certbot runs.
3. The repository checked out to the server, including `packages/contracts`,
   and `bun install --frozen-lockfile` run there, because the adapter imports
   the workspace contracts package. **The checkout must be a clean, committed
   state before you copy it**: the release is a copy of the working tree, not
   of a commit, so `git status --porcelain` must be empty or an uncommitted
   local edit would be the version that goes live.
4. A public Google Play listing, if and only if a live download button should
   appear. Until then leave `PLAY_STORE_URL` empty and the site shows the honest
   "Google Play release in progress" panel.

## 1. Place a versioned release and link `current`

```sh
sudo useradd --system --no-create-home --shell /usr/sbin/nologin cbk-edge
CHECKOUT=/path/to/checkout
[ -z "$(git -C "$CHECKOUT" status --porcelain)" ] || {
  echo "Refusing to deploy a dirty checkout" >&2
  exit 1
}
git -C "$CHECKOUT" rev-parse --short HEAD
RELEASE=/opt/cbk-edge/releases/$(git -C "$CHECKOUT" rev-parse --short HEAD)
sudo mkdir -p "$RELEASE"
# Only the Bun workspace is served. The exclusions below drop the git
# directory, the Flutter working files, and the Gradle and CocoaPods caches.
# --delete-excluded also removes any stale excluded file from a reused release.
sudo rsync -a --delete --delete-excluded \
  --exclude '.git/' --exclude '.idea/' --exclude '.DS_Store' --exclude '*.iml' \
  --exclude 'build/' --exclude '.dart_tool/' --exclude '.flutter-plugins-dependencies' \
  --exclude 'android/.gradle/' --exclude 'android/app/build/' --exclude 'android/build/' \
  --exclude 'ios/Pods/' --exclude 'ios/.symlinks/' \
  --exclude 'node_modules/' --exclude 'doc/api/' \
  "$CHECKOUT/" "$RELEASE/"
sudo chown -R cbk-edge:cbk-edge "$RELEASE"
# Installs the workspace dependency (@collection-book/contracts) the adapter
# imports. Runs here, outside the systemd sandbox, as the service user.
sudo -u cbk-edge bun install --frozen-lockfile --cwd "$RELEASE"
sudo ln -sfn "$RELEASE" /opt/cbk-edge/current
```

Keep old `releases/` directories until the new one is verified; rolling back is
`ln -sfn` plus a restart. The service only ever reads from `/opt/cbk-edge`.

## 2. Install the environment file and the unit

```sh
sudo install -d -m 0750 -o root -g cbk-edge /etc/cbk-edge
sudo install -m 0640 -o root -g cbk-edge \
  services/cbk-edge/deploy/v1/cbk-edge.env.example /etc/cbk-edge/cbk-edge.env
sudoedit /etc/cbk-edge/cbk-edge.env          # set PLAY_STORE_URL only when the listing is public
sudo install -m 0644 services/cbk-edge/deploy/v1/cbk-edge.service \
  /etc/systemd/system/cbk-edge.service
sudo systemd-analyze verify /etc/systemd/system/cbk-edge.service
sudo systemctl daemon-reload
sudo systemctl enable --now cbk-edge
sudo systemctl status cbk-edge
curl -fsS http://127.0.0.1:8787/health
```

`PLAY_STORE_URL` and `ANDROID_SHA256_CERT_FINGERPRINT` are read from
`/etc/cbk-edge/cbk-edge.env` by the adapter itself, so a change needs only
`sudo systemctl restart cbk-edge`. Set the fingerprint to the `SHA256` value of
the release signing key you actually ship, read with
`keytool -list -v -keystore <keystore> -alias <alias>`; never the debug key. A
missing, blank, or malformed value leaves
`/.well-known/assetlinks.json` answering `[]`, which keeps the App Link
unverified rather than advertising a wrong certificate.

`cbk-edge.env` holds no secrets today. If a value is ever added, keep the file
at `0640 root:cbk-edge` and never commit it. Only `GET` is answered, so probe
the service with `curl ... -o /dev/null -w '%{http_code}'` rather than `curl -I`.

## 3. Stage 1 — plain HTTP

```sh
sudo install -m 0644 services/cbk-edge/deploy/v1/nginx/cbk.sarbaa.com.http.conf \
  /etc/nginx/sites-available/cbk.sarbaa.com
sudo ln -sfn /etc/nginx/sites-available/cbk.sarbaa.com \
  /etc/nginx/sites-enabled/cbk.sarbaa.com
sudo nginx -t && sudo systemctl reload nginx
curl -fsS -H 'Host: cbk.sarbaa.com' http://127.0.0.1/health
```

This is the only configuration that is active before a certificate exists. It
contains no `ssl_certificate` directive on purpose, so nginx can serve the
ACME challenge and the site is reachable over HTTP before TLS exists.

### What stage 1 cannot do

Plain HTTP is a bring-up step, not a usable App Link target, and the limitation
is expected rather than a misconfiguration:

- `/r/{code}` still answers `302` and still logs the click, but the
  `cbk_referral` cookie is set with `Secure`, so a browser discards it on an
  `http://` page. The code still reaches the Play `referrer` parameter through
  the `?ref=` query, but the 30-day cookie does not persist until TLS exists.
- Android App Links need HTTPS and a verified `assetlinks.json`, so `/import`
  and `/r/{code}` will not open the app from a link in stage 1.
- HSTS is only sent over HTTPS, so a browser has no upgrade protection yet.

Do not run production smoke checks until stage 2 is in place.

## 4. Stage 2 — Certbot, then the HTTPS vhost

```sh
sudo certbot certonly --webroot -w /var/www/html -d cbk.sarbaa.com
sudo sed -e "s|__CERTBOT_FULLCHAIN__|/etc/letsencrypt/live/cbk.sarbaa.com/fullchain.pem|" \
        -e "s|__CERTBOT_PRIVKEY__|/etc/letsencrypt/live/cbk.sarbaa.com/privkey.pem|" \
  /opt/cbk-edge/current/services/cbk-edge/deploy/v1/nginx/cbk.sarbaa.com.https.conf.template \
  | sudo tee /etc/nginx/sites-available/cbk.sarbaa.com > /dev/null
sudo nginx -t && sudo systemctl reload nginx
```

The rendered file overwrites the stage 1 vhost in place: both stages install to
`/etc/nginx/sites-available/cbk.sarbaa.com`, so there is no second file to
remove and only one block can claim `server_name cbk.sarbaa.com`. Writing it
through `sudo tee` matters because the shell runs as your own user: a plain `>`
redirection would fail on the root-owned directory and leave nginx reloading the
old vhost. The redirect from port 80 targets the literal `cbk.sarbaa.com` rather
than `$host`, so a spoofed `Host` header cannot turn it into an open redirect.
`Strict-Transport-Security` is set by the Bun handler on every proxied response,
so the vhost deliberately does not add it again.

Stage 2 keeps a port-80 block that serves `/.well-known/acme-challenge/` and
redirects everything else to HTTPS, so certificate renewals keep working.

## 5. Smoke checks after the cutover

```sh
# The handler answers GET only (HEAD is a 405), so check status with -w.
curl -sS -o /dev/null -w '%{http_code}\n' https://cbk.sarbaa.com/health          # 200
curl -sS  https://cbk.sarbaa.com/ | head -c 200
curl -sS  https://cbk.sarbaa.com/privacy | head -c 200
curl -sS -D- -o /dev/null https://cbk.sarbaa.com/r/AB12CD                       # 302 + Set-Cookie
curl -sS -o /dev/null -w '%{http_code}\n' https://cbk.sarbaa.com/r/AB12C        # 404
curl -sS -o /dev/null -w '%{http_code}\n' -X POST https://cbk.sarbaa.com/       # 405
curl -sS  https://cbk.sarbaa.com/.well-known/assetlinks.json                     # [] until ANDROID_SHA256_CERT_FINGERPRINT holds a real value
curl -sS -o /dev/null -w '%{http_code}\n' -X POST https://cbk.sarbaa.com/api/v1/telemetry/batch  # 503, see below
sudo journalctl -u cbk-edge --since '-10m' --no-pager
```

## Known limitation: telemetry on the Bun adapter

`TELEMETRY` is a Cloudflare Analytics Engine binding. The Bun adapter has no
equivalent, so it deliberately leaves the binding undefined and
`POST /api/v1/telemetry/batch` answers `503 telemetry_unavailable` with
`Retry-After: 60` and this body:

```json
{"error":"telemetry_unavailable"}
```

The Android app treats a failed flush as "keep the queue" and retries later, so
no event is lost; nothing is silently accepted and dropped. Event ingestion on
the VPS needs a separate, explicitly approved storage decision (a bounded local
sink is the obvious option) and is not part of this deployment.

## Rollback

```sh
sudo ln -sfn /opt/cbk-edge/releases/<previous> /opt/cbk-edge/current
sudo systemctl restart cbk-edge
```

If the cutover is not healthy, remove the nginx symlink, `nginx -t`, reload, and
the previous site keeps serving.
