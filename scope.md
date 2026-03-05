# scope.md

# ScreenFlow: Local-Model On-Screen Understanding -> One-Tap Action Packs

Project codename: `screenflow`

---

## 1. Purpose

ScreenFlow converts screenshots into structured, machine-validated understanding using local/open models, then executes one-tap Action Packs (multi-step workflows).

Unlike simple OCR apps, ScreenFlow:

- Uses local/open models to interpret screen meaning
- Enforces strict JSON schemas for structure
- Validates and normalizes outputs deterministically
- Executes structured workflows from the validated result
- Stores execution traces for replay and inspection

This is an AI-first mobile product with deterministic guardrails and no paid LLM dependency.

---

## 2. Core Value Proposition

Input:
Screenshot or shared image.

Output:
- Scenario classification
- Structured entities
- Suggested action packs
- One-tap execution
- Traceable execution history

Local/open models provide semantic understanding.
The app enforces structural correctness.

---

## 3. High-Level Architecture

Pipeline:

1. Import image
   - In-app picker import and Share Sheet extension import
   - Persist original image blob + metadata sidecar
   - Produce deterministic normalized PNG for hashing/OCR
2. On-device OCR (Vision framework, VNRecognizeTextRequest with configurable language hints)
3. Normalize OCR -> `OCRBlockSpec.v1` (deterministic JSON)
4. Local/open model interpretation call (on-device preferred, self-hosted open-model fallback):
   `OCRBlockSpec.v1` -> `ScreenFlowSpec.v1`
5. Deterministic validation + canonicalization
6. Action Pack selection
7. Pack execution engine
8. Execution trace persisted

Key rule:
Model proposes structure. Validator decides acceptance.

---

## 4. Local Model Responsibilities

### 4.1 Scenario Classification
Local/open model determines scenario:
- job_listing
- event_flyer
- error_log
- travel_confirmation (future)
- invoice_receipt (future)

### 4.2 Entity Extraction
Local/open model extracts structured typed entities:

Job:
- company
- role
- location
- skills[]
- salaryRange
- link

Event:
- title
- dateTime
- venue
- address
- link

Error:
- errorType
- message
- stackTrace
- toolName
- filePaths[]

### 4.3 Action Pack Suggestions
Local/open model suggests:
- packId
- parameter bindings
- confidence score

### 4.4 Drafting
Optional drafting features:
- Email drafts
- GitHub issue summaries
- Clean markdown exports
- Calendar descriptions

Drafting never affects structural outputs.

---

## 5. Deterministic Guardrails

### 5.1 Schema Versioning

Two required schemas:

`OCRBlockSpec.v1`
- blocks: [{text, bbox, pageSize}]
- languageHint
- source
- processingVersion

`ScreenFlowSpec.v1`
- scenario (enum)
- scenarioConfidence (0–1)
- entities (typed)
- packSuggestions[]
- optional intentGraph
- modelMeta {model, promptVersion}

All schemas versioned explicitly.

---

### 5.2 Validation Layer

After model response:

- Strict JSON parsing
- Schema validation
- Type enforcement
- Unit normalization (dates, currency)
- Canonical key ordering
- Deterministic serialization

Invalid outputs:
- One automatic repair attempt
- Otherwise fallback to heuristic extraction
- Mark result as low confidence

---

### 5.3 Canonicalization Rules

- Sort object keys alphabetically
- Sort arrays where order is not semantically meaningful
- Normalize:
  - ISO8601 date format
  - Salary to structured min/max currency
  - Trim whitespace
- Emit stable JSON for golden tests

---

## 6. Data Model

### 6.1 Storage Strategy

Structured:
- SwiftData (iOS 17+) or Core Data (if older support required)

Blobs:
- Application Support directory
  - `Screens/{screenId}.original.img`
  - `Screens/{screenId}.normalized.png`
  - `Screens/{screenId}.metadata.json` (`screenshot-artifact.v1`)

Secrets:
- Keychain

Share extension:
- App Group container

---

### 6.2 Core Entities

ScreenRecord
- id (sha256 hash of normalized image)
- imagePath
- createdAt
- scenario
- scenarioConfidence
- processingVersion

OCRArtifact
- id
- screenId
- ocrVersion
- blocksJSONPath

LLMResult
- id
- screenId
- model
- promptVersion
- rawResponseJSONPath
- validatedJSONPath
- createdAt

