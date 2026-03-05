# AGENTS.md

## Project

**Name:** ScreenFlow — On-Screen Understanding → One-Tap Action Packs  
**Platform:** iOS (iPhone-first, iPad-compatible)  
**Framework:** Swift, SwiftUI, Vision, Apple Intelligence / On-device ML, Shortcuts integration

---

## Purpose

This repository defines the architecture, scope, and implementation of ScreenFlow, an iOS app that analyzes screenshots or on-screen content and generates deterministic, structured, one-tap actions.

Primary goals:

- Deterministic screenshot understanding pipeline
- Structured extraction of actionable UI elements
- Explicit, reproducible action generation
- One-tap execution of relevant actions
- Privacy-first, on-device processing whenever possible
- Machine-readable extraction artifacts
- Predictable and explainable behavior

Default focus:

- Deterministic extraction pipeline
- Explicit action generation logic
- Contract-first data models
- Reproducibility of extraction results
- Clear separation between detection, interpretation, and action layers

Primary deployment target: iOS App Store.

Implementation must always preserve reproducibility, predictability, and privacy guarantees.

---

## How To Work Here

- Prefer small, scoped changes.
- Complete one task at a time unless multiple tasks are tightly coupled.
- Do not complete entire phases at once unless explicitly required.
- For any iOS-development task, proactively use the `ios-development` skill at `~/.codex/skills/ios-development/SKILL.md`.
- Every change must preserve determinism and reproducibility where applicable.
- Keep logic explicit and testable.
- Use ASCII-only content unless Unicode already exists.
- Project anchors are `scope.md` and `task.md`.
- Update `scope.md` when architecture, pipelines, models, or guarantees change.
- Update `task.md` as execution progresses.
- Tick completed tasks in `task.md` immediately (`[ ]` -> `[x]`).
- Provide a suggested commit message after task completion.
- Update `README.md` when user-visible behavior changes.
- Run code review and apply critical fixes after major implementation milestones.
- If `context.md` exists, read it first and anchor decisions to it.

---

## Core Design Principles

- Deterministic-first extraction pipeline
- Explicit extraction and action generation rules
- Privacy-first architecture
- Predictability over convenience
- Reproducibility of extraction results
- No hidden state
- Explainable action generation
- Strong separation between extraction, interpretation, and execution

---

## Files Of Interest

- `AGENTS.md`: Contributor operating rules.
- `scope.md`: Product definition, architecture, and acceptance criteria.
- `task.md`: Execution plan and status tracker.
- `README.md`: User-facing documentation.
- `context.md`: Project state anchor (if present).
- `docs/assumptions.md`: Explicit assumptions log.
- `docs/timeline.md`: Milestones and release plan.

Source structure:

- `ScreenFlowApp.swift`: App entry point.
- `Core/`: Core pipelines, models, and services.
- `Features/`: Feature modules.
- `UI/`: SwiftUI views.
- `Services/`: Extraction, interpretation, and execution services.
- `Models/`: Typed data structures.
- `Tests/`: Unit and integration tests.

---

## Architecture Contracts

The pipeline must remain strictly stage-separated.

### 1. Input Stage

Responsibilities:

- Screenshot ingestion
- Image normalization
- Metadata capture

Outputs:

- `ScreenshotArtifact`

---

### 2. Extraction Stage

Responsibilities:

- OCR text extraction
- UI element detection
- Layout parsing

Outputs:

- `ExtractionResult`
- `ExtractedTextBlock`
- `ExtractedUIElement`

---

### 3. Interpretation Stage

Responsibilities:

- Context classification
- Intent inference
- Action candidate generation

Outputs:

- `IntentClassification`
- `ActionCandidate[]`

---

### 4. Action Planning Stage

Responsibilities:

- Deterministic action mapping
- Action validation
- Action prioritization

Outputs:

- `ActionPlan`

---

### 5. Execution Stage

Responsibilities:

- Action execution
- Shortcuts integration
- System API invocation

Outputs:

- `ExecutionResult`

---

### 6. Reporting Stage

Responsibilities:

- Artifact generation
- Logging
- Debug trace capture

Outputs:

- Extraction and execution artifacts

---

Each stage must have:

- Explicit typed inputs
- Explicit typed outputs
- Versioned schemas
- No hidden state

---

## Data Model Rules

All core data structures must be strongly typed.

Use:

- Swift structs
- Codable models
- Explicit schema versions

Core models include:

- `ScreenshotArtifact`
- `ExtractedTextBlock`
- `ExtractedUIElement`
- `ExtractionResult`
- `IntentClassification`
- `ActionCandidate`
- `ActionPlan`
- `ExecutionResult`

Rules:

- Do not use untyped dictionaries for core logic
- Schema changes must increment version
- Models must remain backward compatible where possible

---

## Determinism And Reproducibility Rules

Every extraction run must record:

- App version
- Extraction pipeline version
- Model version
- Device type
- iOS version
- Screenshot hash
- Processing timestamp
- Extraction schema version

Never:

- Mutate prior extraction results silently
- Reuse extraction IDs for different inputs
- Change extraction logic without version bump

If nondeterministic ML is used:

- Record model version
- Record configuration
- Mark extraction as nondeterministic

---

## Action Contract Rules

Each action must include:

- Stable identifier
- Explicit trigger conditions
- Required inputs
- Execution handler
- Execution result format

Example actions:

- Open URL
- Add calendar event
- Add reminder
- Copy text
- Create note
- Open app deep link
- Execute Shortcut

Rules:

- Actions must be explicit and deterministic
- Do not execute unsafe or ambiguous actions automatically
- Require confirmation when needed

---

## Testing Standards

Tests are mandatory for:

- Screenshot ingestion
- OCR extraction pipeline
- Element detection logic
- Intent classification
- Action planning logic
- Action execution handlers
- Artifact schema validation

Tests must cover:

- Valid screenshots
- Edge cases
- Partial extraction scenarios
- Ambiguous contexts
- Deterministic repeat runs

If code changes:

- Update tests
- Run tests
- Verify deterministic outputs

---

## Artifact Contract

Extraction artifacts must remain stable.

Recommended artifacts:

- `extraction.json`
- `action-plan.json`
- `execution.json` (if executed)

Artifacts must include:

- Schema version
- Screenshot hash
- Pipeline version
- Timestamp

If artifact format changes:

- Update `scope.md`
- Update `README.md`
- Update tests

---

## Error Taxonomy

Use typed errors:

- `ScreenshotLoadError`
- `ExtractionError`
- `OCRProcessingError`
- `ClassificationError`
- `ActionPlanningError`
- `ExecutionError`
- `ArtifactWriteError`
- `SchemaValidationError`

Errors must:

- Be explicit
- Be testable
- Be logged

---

## Documentation Sync Rules

If any of the following change:

- Pipeline architecture
- Data models
- Artifact formats
- Action contracts
- Execution behavior

You must update:

- `scope.md`
- `README.md`
- `task.md`
- Tests

Documentation drift is not acceptable.

---

## Assumptions Log

If introducing assumptions about:

- OCR reliability
- Vision framework behavior
- Apple Intelligence APIs
- iOS limitations
- Performance constraints

Update:

`docs/assumptions.md`

Include:

- Date
- Assumption
- Reason

---

## Operating Mindset

This is production-grade mobile infrastructure, not a demo.

Every decision must optimize for:

- Predictability
- Traceability
- Deterministic behavior where possible
- Privacy-first architecture
- Strong engineering rigor

If a design reduces predictability or explainability, it is the wrong design.
