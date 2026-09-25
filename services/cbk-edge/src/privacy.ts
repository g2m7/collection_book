/**
 * Public privacy policy for `cbk.sarbaa.com`.
 *
 * Every statement here describes behavior that exists in the shipped Flutter
 * app (`lib/services/analytics_service.dart`, `lib/services/backup_service.dart`,
 * `lib/services/whatsapp_receipt_service.dart`) or in the `handleRequest`
 * request handler. Nothing is promised beyond that, and no email address is
 * invented: the published website and phone number are the contact points.
 */

import { operatorName, renderDocument } from "./page";

const policyStyles = `
    .prose { max-width: 46rem; }
    .prose section { padding-block: 1.75rem; border-top: 1px solid var(--line-soft); }
    .prose section:first-of-type { border-top: 0; padding-top: 0; }
    .prose h2 { font-size: clamp(1.25rem, 4.5vw, 1.6rem); }
    .prose h3 { margin-top: 1.25rem; }
    .prose p, .prose li { color: var(--ink-soft); font-size: 0.98rem; }
    .prose p { margin: 0.75rem 0 0; }
    .prose ul { margin: 0.75rem 0 0; padding-left: 1.1rem; }
    .prose li { margin-top: 0.4rem; }
    .prose strong { color: var(--ink); }
    .prose dt { margin-top: 0.75rem; color: var(--ink); font-weight: 700; }
    .prose dd { margin: 0.2rem 0 0; color: var(--ink-soft); font-size: 0.98rem; }
    .updated { color: var(--ink-soft); font-size: 0.88rem; }
`;