ExtractionResult
- id
- screenId
- schemaVersion
- entitiesJSONPath (canonical `ScreenFlowSpec.v1` JSON)
- intentGraphJSONPath (deterministic `IntentGraph.v1` JSON built from scenario and extracted entities)
- userOverridesJSONPath

ActionPackRun
- id
- screenId
- packId
- packVersion
- inputParamsJSONPath
- traceJSONPath
- status
- createdAt

---

## 7. Action Pack Engine

### 7.1 Pack Definition

ActionPack:
- id
- scenario
- requiredEntities[]
- optionalEntities[]
- steps[]

Step types (MVP):
- RenderTextTemplate
- ExportBindingsJSON (deterministic canonical JSON export)
- ExportJobTrackerJSON
- CreateCalendarEvent (EventKit-backed service)
- ExportFile (deterministic copy to `Exports/` for markdown/JSON artifacts)
- CopyTextToClipboard
- OpenURL (optional, non-failing integration step)

Execution engine currently persists deterministic run artifacts:
- `Runs/{runId}.input.json` (validated input bindings)
- `Runs/{runId}.trace.json` (`action-pack-trace.v1`)
- `Exports/{runId}.*` (explicit exported markdown/JSON artifacts when configured by pack steps)

All packs are declarative and versioned.

---

### 7.2 Execution Trace

Each run stores:

- Canonical input snapshot
- Step-by-step execution records
- Outputs
- Errors
- Duration metrics

Trace is append-only.

---

## 8. MVP Scope

### 8.1 Supported Scenarios
- job_listing
- event_flyer
- error_log

### 8.2 Action Packs

Job:
- Save structured job JSON
- Draft application email

Event:
- Add to Calendar
- Generate share card

Error:
- Generate GitHub issue markdown
- Generate debug checklist

### 8.3 Later (Post-MVP) Action Packs

Travel (`travel_confirmation`):
- Create itinerary summary (deterministic markdown export)
- Add trip timeline to calendar (EventKit)

Invoice (`invoice_receipt`):
- Export expense entry (canonical JSON/CSV output)
- Draft expense report note (deterministic template output)

---

## 9. Testing System

### 9.1 Unit Tests
- Schema validation
- Canonicalization
- Pack parameter binding
- Execution engine

### 9.2 Golden Tests (Model-aware)

For each fixture:

- Store OCRBlockSpec input
- Store validated ScreenFlowSpec output (golden)
- Assert canonical JSON equality

Golden tests do not call live model endpoints.

### 9.3 Recorded Model Mode

Optional:
- Record model responses once
- Replay locally in tests
- Compare normalized outputs

### 9.4 Integration Tests
- OCR pipeline correctness
- End-to-end import -> pack execution

### 9.5 Performance Tests
- OCR latency
- Model latency (median + P95)
- Memory usage

---

## 10. Privacy Model

Default:
- On-device OCR
- Model calls require explicit toggle
- No automatic upload of screenshots without consent

Options:
- Run fully on-device model inference
- Use user-configured self-hosted open model endpoint
- Send only OCR text to model (not raw image), or image + text if required

No data sharing for third-party training.

---

## 11. Performance Targets

- OCR + normalization: under 1.5s median
- Local model roundtrip: under 2s median (on-device or local network)
- Full pipeline: under 3s typical

Must degrade gracefully offline:
- Basic OCR + heuristic extraction still functional

---

## 12. Monetization Strategy

Free:
- Local extraction pipeline
- Basic packs

Pro:
- Advanced packs
- Drafting features
- Cloud sync

Enterprise (future):
- Recruiters
- Engineering teams
- Traders

---

## 13. Roadmap

Phase 1:
- Core local/open model extraction + 3 scenarios
- Deterministic validation
- Pack engine
- Share extension

Phase 2:
- Additional scenarios
- Embedding-based similarity search across screens
- Smart history insights

Phase 3:
- Pack marketplace
- SDK for third-party pack creation
- Multi-model routing (latency/quality-aware selection)

---

## 14. Acceptance Criteria (MVP)

- User shares screenshot
- App generates:
  - scenario
  - structured entities
  - at least 2 suggested packs
- User executes at least 1 pack per scenario
- All validated outputs are schema-compliant
- Golden tests pass with canonical JSON
- Model failures handled gracefully
- Execution traces stored and viewable

---

## 15. Open Questions

- Minimum iOS target
- Which local/open model runtime(s) at launch
- Image-to-model vs text-only strategy
- Offline small model fallback
- Resource controls (latency, memory, battery)
