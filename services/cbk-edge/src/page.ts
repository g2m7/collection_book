/**
 * Shared self-contained HTML shell for the public `cbk.sarbaa.com` pages.
 *
 * Both pages are plain HTML with inline CSS only: no scripts, no external
 * fonts, images, or stylesheets, so the security policy can keep
 * `script-src 'none'` and `default-src 'none'`.
 */

import { publicOrigin } from "@collection-book/contracts";

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

export const operatorName = "Sarbani Associates";
export const operatorWebsiteUrl = "https://sarbaa.com";
export const operatorPhoneDisplay = "+91 89721 46130";
export const operatorPhoneHref = "tel:+918972146130";

const siteStyles = `
    :root {
      --paper: #f6f4ee;
      --card: #fffdf8;
      --ink: #14231d;
      --ink-soft: #46584f;
      --line: #d9d5c8;
      --line-soft: #e8e4d8;
      --accent: #0b5c46;
      --on-accent: #ffffff;
      --on-accent-soft: #d8efe5;
      --accent-dark: #08402f;
      --accent-soft: #dcefe6;
      --signal: #a24412;
      --focus: #a24412;
      --radius: 18px;
      --tap: 48px;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --paper: #101a16;
        --card: #16241e;
        --ink: #eef3ef;
        --ink-soft: #b3c4ba;
        --line: #2c3d35;
        --line-soft: #22322b;
        --accent: #63d3ab;
        --on-accent: #06201a;
        --on-accent-soft: #0d3a2c;
        --accent-dark: #8fe6c4;
        --accent-soft: #14322a;
        --signal: #ffab70;
        --focus: #ffab70;
      }
    }
    *, *::before, *::after { box-sizing: border-box; }
    html { -webkit-text-size-adjust: 100%; scroll-behavior: smooth; }
    body {
      margin: 0;
      background: var(--paper);
      color: var(--ink);
      font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
      font-size: 1rem;
      line-height: 1.6;
      padding-inline: env(safe-area-inset-left) env(safe-area-inset-right);
      padding-block: env(safe-area-inset-top) env(safe-area-inset-bottom);
    }
    a { color: var(--accent); touch-action: manipulation; }
    :focus-visible { outline: 3px solid var(--focus); outline-offset: 3px; border-radius: 6px; }
    .skip-link {
      position: absolute; left: 0.75rem; top: 0.75rem; z-index: 20;
      transform: translateY(-200%);
      display: inline-flex; align-items: center; min-height: var(--tap);
      padding: 0 1rem; border-radius: 12px;
      background: var(--accent); color: var(--on-accent); font-weight: 700; text-decoration: none;
    }
    .skip-link:focus { transform: translateY(0); }
    .shell { width: min(64rem, 100% - 2.5rem); margin-inline: auto; }
    .site-header {
      display: flex; flex-wrap: wrap; gap: 0.5rem 1rem; align-items: center; justify-content: space-between;
      padding-block: 1rem;
    }
    .brand { display: inline-flex; align-items: center; gap: 0.6rem; min-height: var(--tap); font-weight: 800; letter-spacing: -0.01em; text-decoration: none; color: inherit; }
    .brand-mark {
      display: grid; place-items: center; width: 2.25rem; height: 2.25rem; border-radius: 10px;
      background: var(--accent); color: var(--on-accent); font-size: 0.8rem; font-weight: 800; letter-spacing: 0.02em;
    }
    .site-nav { display: flex; flex-wrap: wrap; align-items: center; gap: 0.25rem; }
    .site-nav a {
      display: inline-flex; align-items: center; min-height: var(--tap); padding-inline: 0.6rem;
      border-radius: 10px; color: var(--ink-soft); font-size: 0.92rem; font-weight: 600; text-decoration: none;
    }
    .site-nav a:hover { color: var(--ink); background: var(--accent-soft); }
    h1, h2, h3 { letter-spacing: -0.02em; line-height: 1.12; text-wrap: balance; margin: 0; }
    h1 { font-size: clamp(2.1rem, 8.5vw, 3.75rem); }
    h2 { font-size: clamp(1.55rem, 5.5vw, 2.35rem); }
    h3 { font-size: 1.08rem; }
    p, li { text-wrap: pretty; }
    .eyebrow {
      display: inline-block; margin: 0 0 0.9rem; padding: 0.3rem 0.7rem; border-radius: 999px;
      background: var(--accent-soft); color: var(--accent-dark);
      font-size: 0.78rem; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase;
    }
    .lead { max-width: 58ch; margin: 1.1rem 0 0; color: var(--ink-soft); font-size: 1.06rem; }
    .section { padding-block: clamp(2.75rem, 8vw, 4.5rem); }
    .section + .section { border-top: 1px solid var(--line-soft); }
    .section-head { max-width: 46rem; margin-bottom: 1.75rem; }
    .section-head p { margin: 0.7rem 0 0; color: var(--ink-soft); }
    .actions { display: flex; flex-wrap: wrap; gap: 0.75rem; margin-top: 1.75rem; }
    .button {
      display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem;
      min-height: var(--tap); min-width: var(--tap); padding: 0.7rem 1.4rem; border: 2px solid transparent; border-radius: 14px;
      background: var(--accent); color: var(--on-accent); font-size: 1rem; font-weight: 700; text-align: center; text-decoration: none;
      touch-action: manipulation; transition: background-color .15s ease, transform .15s ease;
    }
    .button:hover { background: var(--accent-dark); }
    .button:active { transform: translateY(1px); }
    .button--ghost { background: transparent; border-color: var(--line); color: var(--ink); }
    .button--ghost:hover { background: var(--accent-soft); border-color: var(--accent); }
    .microcopy { margin: 0.9rem 0 0; color: var(--ink-soft); font-size: 0.88rem; }
    .availability {
      margin-top: 1.75rem; padding: 1.1rem 1.25rem; border: 1px solid var(--line); border-left: 4px solid var(--signal);
      border-radius: 14px; background: var(--card);
    }
    .availability strong { display: block; font-size: 1.02rem; }
    .availability p { margin: 0.35rem 0 0; color: var(--ink-soft); font-size: 0.92rem; }
    .referral-note {
      display: inline-flex; align-items: center; min-height: var(--tap); margin-top: 1.1rem; padding: 0 0.9rem;
      border-radius: 12px; background: var(--accent-soft); color: var(--accent-dark); font-size: 0.9rem; font-weight: 600;
    }
    .grid { display: grid; gap: 1rem; }
    .card {
      padding: 1.35rem; border: 1px solid var(--line); border-radius: var(--radius); background: var(--card);
    }
    .card p { margin: 0.45rem 0 0; color: var(--ink-soft); font-size: 0.95rem; }
    .step-list { margin: 0; padding: 0; list-style: none; display: grid; gap: 0.75rem; counter-reset: step; }
    .step-list li {
      counter-increment: step; display: grid; grid-template-columns: 2.5rem 1fr; gap: 0.9rem; align-items: start;
      padding: 1.1rem 1.25rem; border: 1px solid var(--line); border-radius: var(--radius); background: var(--card);
    }
    .step-list li::before {
      content: counter(step); display: grid; place-items: center; width: 2.5rem; height: 2.5rem; border-radius: 10px;
      background: var(--accent); color: var(--on-accent); font-weight: 800;
    }
    .step-list p { margin: 0.35rem 0 0; color: var(--ink-soft); font-size: 0.95rem; }
    .faq { display: grid; gap: 0.6rem; }
    .faq details { border: 1px solid var(--line); border-radius: 14px; background: var(--card); }
    .faq summary {
      display: flex; align-items: center; justify-content: space-between; gap: 1rem;
      min-height: var(--tap); padding: 0.85rem 1.1rem; cursor: pointer; font-weight: 700; list-style: none;
      touch-action: manipulation;
    }
    .faq summary::-webkit-details-marker { display: none; }
    .faq summary::after { content: "+"; color: var(--accent); font-size: 1.25rem; line-height: 1; }
    .faq details[open] summary::after { content: "\\2013"; }
    .faq p { margin: 0; padding: 0 1.1rem 1.1rem; color: var(--ink-soft); font-size: 0.95rem; }
    .panel { padding: clamp(1.5rem, 5vw, 2.5rem); border-radius: var(--radius); background: var(--accent); color: var(--on-accent); }
    .panel p { max-width: 52ch; margin: 0.8rem 0 0; color: var(--on-accent-soft); }
    .panel .button { background: var(--on-accent); color: var(--accent); }
    .panel .button:hover { background: var(--accent-soft); }
    .panel .button--ghost { background: transparent; border-color: var(--on-accent); color: var(--on-accent); }
    .panel .button--ghost:hover { background: var(--on-accent); color: var(--accent); }
    .site-footer { border-top: 1px solid var(--line-soft); padding-block: 2rem 2.5rem; color: var(--ink-soft); font-size: 0.9rem; }
    .footer-row { display: flex; flex-wrap: wrap; gap: 0.5rem 1.25rem; align-items: center; justify-content: space-between; }
    .footer-links { display: flex; flex-wrap: wrap; gap: 0.25rem 0.75rem; }
    .footer-links a { display: inline-flex; align-items: center; min-height: var(--tap); color: var(--ink-soft); }
    @media (min-width: 46rem) {
      .grid--two { grid-template-columns: repeat(2, 1fr); }
      .grid--three { grid-template-columns: repeat(3, 1fr); }
    }
    @media (prefers-reduced-motion: reduce) {
      html { scroll-behavior: auto; }
      *, *::before, *::after { transition-duration: .01ms !important; animation-duration: .01ms !important; animation-iteration-count: 1 !important; }
    }
`;

