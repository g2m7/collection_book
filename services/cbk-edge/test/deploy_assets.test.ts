import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const deployDirectory = join(import.meta.dir, "..", "deploy", "v1");

function readDeployFile(relativePath: string): string {
  return readFileSync(join(deployDirectory, relativePath), "utf8");
}

const unit = readDeployFile("cbk-edge.service");
const environmentExample = readDeployFile("cbk-edge.env.example");
const httpVhost = readDeployFile("nginx/cbk.sarbaa.com.http.conf");
const httpsTemplate = readDeployFile(
  "nginx/cbk.sarbaa.com.https.conf.template",
);
const runbook = readDeployFile("README.md");

function countOccurrences(haystack: string, needle: string): number {
  return haystack.split(needle).length - 1;
}

describe("systemd unit", () => {
  test("runs the Bun adapter as an unprivileged user on loopback", () => {
    expect(unit).toContain("User=cbk-edge");
    expect(unit).toContain("Group=cbk-edge");
    expect(unit).toContain("Environment=CBK_EDGE_HOST=127.0.0.1");
    expect(unit).toContain("Environment=CBK_EDGE_PORT=8787");
    expect(unit).toMatch(
      /ExecStart=\S*bun run \S*services\/cbk-edge\/src\/vps_server\.ts/u,
    );
    expect(unit).toContain("Restart=on-failure");
  });

  test("reads its configuration from a root-owned environment file", () => {
    expect(unit).toContain("EnvironmentFile=/etc/cbk-edge/cbk-edge.env");
    expect(countOccurrences(unit, "EnvironmentFile=")).toBe(1);
  });

  test("applies baseline hardening and has an install target", () => {
    for (const directive of [
      "NoNewPrivileges=true",
      "PrivateTmp=true",
      "ProtectSystem=strict",
      "ProtectHome=true",
      "RestrictSUIDSGID=true",
    ]) {
      expect(unit).toContain(directive);
    }
    expect(unit).toContain("WantedBy=multi-user.target");
  });

  test("declares each required section exactly once and is bracket balanced", () => {
    for (const section of ["[Unit]", "[Service]", "[Install]"]) {
      expect(countOccurrences(unit, section)).toBe(1);
    }
    expect(countOccurrences(unit, "[")).toBe(countOccurrences(unit, "]"));
  });
});

describe("environment example", () => {
  test("ships no secret values and keeps the Play listing opt-in", () => {
    const activeLines = environmentExample
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line !== "" && !line.startsWith("#"));

    expect(activeLines).toEqual([]);
    expect(environmentExample).toContain("#PLAY_STORE_URL=");
    expect(environmentExample).toContain("telemetry_unavailable");
  });

  test("documents the signing fingerprint without shipping a value", () => {
    expect(environmentExample).toContain("#ANDROID_SHA256_CERT_FINGERPRINT=");
    expect(environmentExample).not.toMatch(/^[A-Z0-9]{2}(:[A-Z0-9]{2}){31}$/mu);
    expect(environmentExample).toContain("answers []");
    expect(environmentExample).toContain("keytool -list -v");
  });
});

describe("nginx http vhost (stage 1)", () => {
  test("proxies to the loopback adapter with safe headers and timeouts", () => {
    expect(httpVhost).toContain("server_name cbk.sarbaa.com");
    expect(httpVhost).toContain("listen 80;");
    expect(httpVhost).toContain("proxy_pass http://127.0.0.1:8787;");
    expect(httpVhost).toContain("proxy_set_header X-Forwarded-Proto $scheme;");
    expect(httpVhost).toContain("proxy_set_header X-Real-IP $remote_addr;");
    expect(httpVhost).toContain("proxy_connect_timeout 5s;");
    expect(httpVhost).toContain("proxy_read_timeout 15s;");
    expect(httpVhost).toContain("client_max_body_size 128k;");
    expect(httpVhost).toContain("/.well-known/acme-challenge/");
  });

  test("contains no certificate path before Certbot provisions one", () => {
    expect(httpVhost).not.toContain("ssl_certificate");
    expect(httpVhost).not.toContain("listen 443");
    expect(httpVhost).not.toContain(".pem");
  });

  test("is structurally balanced so `nginx -t` can parse it", () => {
    expect(countOccurrences(httpVhost, "{")).toBe(
      countOccurrences(httpVhost, "}"),
    );
    expect(countOccurrences(httpVhost, "server {")).toBe(1);
  });
});

