import {
  androidPackageName,
  defaultPlayStoreUrl,
  parseReferralCode,
  publicOrigin,
} from "@collection-book/contracts";

export function escapeHtml(value: string): string {
  return value.replace(/[&<>'"]/gu, (character) => {
    const entities: Record<string, string> = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "'": "&#39;",
      '"': "&quot;",
    };
    return entities[character] ?? character;
  });
}

export function buildPlayStoreUrl(
  configuredUrl: string | undefined,
  referralCode: string | null,
): string {
  let url = new URL(defaultPlayStoreUrl);
  if (configuredUrl !== undefined && configuredUrl.trim() !== "") {
    try {
      const candidate = new URL(configuredUrl.trim());
      const isGooglePlayListing =
        candidate.protocol === "https:" &&
        candidate.hostname === "play.google.com" &&
        candidate.port === "" &&
        candidate.username === "" &&
        candidate.password === "" &&
        candidate.pathname === "/store/apps/details";
      if (!isGooglePlayListing) throw new Error("Google Play listing required");
      url = candidate;
    } catch {
      url = new URL(defaultPlayStoreUrl);
    }
  }

  url.searchParams.set("id", androidPackageName);
  if (referralCode !== null) {
    url.searchParams.set(
      "referrer",
      `utm_source=cbk_edge&utm_medium=referral&utm_campaign=${referralCode}`,
    );
  }
  return url.toString();
}

