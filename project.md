# PaisaLog — Master Project Context, Specification & Status

> **Single Source of Truth for Context, Architecture, Decisions, and Live Checklist**
> Last updated: 2026-10-29 11:15 IST
> Target Platform: iOS (iPhone 17 Pro Max) | Development Environment: Windows 11 + VS Code + Flutter 3.47.8

---

## 1. Executive Summary & Product Scope

### 1.1 Product Goal
PaisaLog is a private, personal-use, iPhone-first, local-first expense tracker. It transforms financial SMS messages from Indian banks, credit cards, and payment providers (UPI, NEFT, IMPS) into a local transaction ledger without exposing private financial data to third-party cloud servers.

### 1.2 Core Privacy & Platform Guardrails
- **No Cloud Backend / No User Account:** No signup, authentication servers, Firebase, Supabase, AWS, or remote databases.
- **No Telemetry / No Analytics:** No crash logging or usage tracking sent to external hosts.
- **No External AI APIs:** No cloud LLM/ML classification services that transmit financial messages off-device.
- **On-Device Data Sovereignty:** All database storage, parser execution, deduplication, and calculations happen strictly on the local device.
- **Synthetic Data for Development:** Only synthetic and redacted SMS fixtures (`MERCHANT_A`, `XX1234`, `REF_X`) are permitted in source code and test fixtures.

### 1.3 Out of Scope for MVP
- Public Apple App Store publication or multi-user enterprise features.
- Automated bank scraping, open banking APIs, or payment initiation.
- Guaranteed real-time background processing while the app is closed (iOS App Intents process queued messages upon app opening/foregrounding).
- Android SMS inbox integration (possible future phase after iOS workflow is fully validated).

---

## 2. Financial Correctness Principles

1. **Integer Paise Precision:**
   - Money is strictly stored and calculated in Indian Paise as integers (`int`).
   - Example: ₹1,234.56 is stored as `123456`.
   - Floating-point representations (`double`) are strictly prohibited in financial logic to prevent IEEE-754 precision loss.
2. **Four Canonical Transaction Types:**
   - `expense`: External outflow (purchases, utility bills, subscriptions).
   - `income`: External inflow (salary, external deposits, refunds).
   - `transfer`: Movement between user-owned accounts (credit card bill payments, bank-to-bank own transfers). **Transfers do not inflate income or expense totals.**
   - `needsReview`: Incomplete or ambiguous parses that require user confirmation before affecting totals.
3. **Credit Card Financial Logic:**
   - A credit card purchase/swipe is an **expense**.
   - A later bank payment paying the user's credit card bill is a **transfer** (not a second expense).
4. **Deterministic Deduplication:**
   - Uses unique bank/UPI reference numbers (RRN, UTR, UPI Ref) as primary deduplication identifiers.
   - Secondary fallback uses a safe fingerprint (amount + direction + account hint + 60-minute time window).
   - Ambiguous matches are routed to the **review queue** rather than silently merged or discarded.
5. **Conservative Uncertainty Handling:**
   - If an SMS contains conflicting signals (e.g. "debited" but "transaction failed"), it is classified as `needsReview`.

---

## 3. Architecture & Internal API Specifications

### 3.1 Layer Boundaries
```
┌────────────────────────────────────────────────────────┐
│               Flutter UI Presentation                  │
│  (Screens, Reusable Widgets, Theme, Declarative Router) │
└──────────────────────────┬─────────────────────────────┘
                           │ Watches / Reads
┌──────────────────────────▼─────────────────────────────┐
│          Riverpod Application & State Layer            │
│  (Providers, Filter Notifiers, Streams, ViewModels)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Calls typed interfaces
┌──────────────────────────▼─────────────────────────────┐
│         Domain Services & Pure Business Logic          │
│  (Parser Rules, Deduplication, Transfer Detector, etc)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Persists / Retrieves
┌──────────────────────────▼─────────────────────────────┐
│             Data Repositories & Drift ORM              │
│       (Local SQLite Database with 5 Typed Tables)       │
└────────────────────────────────────────────────────────┘
```
- **Rule:** Widgets must never execute raw SQL, regex parsing, or financial math. All data access is mediated by Riverpod providers calling typed repository contracts.

