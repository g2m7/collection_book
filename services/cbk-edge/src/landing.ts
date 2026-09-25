/**
 * Public landing page for `cbk.sarbaa.com`.
 *
 * Copy may only describe capabilities the Flutter app actually implements, and
 * a Google Play call to action appears only when `PLAY_STORE_URL` points at a
 * valid public listing. `bun test` runs the rendered copy through the shared
 * `findUnsupportedClaims` scanner in `@collection-book/contracts`.
 */

import {
  androidPackageName,
  parseReferralCode,
} from "@collection-book/contracts";

import { escapeHtml, renderDocument } from "./page";

/**
 * Returns the Play Store link to render, or `null` when no valid listing is
 * configured. A non-null result means the page may show a live download call
 * to action and may carry a valid referral code into the Play `referrer`
 * parameter.
 */
export function resolvePlayStoreUrl(
  configuredUrl: string | undefined,
  requestedReferral: string | null,
): string | null {
  if (configuredUrl === undefined || configuredUrl.trim() === "") return null;
  let listing: URL;
  try {
    const candidate = new URL(configuredUrl.trim());
    const isGooglePlayListing =
      candidate.protocol === "https:" &&
      candidate.hostname === "play.google.com" &&
      candidate.port === "" &&
      candidate.username === "" &&
      candidate.password === "" &&
      candidate.pathname === "/store/apps/details";
    if (!isGooglePlayListing) return null;
    listing = candidate;
  } catch {
    return null;
  }

  const referralCode = parseReferralCode(requestedReferral);
  listing.searchParams.set("id", androidPackageName);
  if (referralCode !== null) {
    listing.searchParams.set(
      "referrer",
      `utm_source=cbk_edge&utm_medium=referral&utm_campaign=${referralCode}`,
    );
  }
  return listing.toString();
}

const heroStyles = `
    .hero { display: grid; gap: 2.5rem; padding-block: clamp(1.5rem, 6vw, 4rem) clamp(2.5rem, 8vw, 5rem); }
    .hero-copy { max-width: 34rem; }
    @media (min-width: 62rem) {
      .hero { grid-template-columns: 1.05fr .95fr; align-items: center; }
      .hero-copy { max-width: none; }
      .ledger { margin-top: 0; }
    }
    .ledger {
      margin: 2.25rem 0 0; padding: 1.1rem; border: 1px solid var(--line); border-radius: var(--radius);
      background: var(--card);
      background-image: repeating-linear-gradient(to bottom, transparent 0 2.6rem, var(--line-soft) 2.6rem 2.65rem);
      box-shadow: 0 18px 40px rgba(20, 35, 29, .09);
    }
    .ledger-tabs { display: flex; gap: 0.5rem; margin-bottom: 0.9rem; }
    .ledger-tab {
      display: inline-flex; align-items: center; min-height: 2.5rem; padding: 0 0.9rem; border-radius: 999px;
      background: var(--accent-soft); color: var(--accent-dark); font-size: 0.85rem; font-weight: 700;
    }
    .ledger-tab--muted { background: transparent; border: 1px solid var(--line); color: var(--ink-soft); }
    .ledger-rows { margin: 0; padding: 0; list-style: none; display: grid; gap: 0.35rem; }
    .ledger-rows li {
      display: grid; grid-template-columns: 4.5rem 1fr auto; gap: 0.75rem; align-items: center;
      min-height: 2.5rem; padding: 0.35rem 0.5rem; border-radius: 10px; background: var(--card);
    }
    .ledger-service { color: var(--ink-soft); font-size: 0.78rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; }
    .ledger-bar { display: block; height: 0.65rem; border-radius: 999px; background: var(--line-soft); }
    .ledger-status { padding: 0.2rem 0.6rem; border-radius: 999px; font-size: 0.75rem; font-weight: 700; }
    .ledger-status--paid { background: var(--accent-soft); color: var(--accent-dark); }
    .ledger-status--due { background: rgba(162, 68, 18, .14); color: var(--signal); }
    .ledger figcaption { margin-top: 0.9rem; color: var(--ink-soft); font-size: 0.82rem; }
    .trust-list { margin: 1.25rem 0 0; padding: 0; list-style: none; display: grid; gap: 0.75rem; }
    .trust-list li { display: grid; grid-template-columns: 1.4rem 1fr; gap: 0.6rem; color: var(--ink-soft); font-size: 0.95rem; }
    .trust-list li::before { content: "\\2713"; color: var(--accent); font-weight: 800; }
    .legal { margin: 1.5rem 0 0; color: var(--ink-soft); font-size: 0.86rem; }
`;

