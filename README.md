# ScreenFlow

ScreenFlow is an iOS app that turns screenshots into structured, validated outputs and one-tap action packs.

## What It Does

- Imports screenshots from in-app photo picker and iOS Share Sheet extension
- Normalizes imported images deterministically for hashing and OCR
- Runs on-device Vision OCR with configurable language hints
- Sends normalized OCR to an on-device-preferred runtime with self-hosted open-model fallback (Ollama-compatible)
- Validates and canonicalizes structured output deterministically
- Performs one deterministic model-repair pass for invalid model JSON
- Falls back to deterministic OCR-based heuristic extraction when repair fails
- Suggests and executes action packs
- Executes integration steps for EventKit calendar creation, optional URL opening, clipboard copy, and file exports (`Exports/`)
- Persists artifacts and execution traces for replay
- Replays interpretation deterministically from stored OCR artifacts
- Supports recorded-model replay mode for deterministic local re-runs without live model calls
- Persists canonical extraction artifacts under `Extracted/` and links them in `ExtractionResult`
- Stores original image, normalized image, and metadata sidecar per screen ID
- Uses a centralized version catalog for OCR schema, extraction schema, prompt version, model defaults, and pack versions
- Provides a Home Library list with per-screen thumbnail, scenario, source, confidence, and import timestamp
- Provides a Screen Detail view with extraction metadata, entities, and pack suggestions
- Supports editing extracted entities with deterministic persisted overrides before pack execution
- Does not require paid LLM providers

## Architecture Summary

1. Input ingestion
2. OCR extraction + normalization (`OCRBlockSpec.v1`)
3. Local/open model interpretation (`ScreenFlowSpec.v1`)
4. Validation and canonicalization
5. Action planning and execution
6. Reporting and trace persistence

Model output is never accepted directly without deterministic validation.

## Project Structure

- `screenflow/` app target
- `screenflow/Models/` SwiftData models
- `screenflowTests/` unit tests

## Development

Open in Xcode:

```bash
open screenflow.xcodeproj
```

Build:

```bash
xcodebuild -scheme screenflow -destination 'generic/platform=iOS Simulator' build
```

Test:

```bash
xcodebuild -scheme screenflow -destination 'platform=iOS Simulator,name=iPhone 17' test
```