describe("nginx https template (stage 2)", () => {
  test("keeps certificate paths as placeholders that must be rendered", () => {
    expect(httpsTemplate).toContain("ssl_certificate __CERTBOT_FULLCHAIN__;");
    expect(httpsTemplate).toContain("ssl_certificate_key __CERTBOT_PRIVKEY__;");
    expect(httpsTemplate).toContain("listen 443 ssl http2;");
    expect(httpsTemplate).toContain("listen [::]:443 ssl http2;");
    expect(httpsTemplate).not.toContain("http2 on;");
    expect(httpsTemplate).toContain(
      "return 301 https://cbk.sarbaa.com$request_uri;",
    );
    expect(httpsTemplate).toContain("proxy_pass http://127.0.0.1:8787;");
  });

  test("redirects to the literal host instead of the request Host header", () => {
    expect(httpsTemplate).not.toContain("https://$host");
    expect(httpsTemplate).toContain("open redirect");
  });

  test("does not duplicate the HSTS header the handler already sends", () => {
    expect(httpsTemplate).not.toContain("add_header");
    expect(httpsTemplate).toContain("No Strict-Transport-Security here");
  });

  test("is a template that is never installed verbatim", () => {
    expect(httpsTemplate).toContain("template on purpose");
    expect(countOccurrences(httpsTemplate, "{")).toBe(
      countOccurrences(httpsTemplate, "}"),
    );
  });
});

describe("deployment runbook", () => {
  test("documents the two-stage bring-up and the pending external work", () => {
    expect(runbook).toContain("Stage 1");
    expect(runbook).toContain("Stage 2");
    expect(runbook).toContain("certbot certonly --webroot");
    expect(runbook).toContain("nginx -t");
    expect(runbook).toContain("systemd-analyze verify");
    expect(runbook).toContain("Nothing in this directory has been applied");
  });

  test("requires a clean committed checkout before the release copy", () => {
    expect(runbook).toContain("git status --porcelain");
    expect(runbook).toContain("clean, committed");
    expect(runbook.indexOf("git status --porcelain")).toBeLessThan(
      runbook.indexOf("rsync -a --delete"),
    );
  });

  test("excludes local and build directories from the release copy", () => {
    for (const exclusion of [
      "--exclude '.git/'",
      "--exclude 'build/'",
      "--exclude '.dart_tool/'",
      "--exclude 'node_modules/'",
    ]) {
      expect(runbook).toContain(exclusion);
    }
  });

  test("renders the stage 2 vhost through sudo tee and deletes no file", () => {
    expect(runbook).toContain(
      "| sudo tee /etc/nginx/sites-available/cbk.sarbaa.com",
    );
    expect(runbook).toContain("cbk.sarbaa.com.https.conf.template \\");
    // A plain `>` runs as the unprivileged operator and would leave the old
    // vhost in place, and the stage 1 file no longer needs removing because
    // both stages install to the same target.
    expect(runbook).not.toMatch(
      /^\s*>\s*\/etc\/nginx\/sites-available\/cbk\.sarbaa\.com\s*$/mu,
    );
    expect(runbook).not.toMatch(/^\s*sudo rm\b/mu);
  });

  test("states the telemetry limitation instead of hiding it", () => {
    expect(runbook).toContain("503 telemetry_unavailable");
    expect(runbook).toContain('"keep the queue"');
  });

  test("documents what the plain-HTTP stage cannot do", () => {
    expect(runbook).toContain("What stage 1 cannot do");
    expect(runbook).toContain("browser discards it on an");
    expect(runbook).toContain("App Links need HTTPS");
  });
});