### 3.2 Internal Typed Service & Repository Contracts
All internal contracts are pure Dart interfaces defined in `lib/domain/services/service_contracts.dart`:
1. `TransactionRepository`: Persistence operations (CRUD, filtering, real-time streams, pending count).
2. `AccountRepository`: Bank/card account metadata management (masking last 4 digits).
3. `CategoryRepository`: Category hierarchy management with protection for system-seeded categories.
4. `SmsIngestionService`: End-to-end pipeline coordinating parser, deduplicator, transfer detector, categorizer, and database write.
5. `TransactionParser`: Pure parsing engine outputting `ParsedCandidate`, `ParseNeedsReview`, or `ParseIgnored`.
6. `DeduplicationService`: Evaluates candidates against historical records for duplicate detection.
7. `TransferDetectionService`: Distinguishes own-account movements from external spending.
8. `CategorizationService`: Keyword-based suggestion engine with user correction memory.
9. `AnalyticsService`: Aggregates monthly summaries and category breakdowns.
10. `ImportExportService`: CSV statement import preview, validation, and export generation.
11. `SecurityService`: Local device authentication (Face ID / Touch ID / Passcode) and app lock state.

---

## 4. iOS Capture Workflow & POC Context

### 4.1 iOS Platform Constraints
iOS does not provide third-party applications with background access to the SMS inbox. The ingestion route relies on:
1. **Shortcuts Personal Automation:** User configures a local trigger on their iPhone for incoming Messages.
2. **Swift App Intent:** Automation forwards the message body into a local App Group container / queue.
3. **Flutter App Ingestion:** When PaisaLog opens or comes to the foreground, the queue is drained and processed into the local Drift database.

### 4.2 Proof of Concept (POC) Gate
- **Status:** Unverified on device. Windows development does not support direct iOS signing/debugging.
- **Requirement:** The capture path must be proven on the actual iPhone 17 Pro Max using synthetic messages before being declared complete.
- **Fail-safe Fallback:** Manual add/edit/delete, clipboard paste, and CSV statement imports are already fully functional as primary alternatives.

---

## 5. Decision Log (DECISIONS.md Summary)

| ID | Topic | Working Decision | Status |
|----|-------|------------------|--------|
| SD-001 | Money Precision | Integer paise only (`int`). Zero floating-point arithmetic. | Settled |
| SD-002 | Offline Architecture | Local-first. No cloud backend, sync, or telemetry. | Settled |
| SD-003 | State Management | `flutter_riverpod` + code generation. | Settled |
| SD-004 | Declarative Routing | `go_router` with `StatefulShellRoute` (4 bottom tabs). | Settled |
| SD-005 | Persistence | Drift ORM with local SQLite. | Settled |
| SD-006 | Device Security | `local_auth` (Face ID / Passcode) stubbed; Keychain storage. | Settled |
| D-001 | iOS Installation | Personal install via macOS CI (GitHub Actions / Codemagic). | Open |
| D-003 | Database Encryption | Plain SQLite for MVP. SQLCipher upgrade deferred until iOS verification. | Open |
| D-005 | SMS Timing | Local queuing processed upon app foreground. | Open |

---

## 6. Codebase File Structure Map

```
d:\Expense tracker\paisalog\
├── lib\
│   ├── app\
│   │   ├── app.dart                   # Root MaterialApp with theme & router
│   │   ├── providers.dart             # Riverpod providers & synthetic data
│   │   ├── router.dart                # go_router StatefulShellRoute configuration
│   │   ├── theme.dart                 # PaisaColors, PaisaSpacing, PaisaThemeExtension
│   │   └── widgets\
│   │       ├── amount_display.dart    # Formatted integer paise currency widget
│   │       ├── category_chip.dart     # Color-coded category badge with icon
│   │       ├── confirmation_dialog.dart # Destructive action alert modal
│   │       ├── empty_state.dart       # Empty/error/caught-up placeholders
│   │       ├── loading_state.dart     # Centered loading progress indicator
│   │       ├── review_banner.dart     # Actionable review counter banner
│   │       ├── summary_card.dart      # Income/Expense/Savings metric card
│   │       └── transaction_row.dart   # Interactive ledger list item
│   ├── data\
│   │   ├── database\
│   │   │   ├── app_database.dart      # Drift database connection & migrations
│   │   │   └── tables.dart            # Table schemas (Accounts, Categories, Transactions, etc)
│   │   ├── importers\
│   │   │   └── import_export_service.dart # CSV round-trip preview and export
│   │   └── repositories\
│   │       ├── account_category_repositories.dart # Account & Category Drift DAOs
│   │       ├── security_service.dart  # Device unlock & biometric service
│   │       └── transaction_repository.dart # Transaction Drift DAO with filters & streams
│   ├── domain\
│   │   ├── models\
│   │   │   └── models.dart            # Money, Transaction, Account, Category, Enums, Results
│   │   └── services\
│   │       ├── domain_services.dart   # Deduplication, Transfer, Categorization services
│   │       ├── service_contracts.dart # 10 abstract interfaces
│   │       ├── sms_ingestion_service.dart # End-to-end processing pipeline
│   │       └── sms_parser.dart        # Deterministic regex parser with ignore guards
│   ├── features\
│   │   ├── dashboard\
│   │   │   └── dashboard_screen.dart  # Home tab (net savings, cards, review banner, recent)
│   │   ├── insights\
│   │   │   └── insights_screen.dart   # Insights tab (income vs expense bar, month nav)
│   │   ├── review_queue\
│   │   │   └── review_queue_screen.dart # Review queue tab (ambiguous parses & resolution)
│   │   ├── settings\
│   │   │   └── settings_screen.dart   # Settings tab (accounts, categories, privacy, CSV)
│   │   └── transactions\
│   │       ├── transaction_detail_screen.dart # Full metadata view & delete action
│   │       ├── transaction_editor_screen.dart # Add/edit form with integer validation
│   │       └── transactions_screen.dart # Searchable & filterable ledger view
│   ├── main.dart                      # Flutter app entry point (ProviderScope)
│   └── platform\
│       └── ios_capture\
│           └── ios_capture_adapter.dart # Stub capture adapter (isCaptureVerified = false)
├── test\
│   ├── dedupe\
│   │   └── deduplication_test.dart    # 8 deduplication and transfer tests
│   ├── fixtures\
│   │   └── sms_corpus_synthetic.csv   # 15 synthetic bank SMS test cases
│   ├── parser\
│   │   └── sms_parser_test.dart       # 16 parser, paise precision, and boundary tests
│   └── widgets\
│       └── ui_screens_test.dart       # 6 UI widget tests for dashboard, transactions & review
├── analysis_options.yaml              # Code quality & float-money lint rules
└── pubspec.yaml                       # Package dependencies & assets
```

