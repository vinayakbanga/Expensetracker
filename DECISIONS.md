# PaisaLog — DECISIONS.md

> **Source of Truth:** The pre-coding pack (documents 00–06). Conflicts or missing decisions are tracked here. Decisions that affect privacy or scope require explicit user approval before implementation.

---

## Open Decisions (Awaiting Input)

| ID | Decision | Working Assumption | Status |
|----|----------|-------------------|--------|
| D-001 | iOS installation method | Personal install (not App Store); signing via personal Apple ID or cloud Mac CI (Codemagic/GitHub Actions macOS runner) | **Open — needs user confirmation of Apple account type** |
| D-002 | Cloud Mac build service | Codemagic free tier or GitHub Actions macOS runner | **Open — must confirm signing key handling before connecting personal Apple account** |
| D-003 | Database encryption | Drift + SQLite initially; SQLCipher via `drift` + `sqlcipher_flutter_libs` once plugin compatibility on iOS is verified | **Open — cannot claim encryption is active until tested on device** |
| D-004 | Backup / restore strategy | No cloud sync; user-initiated encrypted CSV export only for MVP | **Open — document lost-device expectations before launch** |
| D-005 | SMS processing timing | Messages queued locally, processed when app opens/foregrounds | **Open — prove on actual iPhone before claiming real-time** |
| D-006 | Refund convention | Treat refund as a special income sub-type, linked to original expense if findable | **Open — no conflict with PRD but not explicitly decided** |
| D-007 | Cash withdrawal classification | `needs_review` by default; can be reclassified to transfer-to-cash if user enables a "Cash" account | **Open** |

---

## Settled Decisions

| ID | Decision | Resolution | Rationale |
|----|----------|------------|-----------|
| SD-001 | Money representation | **Integer paise only**; never `double` for financial values | PRD requirement; prevents floating-point rounding errors |
| SD-002 | No backend / no cloud API | MVP is strictly local-first | PRD requirement; privacy constraint |
| SD-003 | State management | **Riverpod** (flutter_riverpod + riverpod_annotation) | PRD spec; enables testable DI without BuildContext coupling |
| SD-004 | Routing | **go_router** | PRD spec; declarative routing suitable for bottom nav + deep links |
| SD-005 | Local persistence | **Drift** (type-safe ORM over SQLite) | PRD spec; enables migrations, type safety, test DAOs |
| SD-006 | App lock | **local_auth** (FaceID/TouchID/Passcode) | PRD spec; security review still required |
| SD-007 | Secure key storage | **flutter_secure_storage** (iOS Keychain) | PRD spec; subject to design review |
| SD-008 | Transaction classification | 4 canonical types: `income`, `expense`, `transfer`, `needs_review` | PRD requirement |
| SD-009 | Credit-card purchase vs. bill payment | Purchase = `expense`; bill payment = `transfer` (not second expense) | PRD requirement; financial correctness |
| SD-010 | Own-account transfer | Neither income nor expense; `type = transfer` | PRD requirement |
| SD-011 | Uncertain parses | Always go to `needs_review` queue; never silently guessed | PRD requirement |
| SD-012 | No external AI APIs | No off-device ML/LLM for classification in MVP | PRD privacy constraint |
| SD-013 | Development platform | Windows for Flutter/Dart logic; iOS build requires macOS/Xcode | PRD constraint |
| SD-014 | Flutter SDK | Stable channel, latest stable at time of install | Doc 05 |
| SD-015 | iOS capture fallback | Manual paste/share + CSV import are always available; Shortcuts/App Intents is additive | PRD constraint |

---

## Dependencies Added (with Justification)

| Package | Purpose | Version Constraint | Doc Reference |
|---------|---------|-------------------|---------------|
| `flutter_riverpod` | State management + DI | ^2.x | SD-003 |
| `riverpod_annotation` | Code-gen for providers | ^2.x | SD-003 |
| `go_router` | Declarative routing | ^14.x | SD-004 |
| `drift` | Type-safe SQLite ORM | ^2.x | SD-005 |
| `sqlite3_flutter_libs` | Native SQLite binaries | ^0.5.x | SD-005 |
| `path_provider` | App documents directory | ^2.x | SD-005 |
| `local_auth` | Biometric / device auth | ^2.x | SD-006 |
| `flutter_secure_storage` | Keychain key storage | ^9.x | SD-007 |
| `intl` | Date/number formatting | ^0.19.x | UI formatting |
| `fl_chart` | Insights charts | ^0.68.x | Doc 06 Insights screen |
| `shared_preferences` | App settings (non-sensitive) | ^2.x | Settings screen |
| `uuid` | Stable local primary keys | ^4.x | SD-001 data model |
| `csv` | CSV import/export | ^6.x | ImportExportService |
| `file_picker` | File picker for import | ^8.x | ImportExportService |
| `share_plus` | Share/export files | ^10.x | ImportExportService |
| `build_runner` | Code generation | dev | Drift + Riverpod codegen |
| `drift_dev` | Drift code generator | dev | SD-005 |
| `riverpod_generator` | Riverpod provider codegen | dev | SD-003 |
| `custom_lint` | Riverpod lint rules | dev | Code quality |
| `riverpod_lint` | Riverpod-specific lints | dev | Code quality |
| `mocktail` | Mocking in unit tests | dev | Testing |

> **SQLCipher:** NOT added yet. Will be added as `sqlcipher_flutter_libs` only after verifying plugin compatibility on iOS (Decision D-003). Until then, plain SQLite is used.

---

## Privacy-Affecting Choices Log

| Date | Item | Decision |
|------|------|----------|
| 2026-10-28 | SMS raw text retention | Do NOT persist raw SMS body in production database; keep only safe derived fields + a SHA-256 fingerprint for dedup. Redaction happens before any persistence. |
| 2026-10-28 | Logs | Never log raw SMS bodies, full account numbers, OTPs, or references in release builds. |
| 2026-10-28 | Export | Export is an explicit user action; app warns that exported CSV may be unencrypted. |
| 2026-10-28 | Test fixtures | Only synthetic/redacted SMS patterns allowed in test/ directory and source control. |

---

*Last updated: 2026-10-28 by coding agent. Update whenever a new dependency, privacy choice, or architectural change is made.*