export interface NavLink {
  readonly href: string;
  readonly label: string;
}

export interface DocumentOptions {
  readonly title: string;
  readonly description: string;
  readonly canonicalPath: string;
  readonly navLinks: ReadonlyArray<NavLink>;
  /** Extra page-scoped rules appended to the shared stylesheet. */
  readonly styles?: string;
  readonly content: string;
}

function renderNav(navLinks: ReadonlyArray<NavLink>): string {
  const items = navLinks
    .map(
      (link) =>
        `<a href="${escapeHtml(link.href)}">${escapeHtml(link.label)}</a>`,
    )
    .join("\n        ");
  return `<nav class="site-nav" aria-label="Primary">\n        ${items}\n      </nav>`;
}

function renderFooter(): string {
  return `<footer class="site-footer">
      <div class="shell footer-row">
        <p>Collection Book &middot; an offline-first collection ledger by ${escapeHtml(operatorName)}.</p>
        <div class="footer-links">
          <a href="/privacy">Privacy policy</a>
          <a href="${escapeHtml(operatorWebsiteUrl)}" rel="external noopener noreferrer">${escapeHtml(operatorWebsiteUrl.replace("https://", ""))}</a>
          <a href="${escapeHtml(operatorPhoneHref)}">${escapeHtml(operatorPhoneDisplay)}</a>
        </div>
      </div>
    </footer>`;
}

export function renderDocument(options: DocumentOptions): string {
  const canonical = `${publicOrigin}${options.canonicalPath}`;
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="description" content="${escapeHtml(options.description)}">
  <meta name="theme-color" content="#0b5c46">
  <meta name="color-scheme" content="light dark">
  <meta property="og:type" content="website">
  <meta property="og:title" content="${escapeHtml(options.title)}">
  <meta property="og:description" content="${escapeHtml(options.description)}">
  <meta property="og:url" content="${escapeHtml(canonical)}">
  <link rel="canonical" href="${escapeHtml(canonical)}">
  <title>${escapeHtml(options.title)}</title>
  <style>${siteStyles}${options.styles ?? ""}  </style>
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <header class="shell site-header">
    <a class="brand" href="/"><span class="brand-mark" aria-hidden="true">CB</span>Collection Book</a>
    ${renderNav(options.navLinks)}
  </header>
  <main id="main">
${options.content}
  </main>
  ${renderFooter()}
</body>
</html>`;
}
