# PaisaLog — Project Status & Roadmap

> **Single Source of Truth for Progress & Checklist**
> Last updated: 2026-10-29 11:05 IST

---

## 📌 Project Overview
PaisaLog is a personal, iPhone-first, local-first SMS-based expense tracker built with Flutter/Dart.
- **Privacy & Storage:** 100% offline, local-first on SQLite/Drift. No backend, no accounts, no cloud sync, no analytics, no external AI APIs.
- **Financial Precision:** All amounts stored as strictly integer paise (1 INR = 100 paise). Zero floating-point math for money.
- **Classification:** 4 canonical types: `income`, `expense`, `transfer`, `needsReview`.
- **Deduplication & Safe Parsing:** Exact bank/UPI reference matching with time-window heuristic fallback. Uncertain parses always route to the review queue instead of guessing.

---

## 📋 Comprehensive Checklist

### 1. Environment & Project Foundation
- [x] Pre-coding specifications reviewed (00–06 docx + SMS template)
- [x] Flutter SDK 3.47.8 & Dart 3.13.7 configured and verified (`D:\flutter\bin`)
- [x] Git repository initialized with strict `.gitignore` (excludes DB files, secrets, real SMS)
- [x] Package dependencies installed & resolved (`flutter pub get` — 146 dependencies)
- [x] Code-generation pipeline verified (`build_runner` with 119 outputs generated)
- [x] Decisions logged in `DECISIONS.md`
- [x] Initial clean baseline committed to Git (`master`)

### 2. Domain Layer (Pure Dart — No Framework/IO Coupling)
- [x] `Money` value object (integer paise arithmetic, exact Rupee string parser, display formatter)
- [x] Canonical data models: `Transaction`, `Account`, `Category`, `TransactionFilters`, `MonthlySummary`, `CategoryBreakdownItem`, `SpendingTrendPoint`, `Result<T>`, `AppError`
- [x] 10 typed internal Dart interfaces:
  - `TransactionRepository`, `AccountRepository`, `CategoryRepository`
  - `SmsIngestionService`, `TransactionParser`, `DeduplicationService`
  - `TransferDetectionService`, `CategorizationService`, `AnalyticsService`
  - `ImportExportService`, `SecurityService`
- [x] Deterministic regex SMS Parser:
  - High-priority ignore guards: OTPs, promotional SMS, balance-only notifications
  - Transaction rules: Generic debits, UPI formats, Credit card purchases
  - Credit card bill payment classifier (classified as transfer, not second expense)
  - Own-account transfer recognition
- [x] Deduplication service (reference ID comparison + time-window fallback)
- [x] Transfer detection service (counterparty verification against known user accounts)
- [x] Categorization service (keyword matching + user correction learning)
- [x] SMS ingestion pipeline service (`sms_ingestion_service.dart`)

### 3. Data & Persistence Layer
- [x] Drift schema with 5 tables: `AccountsTable`, `CategoriesTable`, `TransactionsTable`, `IngestionQueueTable`, `UserCorrectionsTable`
- [x] Pre-seeded with 11 standard system categories
- [x] `DriftTransactionRepository` (CRUD, filtering, real-time reactive streams)
- [x] `DriftAccountRepository` & `DriftCategoryRepository` (system category protection)
- [x] `DefaultImportExportService` (CSV import preview with row validation, CSV export)
- [x] `DefaultSecurityService` (local_auth biometric & lock stubs)

### 4. Presentation Layer & UI Design System
- [x] `PaisaTheme` supporting both Light and Dark themes, custom `PaisaThemeExtension` for semantic finance colors
- [x] Declarative bottom navigation with `go_router` (`StatefulShellRoute` with 4 tabs)
- [x] 8 reusable UI components:
  - `AmountDisplay` (integer paise formatted with color coding and sign)
  - `TransactionRow` (interactive row with category indicator and review badges)
  - `SummaryCard` (stat card with shimmer loading state)
  - `EmptyState` (custom states for no transactions, empty review queue, and errors)
  - `CategoryChip` (badge with icon and category color)
  - `ReviewBanner` (actionable pending count banner linking to `/review`)
  - `LoadingState` (full-screen centered progress indicator)
  - `ConfirmationDialog` (alert modal for destructive actions like delete)