const privacySections = `      <section aria-labelledby="policy-scope">
        <h2 id="policy-scope">1. What this policy covers</h2>
        <p>This policy covers the Collection Book Android app and the public website at <strong>cbk.sarbaa.com</strong>, which is operated by ${operatorName} from Bagdogra, Siliguri, West Bengal. It describes what each of them stores, what leaves your phone, and who to contact.</p>
        <p>Collection Book has no user account and no hosted copy of your subscriber register. This is the single most important fact on this page.</p>
      </section>

      <section aria-labelledby="policy-local-data">
        <h2 id="policy-local-data">2. Your subscriber and customer data stays on the phone</h2>
        <p>Subscriber names, alias names, phone numbers, VC/STB numbers, account numbers, areas, monthly amounts, and every payment and adjustment are stored in a local SQLite database inside the app on your device.</p>
        <ul>
          <li>That data is <strong>not</strong> uploaded to us, to a hosting provider, or to any other service by the app.</li>
          <li>It leaves the device only when you choose to: exporting or sharing a list, taking a local backup copy, or restoring a backup file you already have.</li>
          <li>Once you share a file or a receipt through another app, that app and its recipients apply their own policies.</li>
        </ul>
        <p>The Android app is installed with operating-system backup disabled, so the local database is not copied into the platform's own backup services. Clearing the app's storage, uninstalling it, or resetting it from the app's settings removes the register, the queued events, and the random client identifier on that device.</p>
      </section>

      <section aria-labelledby="policy-sharing">
        <h2 id="policy-sharing">3. WhatsApp receipts and file sharing</h2>
        <p>The app generates a receipt on your device and hands it to the WhatsApp app installed on the phone, in the language you selected. It never connects to a WhatsApp Business account or a messaging API, and it never sends anything on its own: every message starts with a tap from you.</p>
        <p>When the WhatsApp app is not installed or cannot be opened, the app falls back to wa.me and hands your browser a <strong>wa.me web link</strong> instead. On that fallback the <strong>complete receipt text is placed in the link's text parameter</strong>, which means the customer name, phone number, service identifier, billing month, amount paid, and remaining balance all travel to WhatsApp's web service. The link is handled by the browser and by WhatsApp under their own privacy policies and terms, both of which may use that information. Because the full receipt leaves the app in a URL, treat a wa.me fallback as a share with the network provider rather than as a purely on-device action, and prefer the installed app when a message contains customer details.</p>
        <p>The same is true of backups and exports. The app hands the file to the system share sheet, and the app you pick completes the transfer.</p>
      </section>

      <section aria-labelledby="policy-analytics">
        <h2 id="policy-analytics">4. The small, pseudonymous product event queue</h2>
        <p>To know which parts of the app are used, the app keeps a queue on the device of a small set of product events. A batch contains:</p>
        <ul>
          <li>a random client identifier generated on the device, with no name, phone number, email address, or account attached to it;</li>
          <li>event names from a fixed allowlist, such as first app open, first subscriber created, a spreadsheet import, a payment recorded, and a receipt handed to WhatsApp;</li>
          <li>the event timestamp, and a small set of allowlisted properties such as counts, timings, the service type, and the detected import format.</li>
        </ul>
        <p>These events never contain subscriber names, subscriber or customer phone numbers, VC or STB numbers, payment amounts, areas, or free-text fields.</p>
        <p>Delivery to <strong>cbk.sarbaa.com</strong> is only attempted while the device reports a Wi-Fi connection. If no attempt succeeds, the events stay queued on the device. Because the edge service accepts a batch only when its analytics storage is available, a deployment without that storage answers with a temporary error and the app keeps its queue rather than discarding it.</p>
        <p>Resetting the app from its settings removes the local register, the queued events, and the random client identifier on that device.</p>
      </section>

      <section aria-labelledby="policy-referrals">
        <h2 id="policy-referrals">5. Referral links</h2>
        <p>A receipt may carry a referral link to a page on this site. Visiting it sets a single first-party cookie named <strong>cbk_referral</strong> that holds the six-character referral code, is marked <strong>HttpOnly</strong>, <strong>Secure</strong>, and <strong>SameSite=Lax</strong>, and expires after 30 days. It is not readable by scripts and is not shared with any advertising or analytics provider.</p>
        <p>For each valid referral click the server writes one log line containing the event name, the referral code, a generated request identifier, and a timestamp. That line deliberately excludes IP addresses, user agents, cookies, subscriber data, and operator data.</p>
      </section>

      <section aria-labelledby="policy-network">
        <h2 id="policy-network">6. Website hosting and network data</h2>
        <p>This site is served over HTTPS through a hosting provider and, for the referral and event endpoints, through a CDN or reverse proxy. Like any web server, they process the ordinary network metadata a connection requires, such as the request time, the requested path, response status, and the connection's IP address, and they may keep their own short-lived logs and rate limits for security and abuse prevention. The app itself does not send subscriber or customer data to them.</p>
        <p>This page contains no scripts, no cookies of its own, no embedded third-party content, and no advertising or measurement code.</p>
      </section>

      <section aria-labelledby="policy-retention">
        <h2 id="policy-retention">7. Retention and your control</h2>
        <p>Data on the device is under your control: it stays until you delete it, you clear the app's storage, you uninstall the app, or you reset it from the app's settings. Backups you create are ordinary files that you keep, move, or delete yourself.</p>
        <p>Server-side, we keep the minimum needed to operate the site: short-lived web request logs from the hosting and proxy layers, and the minimal referral log described in section 5. How long those operational logs are kept is a decision for the hosting provider's own policy, and we do not publish a fixed deletion window here. If you want a specific record removed, contact us using the details in section 9 and we will tell you exactly what we can find and delete.</p>
      </section>

      <section aria-labelledby="policy-children">
        <h2 id="policy-children">8. Children</h2>
        <p>Collection Book is a business tool for collection operators. It is not directed at children, and we do not knowingly collect personal data from them.</p>
      </section>

      <section aria-labelledby="policy-contact">
        <h2 id="policy-contact">9. Contact</h2>
        <dl>
          <dt>Operator</dt>
          <dd>${operatorName}, Bagdogra, Siliguri, West Bengal, India</dd>
          <dt>Website</dt>
          <dd><a href="https://sarbaa.com" rel="external noopener noreferrer">https://sarbaa.com</a></dd>
          <dt>Phone</dt>
          <dd><a href="tel:+918972146130">+91 89721 46130</a></dd>
        </dl>
        <p>Use the phone number or the website above for any question about this policy, a referral log line, or a data deletion request.</p>
      </section>`;

export function renderPrivacyPage(): string {
  return renderDocument({
    title: "Privacy policy — Collection Book",
    description:
      "How Collection Book stores subscriber data on your device, what the pseudonymous product event queue contains, and how to contact Sarbani Associates.",
    canonicalPath: "/privacy",
    navLinks: [{ href: "/", label: "Back to Collection Book" }],
    styles: policyStyles,
    content: `    <div class="shell section prose">
      <h1>Privacy policy</h1>
      <p class="updated">Applies to the Collection Book Android app and to cbk.sarbaa.com.</p>
${privacySections}
    </div>`,
  });
}