const ledgerFigure = `          <figure class="ledger">
            <div class="ledger-tabs">
              <span class="ledger-tab">Cable TV</span>
              <span class="ledger-tab ledger-tab--muted">Fiber Internet</span>
            </div>
            <ul class="ledger-rows">
              <li><span class="ledger-service">Cable TV</span><span class="ledger-bar" style="width:82%"></span><span class="ledger-status ledger-status--paid">Paid</span></li>
              <li><span class="ledger-service">Cable TV</span><span class="ledger-bar" style="width:64%"></span><span class="ledger-status ledger-status--due">Due</span></li>
              <li><span class="ledger-service">Fiber</span><span class="ledger-bar" style="width:74%"></span><span class="ledger-status ledger-status--due">Due</span></li>
              <li><span class="ledger-service">Fiber</span><span class="ledger-bar" style="width:55%"></span><span class="ledger-status ledger-status--paid">Paid</span></li>
            </ul>
            <figcaption>Every row is a subscriber you already serve: the service, the running balance, and whether the month is settled.</figcaption>
          </figure>`;

function renderPrimaryAction(downloadUrl: string | null): string {
  if (downloadUrl === null) {
    return `        <div class="availability" role="note">
          <strong>Google Play release in progress</strong>
          <p>The Android build is on its way to the Play Store. There is no public listing to link yet, so this page stays honest and shows no download button until one exists.</p>
        </div>`;
  }
  return `        <div class="actions">
          <a class="button" href="${escapeHtml(downloadUrl)}" rel="external noopener noreferrer">Get Collection Book on Google Play</a>
          <a class="button button--ghost" href="/privacy">How your data is handled</a>
        </div>`;
}

function renderFinalCta(downloadUrl: string | null): string {
  const action =
    downloadUrl === null
      ? `        <p><strong>Google Play release in progress.</strong> Nothing is sold and no account is needed; when the Play listing goes public, the download button on this page starts working on its own.</p>`
      : `        <p>Install Collection Book on your Android phone and take the next collection round out of the notebook.</p>
        <div class="actions">
          <a class="button" href="${escapeHtml(downloadUrl)}" rel="external noopener noreferrer">Download from Google Play</a>
        </div>`;
  return `    <section class="shell section" id="availability" aria-labelledby="availability-title">
      <div class="panel">
        <h2 id="availability-title">Run the round from the phone in your pocket.</h2>
${action}
      </div>
    </section>`;
}

