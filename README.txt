PAISALOG PRE-CODING PACK

Start with 00_Start_Here.docx, then read the numbered documents in order.
The pack is based on the existing PaisaLog PRD and preserves its key decisions:
- iPhone-first, personal-use app
- local-first / no backend / no analytics
- Flutter/Dart shared codebase
- iOS Shortcuts + App Intents capture path must be proven early
- manual/share/statement import are fallback paths
- integer paise, dedupe, transfer detection, and review for uncertainty

Privacy: the CSV contains synthetic examples only. Do not paste raw bank SMS,
OTPs, full account numbers, or personal data into shared/cloud tools or source control.

These are planning documents, not proof that iOS automation or a chosen encryption
plugin will work on the current device. The capture and encryption integrations
must be validated before relying on them.

UPDATED CONTENTS
- 06_UI_UX_and_Internal_API_Spec.docx: UI screens, design system, internal Dart service contracts, testing checklist, definition of done.
- UPDATED_CODING_AGENT_PROMPT.txt: revised copy/paste prompt including UI and API architecture requirements.
Existing documents 00, 01, 02, and 05 have also been updated with UI/API addenda.
