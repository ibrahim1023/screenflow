# ScreenFlow

ScreenFlow is an iOS app that turns screenshots into structured, validated outputs and one-tap action packs.

## What It Does

- Imports screenshots from share sheet or photo picker
- Runs on-device OCR
- Sends normalized OCR to a local/open model runtime for semantic interpretation
- Validates and canonicalizes structured output deterministically
- Suggests and executes action packs
- Persists artifacts and execution traces for replay
- Does not require paid LLM providers

## Architecture Summary

1. Input ingestion
2. OCR normalization (`OCRBlockSpec.v1`)
3. LLM interpretation (`ScreenFlowSpec.v1`)
4. Validation and canonicalization
5. Action planning and execution
6. Reporting and trace persistence

LLM output is never accepted directly without deterministic validation.

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