export function renderLandingPage(
  requestedReferral: string | null,
  configuredPlayStoreUrl: string | undefined,
): string {
  const playStoreUrl = resolvePlayStoreUrl(
    configuredPlayStoreUrl,
    requestedReferral,
  );
  const referralCode = parseReferralCode(requestedReferral);
  const referralNote =
    playStoreUrl === null || referralCode === null
      ? ""
      : `\n        <p class="referral-note" role="note">Referral <strong>${escapeHtml(referralCode)}</strong> is carried into your Google Play install.</p>`;

  const content = `    <section class="shell hero" aria-labelledby="hero-title">
      <div class="hero-copy">
        <p class="eyebrow">For cable TV &amp; fiber collection rounds</p>
        <h1 id="hero-title">Know who paid and who owes, before you knock again.</h1>
        <p class="lead">Collection Book is an offline-first collection ledger for local cable TV and fiber internet operators. Subscribers, payments, and dues live in a local database on your own Android phone, so the app behaves the same on a dead network &mdash; and a receipt leaves through WhatsApp on that phone, or through wa.me in your browser when the WhatsApp app is not installed.</p>
${renderPrimaryAction(playStoreUrl)}${referralNote}
        <p class="microcopy">Android phone &middot; no sign-in &middot; works without internet</p>
      </div>
      <div class="hero-figure">
${ledgerFigure}
      </div>
    </section>

    <section class="shell section" aria-labelledby="outcomes-title">
      <div class="section-head">
        <h2 id="outcomes-title">Three things that change on the next round.</h2>
        <p>Built around the hours an operator actually loses: retyping lists, chasing balances, and explaining payments over the phone.</p>
      </div>
      <div class="grid grid--three">
        <article class="card"><h3>Stop retyping your MSO list</h3><p>Import a supported subscriber export, review the preview of the detected columns, and continue from the list you already have.</p></article>
        <article class="card"><h3>See dues before the next knock</h3><p>Cable TV and fiber subscribers stay in separate registers, and each one carries a running balance with the months still pending.</p></article>
        <article class="card"><h3>Send a receipt they can read</h3><p>A receipt is generated on your phone and handed to WhatsApp in the language you choose, so the subscriber knows what was paid and what is left.</p></article>
      </div>
    </section>

    <section class="shell section" id="how" aria-labelledby="how-title">
      <div class="section-head">
        <h2 id="how-title">How a collection round works.</h2>
        <p>Four steps, all of them offline, all of them on your own device.</p>
      </div>
      <ol class="step-list">
        <li><div><h3>Bring your list in</h3><p>Add subscribers by hand, or import a supported .xls, .xlsx, or .csv export and confirm the preview before anything is written.</p></div></li>
        <li><div><h3>Keep the services apart</h3><p>Each subscriber belongs to cable TV or fiber internet, with the VC/STB number or the account number your network uses.</p></div></li>
        <li><div><h3>Record the money you collected</h3><p>Log the payment and any adjustment against the subscriber, and read the remaining balance straight away.</p></div></li>
        <li><div><h3>Send the receipt on WhatsApp</h3><p>You tap send, and WhatsApp opens with the message filled in. If the WhatsApp app is not installed, the same text is handed to your browser as a wa.me link instead. Nothing is delivered without you.</p></div></li>
      </ol>
    </section>

    <section class="shell section" id="capabilities" aria-labelledby="capabilities-title">
      <div class="section-head">
        <h2 id="capabilities-title">What the app does today.</h2>
        <p>Everything here ships in the Android app. Nothing below is planned, promised, or paid for separately.</p>
      </div>
      <div class="grid grid--two">
        <article class="card"><h3>Offline-first database</h3><p>Records are kept in a local SQLite database on the phone, so the register opens and works with no network.</p></article>
        <article class="card"><h3>Cable TV and fiber, separated</h3><p>Filter, import, and report each service on its own instead of mixing two networks in one list.</p></article>
        <article class="card"><h3>Import supported files</h3><p>Bring in the subscriber exports your MSO or operator portal already produces, with a preview before the write.</p></article>
        <article class="card"><h3>Payments and dues</h3><p>Record what was collected, adjust it when needed, and follow paid, partial, and outstanding months per subscriber.</p></article>
        <article class="card"><h3>Multilingual receipts</h3><p>English, Hindi, Marathi, Bengali, and Tamil receipt templates, handed to WhatsApp on your phone. Without the WhatsApp app, the same text goes to wa.me in your browser.</p></article>
        <article class="card"><h3>Local backup and restore</h3><p>Take a copy of the database, keep or share it wherever you want, and restore from that file when you need to.</p></article>
      </div>
    </section>

    <section class="shell section" id="trust" aria-labelledby="trust-title">
      <div class="section-head">
        <h2 id="trust-title">Your list stays on your phone.</h2>
        <p>Collection Book has no account, no server-side copy of your subscribers, no advertising SDK, and no third-party scripts on this page.</p>
      </div>
      <ul class="trust-list">
        <li>Subscriber names, phone numbers, and VC/STB numbers stay in the local database unless you export, share, or back them up yourself.</li>
        <li>WhatsApp and file sharing only happen when you choose them. The app hands the receipt to the installed WhatsApp app; when that app is unavailable it hands the same text to wa.me in your browser, so the full receipt &mdash; including the customer name and payment details printed on it &mdash; is placed in a WhatsApp web URL and handled by the browser and by WhatsApp's own web service under their privacy policies.</li>
        <li>A short queue of pseudonymous product events waits on the device and is only ever attempted over Wi-Fi.</li>
        <li>A referral link can set a single 30-day cookie so a shared receipt link keeps working.</li>
      </ul>
      <p class="legal"><a href="/privacy">Read the privacy policy</a> for the exact data flow.</p>
    </section>

    <section class="shell section" id="faq" aria-labelledby="faq-title">
      <div class="section-head">
        <h2 id="faq-title">Questions operators ask first.</h2>
      </div>
      <div class="faq">
        <details>
          <summary>Does it work without internet?</summary>
          <p>Yes. The register is stored in a local SQLite database on the phone, so adding subscribers, recording payments, and reading balances all work with the network down.</p>
        </details>
        <details>
          <summary>Can I bring my existing subscriber list?</summary>
          <p>Yes, if it is one of the supported spreadsheet or CSV exports. You always see a preview of the detected format and rows before anything is imported.</p>
        </details>
        <details>
          <summary>Does the app send WhatsApp receipts by itself?</summary>
          <p>No. The receipt is generated on your phone and handed to WhatsApp when you tap send, in the language you selected for that subscriber. If the WhatsApp app is not installed, the app opens wa.me in your browser instead, with the complete receipt text &mdash; customer name, amount, and balance &mdash; inside the link, and WhatsApp's web service handles it from there.</p>
        </details>
        <details>
          <summary>Is Collection Book on Google Play yet?</summary>
          <p>${playStoreUrl === null ? "Not yet. The Android release is in progress, and this page deliberately shows no download button until a public Play listing exists." : "Yes. The download button on this page opens the public Play listing for the app."}</p>
        </details>
        <details>
          <summary>What if I reset the app?</summary>
          <p>Resetting removes the app's local data on the device, including the subscriber register, the queued product events, and the random client identifier those events use.</p>
        </details>
      </div>
    </section>
${renderFinalCta(playStoreUrl)}`;

  return renderDocument({
    title: "Collection Book — offline collection ledger for cable TV and fiber",
    description:
      "Collection Book is an offline-first subscriber, payment, and dues ledger for local cable TV and fiber internet operators, with multilingual WhatsApp receipts and local backup.",
    canonicalPath: "/",
    navLinks: [
      { href: "#how", label: "How it works" },
      { href: "#faq", label: "Questions" },
      { href: "/privacy", label: "Privacy" },
    ],
    styles: heroStyles,
    content,
  });
}