- [x] 7 screens:
  - **Home (Dashboard):** Net savings summary, income/expenses cards, pending review banner, recent transactions list
  - **Transactions:** Real-time searchable & filterable list (all, expenses, income, transfers, review)
  - **Transaction Details:** Complete transaction metadata display and delete action
  - **Transaction Editor:** Add/edit form with integer paise validation, type selector, and date/time picker
  - **Review Queue:** Card list of unclassified or ambiguous SMS items with reason and resolution actions
  - **Insights:** Income vs expense comparison bar, net savings indicator, and month navigator
  - **Settings:** Hub for account/category management, privacy info, export warnings, and iOS Shortcuts status

### 5. Automated Testing Suite
- [x] **38 / 38 Tests Passing (`flutter test`)**
  - **16 Parser Tests (`sms_parser_test.dart`):**
    - T-001: Generic debit parsing & paise precision
    - T-002: Salary credit parsing
    - T-003: UPI payment & reference ID extraction
    - T-004: Credit card purchase as expense
    - T-005: Credit card bill payment as transfer (not duplicate expense)
    - T-006: Own-account transfer detection
    - T-007: Balance-only message ignored
    - T-008: OTP message ignored
    - T-009: Promotional message ignored
    - T-010: Failed transaction routed to review queue
    - T-011: Missing amount routed to review queue
    - T-015: Exact decimal paise arithmetic (e.g., ₹1,234.56 = 123456 paise)
    - Money class integer parsing and display formatting
    - MonthlyPeriod month-rollover boundaries
  - **8 Deduplication & Transfer Tests (`deduplication_test.dart`):**
    - Exact reference ID deduplication
    - Non-matching reference ID handling
    - Time-window + amount heuristic uncertainty flagging
    - T-012: Repeated identical SMS deduplicated
    - Transfer classification with known accounts
  - **6 UI Widget Tests (`ui_screens_test.dart`):**
    - Dashboard header and summary cards rendering
    - Review banner display when items pending
    - Transactions screen search bar and filter chips
    - Filter chip interaction
    - Review queue cards and reason visibility
    - Empty state rendering when review queue is clear
  - **Synthetic Test Corpus:** `sms_corpus_synthetic.csv` with 15 synthetic bank messages

---

## 🔄 What Is Next (Immediate Priorities)

1. **Complete Settings Sub-Screens:**
   - [ ] Accounts management view (`/settings/accounts`)
   - [ ] Categories management view (`/settings/categories`)
   - [ ] App Lock / biometric security settings (`/settings/privacy`)
   - [ ] CSV import preview & file picker integration (`/settings/import-export`)
2. **Category Breakdown in Insights:**
   - [ ] Implement `CategoryBreakdown` chart using `fl_chart`
3. **Synthetic SMS Ingestion Tester:**
   - [ ] Add an in-app developer/testing panel to paste synthetic SMS strings and test immediate parsing, deduplication, and ledger storage in real-time.

---

## 🔴 External Blockers & Constraints

| Blocker | Impact | Next Action / Resolution |
|---------|--------|--------------------------|
| **macOS / Xcode required for iOS build** | Windows cannot compile or sign iOS `.ipa` files directly | Build using cloud macOS runner (GitHub Actions / Codemagic) or on a physical Mac when ready for on-device deployment |
| **Shortcuts + App Intents verification** | Cannot verify background SMS trigger on Windows | Test using personal automation on physical iPhone per `04_iPhone_SMS_Capture_POC.docx` once iOS build target is established |
| **SQLCipher verification** | Currently running plain SQLite via Drift | Test `sqlcipher_flutter_libs` compatibility before storing real financial data |