export function renderLandingPage(
  requestedReferral: string | null,
  configuredPlayStoreUrl: string | undefined,
): string {
  const referralCode = parseReferralCode(requestedReferral);
  const playStoreUrl = buildPlayStoreUrl(configuredPlayStoreUrl, referralCode);
  const referralMessage =
    referralCode === null
      ? ""
      : `<p class="referral-note" role="status">Referral <strong>${escapeHtml(referralCode)}</strong> is ready to carry into Google Play.</p>`;

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Collection Book is an offline-first subscriber, payment, and collection ledger for local cable TV and fiber internet operators.">
  <meta name="theme-color" content="#0b1324">
  <meta name="color-scheme" content="light">
  <meta property="og:type" content="website">
  <meta property="og:title" content="Collection Book — Your collection book, finally in order">
  <meta property="og:description" content="Track subscribers, payments, dues, and receipts even when the network is down.">
  <meta property="og:url" content="${publicOrigin}/">
  <link rel="canonical" href="${publicOrigin}/">
  <title>Collection Book — Offline billing & collection ledger</title>
  <style>
    :root{--ink:#14213d;--muted:#52627a;--paper:#fff;--canvas:#f4f7fb;--blue:#1768e5;--blue-dark:#0d4fb1;--mint:#0a806a;--mint-soft:#dff7f1;--line:#dce4ef;--shadow:0 22px 60px rgba(15,35,70,.12);--radius:24px}
    *{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--canvas);color:var(--ink);font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.55}
    a{color:inherit}.skip-link{position:fixed;left:1rem;top:1rem;z-index:10;transform:translateY(-180%);background:#fff;color:var(--blue-dark);padding:.75rem 1rem;border-radius:10px;font-weight:800}.skip-link:focus{transform:translateY(0)}
    :focus-visible{outline:3px solid #f5a524;outline-offset:4px}.shell{width:min(1120px,calc(100% - 2rem));margin-inline:auto}.site-header{display:flex;align-items:center;justify-content:space-between;padding:1.15rem 0}.brand{display:flex;align-items:center;gap:.7rem;text-decoration:none;font-weight:850;letter-spacing:-.02em}.brand-mark{display:grid;place-items:center;width:2.45rem;height:2.45rem;border-radius:12px;background:linear-gradient(145deg,#1768e5,#0a806a);color:#fff;box-shadow:0 8px 20px rgba(23,104,229,.25)}.site-header a:last-child{font-size:.94rem;font-weight:750;text-decoration:none;color:var(--blue-dark)}
    .hero{position:relative;overflow:hidden;display:grid;gap:2.5rem;align-items:center;padding:3.25rem 0 4rem}.hero:before{content:"";position:absolute;width:22rem;height:22rem;right:-12rem;top:-10rem;background:radial-gradient(circle,rgba(23,104,229,.18),transparent 68%);pointer-events:none}.eyebrow{display:inline-flex;align-items:center;gap:.5rem;margin:0 0 1rem;color:var(--mint);font-size:.78rem;font-weight:850;letter-spacing:.1em;text-transform:uppercase}.eyebrow:before{content:"";width:.55rem;height:.55rem;border-radius:50%;background:var(--mint);box-shadow:0 0 0 5px rgba(10,128,106,.12)}h1{max-width:13ch;margin:0;font-size:clamp(2.55rem,10vw,5.4rem);line-height:.98;letter-spacing:-.065em}h1 span{color:var(--blue)}h2{margin:0;font-size:clamp(1.75rem,5vw,2.5rem);line-height:1.1;letter-spacing:-.035em}.lead{max-width:62ch;margin:1.3rem 0 0;color:var(--muted);font-size:1.06rem}.actions{display:flex;flex-wrap:wrap;gap:.8rem;margin-top:1.7rem}.button{display:inline-flex;align-items:center;justify-content:center;gap:.55rem;min-height:3.25rem;padding:.8rem 1.25rem;border:2px solid transparent;border-radius:14px;background:var(--blue);color:#fff;text-decoration:none;font-weight:850;box-shadow:0 12px 24px rgba(23,104,229,.22);transition:transform .18s ease,background .18s ease,box-shadow .18s ease}.button:hover{background:var(--blue-dark);transform:translateY(-2px);box-shadow:0 16px 30px rgba(13,79,177,.25)}.button svg{width:1.2rem;height:1.2rem}.microcopy{margin:.85rem 0 0;color:var(--muted);font-size:.85rem}.referral-note{margin:1.15rem 0 0;padding:.75rem .9rem;border:1px solid #bce9de;border-radius:12px;background:var(--mint-soft);color:#075f50;font-size:.88rem}
    .phone-wrap{position:relative;width:min(100%,22rem);margin-inline:auto}.phone-wrap:before{content:"";position:absolute;inset:12% -10%;background:linear-gradient(145deg,rgba(23,104,229,.2),rgba(10,128,106,.1));filter:blur(2px);border-radius:36px;transform:rotate(3deg)}.phone{position:relative;overflow:hidden;border:9px solid #172238;border-radius:38px;background:#f7f9fc;box-shadow:var(--shadow);transform:rotate(-2deg)}.phone-top{display:flex;align-items:center;justify-content:space-between;padding:1rem 1rem .7rem;background:#fff}.phone-top strong{font-size:.78rem}.phone-top span{font-size:.65rem;color:var(--mint);font-weight:800}.phone-body{padding:.85rem}.summary{display:grid;grid-template-columns:repeat(2,1fr);gap:.6rem}.summary div{padding:.75rem;border-radius:14px;background:#fff;box-shadow:0 5px 18px rgba(27,46,78,.07)}.summary small{display:block;color:var(--muted);font-size:.62rem}.summary strong{font-size:1rem}.row{margin-top:.65rem;padding:.78rem .8rem;border-radius:14px;background:#fff;box-shadow:0 5px 18px rgba(27,46,78,.07)}.row div{display:flex;justify-content:space-between;gap:.8rem;font-size:.7rem}.row span{color:var(--muted)}.paid{color:var(--mint);font-weight:800}.due{color:#b53b39;font-weight:800}
    .trust{background:#fff;border-block:1px solid var(--line)}.trust-grid{display:grid;gap:1.8rem;padding-block:2.3rem}.trust-item{display:grid;grid-template-columns:2.7rem 1fr;gap:.9rem;align-items:start}.icon{display:grid;place-items:center;width:2.7rem;height:2.7rem;border-radius:12px;background:#eaf2ff;color:var(--blue);font-weight:900}.trust-item h3{margin:0 0 .2rem;font-size:1rem}.trust-item p{margin:0;color:var(--muted);font-size:.9rem}
    .features{padding:4.2rem 0}.section-head{max-width:40rem;margin-bottom:1.7rem}.section-head p{margin:.8rem 0 0;color:var(--muted)}.feature-grid{display:grid;gap:1rem}.feature{padding:1.35rem;border:1px solid var(--line);border-radius:var(--radius);background:rgba(255,255,255,.8)}.feature b{display:block;margin-bottom:.35rem;font-size:1.05rem}.feature p{margin:0;color:var(--muted);font-size:.93rem}.free{display:flex;align-items:center;justify-content:space-between;gap:1rem;flex-wrap:wrap;padding:1rem;border-radius:16px;background:var(--mint-soft);color:#075f50;font-weight:800}
    .bottom-cta{position:relative;overflow:hidden;padding:2.2rem;border-radius:var(--radius);background:#0b1324;color:#fff}.bottom-cta:after{content:"";position:absolute;width:18rem;height:18rem;right:-8rem;top:-10rem;border-radius:50%;background:radial-gradient(circle,rgba(49,130,246,.42),transparent 66%)}.bottom-cta>*{position:relative;z-index:1}.bottom-cta p{max-width:42ch;margin:.8rem 0 1.3rem;color:#c8d3e4}.bottom-cta .button{background:#fff;color:var(--blue-dark);box-shadow:none}.bottom-cta .button:hover{background:#eef5ff}
    footer{padding:2rem 0 2.5rem;color:var(--muted);font-size:.82rem}footer .shell{display:flex;justify-content:space-between;gap:1rem;flex-wrap:wrap}
    @media (min-width:760px){.hero{grid-template-columns:1.12fr .88fr;min-height:680px;padding-top:4rem}.trust-grid{grid-template-columns:repeat(3,1fr)}.feature-grid{grid-template-columns:repeat(2,1fr)}.bottom-cta{padding:3rem}}
    @media (min-width:980px){.feature-grid{grid-template-columns:repeat(3,1fr)}.feature:last-child{grid-column:2}}
    @media (prefers-reduced-motion:reduce){html{scroll-behavior:auto}*,*:before,*:after{transition-duration:.01ms!important;animation-duration:.01ms!important;animation-iteration-count:1!important}}
  </style>
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <header class="shell site-header">
    <a class="brand" href="/" aria-label="Collection Book home"><span class="brand-mark" aria-hidden="true">CB</span><span>Collection Book</span></a>
    <a href="${escapeHtml(playStoreUrl)}" rel="external noopener noreferrer">Google Play</a>
  </header>
  <main id="main">
    <section class="shell hero" aria-labelledby="hero-title">
      <div>
        <p class="eyebrow">Built for cable TV &amp; fiber operators</p>
        <h1 id="hero-title">Your collection book, <span>finally in order.</span></h1>
        <p class="lead">Record door-to-door collections, track every subscriber balance, and send clear WhatsApp receipts—even when the network is down.</p>
        <div class="actions">
          <a class="button" href="${escapeHtml(playStoreUrl)}" rel="external noopener noreferrer">
            <svg aria-hidden="true" viewBox="0 0 24 24" fill="currentColor"><path d="M3.6 2.8a2 2 0 0 0-.6 1.4v15.6a2 2 0 0 0 .6 1.4L12.2 13 3.6 2.8Zm10 8.8L12.2 13 3.6 21.2 13.6 11.6Zm2.3-1.4 2.9 1.7c.9.5.9 1.3 0 1.8l-2.9 1.7-2.3-2.6 2.3-2.6ZM13.6 9.2 3.6-.4l10 8.8 0 .8Z" transform="translate(1 2) scale(.9)"/></svg>
            Get Collection Book
          </a>
        </div>
        <p class="microcopy">For Android · Free for up to 100 subscribers</p>
        ${referralMessage}
      </div>
      <div class="phone-wrap" aria-label="Illustration of a collection summary screen">
        <div class="phone" aria-hidden="true">
          <div class="phone-top"><strong>Collection Book</strong><span>SEPTEMBER</span></div>
          <div class="phone-body">
            <div class="summary"><div><small>Monthly collections</small><strong>View</strong></div><div><small>Outstanding dues</small><strong>Review</strong></div></div>
            <div class="row"><div><strong>Cable TV</strong><span>Register</span></div><div class="paid">Open</div></div>
            <div class="row"><div><strong>Fiber Internet</strong><span>Register</span></div><div class="paid">Open</div></div>
            <div class="row"><div><strong>Record payment</strong><span>WhatsApp</span></div><div class="due">Ready</div></div>
          </div>
        </div>
      </div>
    </section>
    <section class="trust" aria-label="Product principles">
      <div class="shell trust-grid">
        <div class="trust-item"><span class="icon" aria-hidden="true">01</span><div><h3>Works offline</h3><p>Your collection register remains available in low-connectivity areas.</p></div></div>
        <div class="trust-item"><span class="icon" aria-hidden="true">02</span><div><h3>Clear monthly dues</h3><p>See paid, partial, and outstanding balances without spreadsheet juggling.</p></div></div>
        <div class="trust-item"><span class="icon" aria-hidden="true">03</span><div><h3>Receipts on WhatsApp</h3><p>Send a clear payment receipt through the device—no messaging API required.</p></div></div>
      </div>
    </section>
    <section class="shell features" aria-labelledby="features-title">
      <div class="section-head"><h2 id="features-title">From door to dashboard, without the paperwork.</h2><p>Practical tools for daily cable and broadband collection rounds.</p></div>
      <div class="feature-grid">
        <article class="feature"><b>Subscriber register</b><p>Search by name, alias, or VC/STB number and separate Cable TV from Fiber Internet.</p></article>
        <article class="feature"><b>Fast payment entry</b><p>Log a collection, review the remaining balance, and keep the monthly history in one place.</p></article>
        <article class="feature"><b>Imports that save retyping</b><p>Bring supported MSO subscriber spreadsheets into Collection Book and continue from a familiar list.</p></article>
        <article class="feature"><b>Area-wise visibility</b><p>Organize subscribers by neighborhood or route and focus on outstanding collections.</p></article>
        <article class="feature"><b>Local-first storage</b><p>Core ledger work runs on your device in an offline-first SQLite database.</p></article>
        <div class="free"><span>Start with the Free plan</span><span>Up to 100 subscribers</span></div>
      </div>
    </section>
    <section class="shell bottom-cta" aria-labelledby="download-title">
      <h2 id="download-title">Make your next collection round easier.</h2>
      <p>Install Collection Book for Android and move your daily register out of the notebook.</p>
      <a class="button" href="${escapeHtml(playStoreUrl)}" rel="external noopener noreferrer">Download from Google Play</a>
    </section>
  </main>
  <footer><div class="shell"><span>Collection Book · Offline-first field billing</span><span>No tracking scripts. No remote assets.</span></div></footer>
</body>
</html>`;
}
