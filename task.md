# task.md

## Rules
- [x] Always tick tasks immediately after completion by changing `[ ]` to `[x]`.

# ScreenFlow Task Breakdown

## 1. Project Setup
- [x] Confirm minimum iOS version target and deployment settings.
- [x] Configure app bundle identifiers and App Group container (if share extension is in MVP).
- [x] Set up app capabilities: Photos, Calendar (EventKit), App Group, File access (as needed).
- [x] Define build configurations (Debug/Release) and info plist privacy strings.
- [x] Create a basic app architecture folder structure in Xcode.

## 2. Data Model and Storage
- [x] Decide between SwiftData and Core Data based on iOS target.
- [x] Define/extend models: ScreenRecord, OCRArtifact, LLMResult, ExtractionResult, ActionPackRun.
- [x] Implement file storage paths in Application Support and App Group container.
- [x] Add stable screen identifier generation (sha256 of normalized image + processing version).
- [x] Build persistence layer and basic repository API.

## 3. Import and Ingestion
- [x] Build share sheet extension flow (if MVP): accept image input, write to App Group.
- [x] Build in-app import via photo picker.
- [x] Normalize images for hashing and OCR.
- [x] Store original image and metadata.

## 4. OCR Pipeline (On-Device)
- [x] Integrate Vision OCR (VNRecognizeTextRequest).
- [x] Normalize OCR output into `OCRBlockSpec.v1` (deterministic JSON).
- [x] Persist OCR artifacts.
- [x] Add language hint configuration.

## 5. Local/Open Model Interpretation Pipeline
- [x] Define `ScreenFlowSpec.v1` schema (scenario, confidence, entities, packSuggestions, modelMeta).
- [x] Implement local/open-model client with explicit model/prompt versioning.
- [x] Build OCRBlockSpec -> ScreenFlowSpec request mapping.
- [x] Implement scenario classification via model output.
- [x] Implement entity extraction via model output.
- [x] Implement action pack suggestion extraction via model output.
- [x] Persist raw and validated LLM artifacts (`LLMResult`).
- [x] Add provider abstraction for on-device and self-hosted open models only (no paid provider dependency).

## 6. Validation and Canonicalization
- [x] Implement strict JSON parse + schema validation for model responses.
- [x] Implement type/unit normalization (ISO8601 dates, salary/currency normalization, whitespace cleanup).
- [x] Implement deterministic canonicalization (stable key ordering and deterministic array ordering rules).
- [x] Add one automatic model repair pass for invalid outputs.
- [x] Implement fallback heuristic extraction when repair fails.
- [x] Persist canonical validated extraction results.

## 7. Intent Graph
- [x] Define graph schema (nodes, edges, types).
- [x] Build graph from entities and scenario.
- [x] Persist intent graph JSON.

## 8. Action Pack System
- [x] Define Action Pack schema (Swift structs or JSON/YAML).
- [x] Implement pack registry and selection logic.
- [x] Build pack validation (required entities, types, preconditions).
- [x] Implement step execution engine and trace recording.

## 9. MVP Action Packs
- [x] job_listing:
  - [x] Save to Job Tracker (JSON export).
  - [x] Draft Application Email (deterministic outline, optional cloud draft).
- [x] event_flyer:
  - [x] Add to Calendar (EventKit).
  - [x] Create Share Card (formatted text output).
- [x] error_log:
  - [x] Generate GitHub Issue Template (markdown).
  - [x] Create Debug Checklist.

## 10. Integrations
- [x] EventKit integration for calendar events.
- [x] Clipboard export support.
- [x] File export support (markdown/JSON).
- [x] Optional URL opening.

## 11. UI and UX
- [x] Home library list of screens.
- [ ] Screen detail view with scenario, entities, pack suggestions.
- [ ] Edit entities before pack execution.
- [ ] Pack execution screen with step-by-step progress and outputs.
- [ ] Settings screen: cloud drafting toggle, data retention, privacy mode.

## 12. Determinism and Replay
- [x] Ensure deterministic output from OCR artifacts and validation/canonicalization rules.
- [x] Add versioning for OCR schema, extraction schema, prompt versions, models, and packs.
- [x] Build replay system for stored OCR artifacts.
- [ ] Add recorded-model replay mode for deterministic local re-runs.

## 13. Testing
- [ ] Unit tests for schema validation, canonicalization, pack binding, and execution engine.
- [ ] Golden tests for canonical `ScreenFlowSpec` outputs from fixture OCR inputs.
- [ ] Ensure golden tests run without live model endpoint calls.
- [ ] Add recorded-response tests for model normalization/replay.
- [ ] Integration tests on fixed OCR corpus.
- [ ] UI tests: import -> view -> run pack -> verify result.
- [ ] Performance tests for OCR latency, model latency (median/P95), and full pipeline speed.

## 14. Privacy and Security
- [ ] Ensure no outbound network calls by default; only allow explicit user-configured local/self-hosted model endpoints.
- [ ] Store tokens in Keychain if needed.
- [ ] Add explicit model-consent controls (off by default) and disclosure copy.
- [ ] Add data sharing mode: OCR text-only vs image+text to model runtime.
- [ ] Add privacy mode to blur thumbnails.
- [ ] Draft privacy policy if distributing publicly.

## 15. Local Model Reliability Controls
- [ ] Define local/open model runtime decision and fallback policy.
- [ ] Add resource guardrails for on-device/local model inference (latency, memory, battery budget).
- [ ] Add timeout/retry budget strategy for model calls.

## 16. Release Readiness
- [ ] Validate acceptance criteria (MVP).
- [ ] Perform end-to-end manual QA on supported scenarios.
- [ ] App Store compliance checks.
- [ ] Prepare TestFlight builds.

## 17. Later (Post-MVP) Action Packs
- [ ] travel_confirmation:
  - [ ] Create Itinerary Summary (deterministic markdown export).
  - [ ] Add Trip to Calendar (flight/hotel timeline via EventKit).
- [ ] invoice_receipt:
  - [ ] Export Expense Entry (canonical JSON/CSV output).
  - [ ] Draft Expense Report Note (deterministic template output).
