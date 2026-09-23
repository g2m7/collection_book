# agent.md — AI Agent Operating Constitution

This document defines the operating rules, technical constraints, planning protocols, and architecture guidelines for AI agents working in the **Collection Book** workspace.

---

## 🚨 Non-Negotiable Rules

1. **Runtime Constraint**:
   - The runtime environment is **Bun and Bun only** (`bun`, `bunx`).
   - **`npm` and `npx` MUST NEVER BE USED under any circumstances.**
2. **Planning & Directory Structure Protocol**:
   - All feature and architectural plans must reside inside `docs/plans/`.
   - **EACH PLAN MUST HAVE ITS OWN DEDICATED DIRECTORY** (e.g. `docs/plans/<plan-name>/`).
   - **Never** add loose plan files directly to `docs/` or `docs/plans/`.
   - Every plan folder should contain a primary `plan.md` or `README.md` with explicit objectives, architecture impact, phased checklist, and verification steps.

---

## 📁 Repository & Documentation Map

| Path | Purpose |
| :--- | :--- |
| `agent.md` | Workspace operating constitution for AI agents (this file). |
| `product.md` | Master Product Requirements Document (PRD) & Product Specification. |
| `docs/INDEX.md` | Master index of strategic, technical, and market documentation. |
| `docs/01-market-and-competitor-intelligence.md` | TRAI/AIDCF market metrics, competitor analysis (BixApp, Mobiezy). |
| `docs/02-customer-research-and-icp.md` | LCO/ISP customer personas, field jargon (*bahi-khata, line boy, baqaya*). |
| `docs/03-go-to-market-and-marketing-playbook.md` | Acquisition playbook (Meta Advantage+, YouTube Shorts, WhatsApp loops). |
| `docs/04-pricing-and-5k-customer-economics.md` | Freemium pricing tiers and 5,000 subscriber economics. |
| `docs/05-product-architecture-and-roadmap.md` | Technical architecture (SQLite v5, Convex, Cloudflare edge, i18n). |
| `docs/plans/` | **Root directory for all plans. Each plan has its own subfolder.** |
| `lib/` | Flutter application source code (models, screens, services, theme). |
| `android/` | Android native project files, gradle configs, and manifest. |
| `test/` | Automated unit and widget tests. |

---

## 📐 Planning Protocol (`docs/plans/<plan-name>/`)

When tasked with designing, specifying, or executing a new feature, architecture migration, or complex refactor:

1. **Create a Dedicated Directory**:
   ```bash
   mkdir -p docs/plans/<plan-slug>
   ```
   *Example: `docs/plans/cloud-sync-engine/`, `docs/plans/multi-lang-localization/`*

2. **Structure Within the Plan Folder**:
   - `plan.md` (or `README.md`) — Master specification and task checklist.
   - `architecture.md` (optional) — Deep-dive schema or sequence diagrams.
   - `research.md` (optional) — Competitor benchmarks, field notes, API investigations.
   - `assets/` (optional) — Diagrams, sample payloads, or wireframes.

3. **Plan Document Standard Template**:
   - **1. Objective & Background**: Problem statement and target user outcome.
   - **2. Scope & Constraints**: Clear boundaries of what is included and what is deferred.
   - **3. Technical Design**: SQLite tables, state management changes, UI flows.
   - **4. Execution Checklist**: Step-by-step checkboxes updated as work progresses.
   - **5. Verification Plan**: Automated tests (`flutter test`), static analysis (`flutter analyze`), and manual device testing.

4. **Lifecycle & Progress Tracking**:
   - Update checklist items `[x]` as tasks are completed.
   - Record architectural trade-offs and edge-case decisions in the plan folder so future agents retain full context.

---

## 🛠️ Tech Stack & Engineering Standards

- **Framework**: Flutter (Dart SDK ^3.6.0).
- **Architecture Philosophy**: **Offline-first**. Local operations must be instant, resilient to spotty network connectivity, and never block the UI thread.
- **Local Persistence**: SQLite (`sqflite`). Database migrations must be backwards-compatible.
- **Cloud Backend (Planned)**: Convex + Cloudflare edge functions.
- **WhatsApp Engine**: Zero-marginal-cost device URI scheme (`whatsapp://send?phone=...&text=...`). Do not route through paid BSPs (Twilio/Gupshup) unless explicitly required for automated broadcasts.
- **UI & Icons**: Use `phosphor_flutter` with the bold style convention established across the app.
- **File & Excel Imports**: In-app XLS/XLSX parser for MSO subscriber sheets.

---

## ✅ Quality & Verification Gates

Before completing any task:
1. **Analyze**: Run `flutter analyze` — ensure zero errors and zero unaddressed warnings.
2. **Test**: Run `flutter test` for any affected unit/widget test suites.
3. **Preserve Rules**: Maintain existing comments, formatting conventions, and runtime constraints.