---

## 7. Live Project Checklist

### ✅ Completed & Verified

1. **Environment & Tooling**
   - [x] Flutter SDK 3.47.8 & Dart 3.13.7 configured at `D:\flutter\bin`.
   - [x] Package resolution complete (`flutter pub get` — 146 dependencies).
   - [x] Drift and Riverpod code generation complete (`build_runner` — 119 outputs).
   - [x] Git repository initialized and pushed to GitHub (`vinayakbanga/Expensetracker`).
   - [x] Codemagic cloud macOS CI pipeline configured (`codemagic.yaml` with M2 Mac, Flutter stable, build & test).
   - [x] iOS native project scaffolding generated (`ios/Runner.xcodeproj`, `Info.plist`, assets, schemes) and pushed to GitHub.

2. **Domain & Business Logic**
   - [x] `Money` object with integer paise arithmetic and display formatting.
   - [x] 10 typed service contracts implemented.
   - [x] SMS Parser covering OTPs, promotions, balance notices, debits, UPI, credit cards, bill payments, and own transfers.
   - [x] Reference-first deduplication with time-window heuristic fallback.
   - [x] Transfer detection distinguishing purchases from bill payments.
   - [x] Ingestion pipeline coordinating all domain services.

3. **Persistence & Data Layer**
   - [x] 5 Drift database tables with integer money columns.
   - [x] 11 pre-seeded system categories.
   - [x] Drift repositories supporting CRUD, search queries, and real-time reactive streams.
   - [x] CSV Import/Export service with row validation and duplicate prevention.

4. **UI & Design System**
   - [x] Full design system with Light and Dark modes.
   - [x] Declarative bottom navigation with `go_router` (4 tabs).
   - [x] 8 reusable UI components.
   - [x] 7 screens (Dashboard, Transactions, Detail, Editor, Review Queue, Insights, Settings).

5. **Automated Testing Suite (38 / 38 Tests Passing)**
   - [x] 16 SMS Parser & Money tests (`sms_parser_test.dart`).
   - [x] 8 Deduplication & Transfer tests (`deduplication_test.dart`).
   - [x] 6 Screen Widget tests (`ui_screens_test.dart`).

---

## 8. Active & Next Priorities

- [ ] **Task 1: Complete Settings Sub-Screens**
  - Accounts management (`/settings/accounts`)
  - Categories management (`/settings/categories`)
  - App Lock / biometric preferences (`/settings/privacy`)
  - CSV Import/Export UI with preview dialog (`/settings/import-export`)
- [ ] **Task 2: Implement Category Breakdown Chart in Insights**
  - Add interactive pie chart using `fl_chart`.
- [ ] **Task 3: In-App SMS Testing & Ingestion Panel**
  - Provide an on-device/desktop testing interface to paste synthetic SMS strings and verify live parsing, deduplication, and database insertion.

---

## 9. External Blockers

1. **macOS / Xcode Environment:** Required to compile native iOS binaries and sign for the physical iPhone 17 Pro Max. (Windows provides complete Flutter/Dart testing coverage).
2. **Shortcuts Automation POC:** Physical execution on the iPhone to measure friction and background payload behavior.
3. **SQLCipher Verification:** On-device encryption verification before storing actual personal financial records.
