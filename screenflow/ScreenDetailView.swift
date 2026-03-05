import SwiftData
import SwiftUI

struct ScreenDetailView: View {
    let record: ScreenRecord

    @Environment(\.modelContext) private var modelContext
    @State private var latestSpec: ScreenFlowSpecV1?
    @State private var latestExtraction: ExtractionResult?
    @State private var loadErrorMessage: String?
    @State private var isPresentingEntityEditor = false

    var body: some View {
        List {
            screenshotSection
            metadataSection
            entitiesSection
            packSuggestionsSection
        }
        .navigationTitle("Screen Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: record.id) {
            await loadLatestExtractionSpec()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit Entities") {
                    isPresentingEntityEditor = true
                }
                .disabled(latestSpec == nil || latestExtraction == nil)
            }
        }
        .sheet(isPresented: $isPresentingEntityEditor) {
            if let latestSpec, let latestExtraction {
                ScreenEntityEditorView(
                    extractionResult: latestExtraction,
                    baseSpec: latestSpec
                ) { savedSpec, overridePath in
                    self.latestSpec = savedSpec
                    self.latestExtraction?.userOverridesJSONPath = overridePath
                }
            } else {
                Text("No extraction available to edit.")
            }
        }
        .alert("Load Error", isPresented: Binding(
            get: { loadErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    loadErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                loadErrorMessage = nil
            }
        } message: {
            Text(loadErrorMessage ?? "Unknown error")
        }
    }

    private var screenshotSection: some View {
        Section("Screenshot") {
            HStack(spacing: 12) {
                ScreenshotThumbnailView(imagePath: record.imagePath)
                    .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.scenario.displayName)
                        .font(.headline)
                    Text("Confidence \(record.scenarioConfidence.formatted(.percent.precision(.fractionLength(0))))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(record.source.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var metadataSection: some View {
        Section("Metadata") {
            metadataRow(label: "Screen ID", value: record.id)
            metadataRow(label: "Source", value: record.source.displayName)
            metadataRow(label: "Imported", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
            metadataRow(label: "Image Size", value: "\(record.imageWidth)x\(record.imageHeight)")
            metadataRow(label: "Processing", value: record.processingVersion)

            if let extraction = latestExtraction {
                metadataRow(label: "Extraction ID", value: extraction.id)
                metadataRow(label: "Schema", value: extraction.schemaVersion)
                metadataRow(label: "Extracted", value: extraction.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let overridePath = extraction.userOverridesJSONPath {
                    metadataRow(label: "Overrides", value: overridePath)
                }
            } else {
                metadataRow(label: "Extraction", value: "No extraction artifact found")
            }
        }
    }

    private var entitiesSection: some View {
        Section("Entities") {
            if let spec = latestSpec {
                let entityRows = makeEntityRows(from: spec.entities)
                if entityRows.isEmpty {
                    Text("No entities available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entityRows, id: \.key) { row in
                        metadataRow(label: row.key, value: row.value)
                    }
                }
            } else {
                Text("No extracted entities available")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var packSuggestionsSection: some View {
        Section("Pack Suggestions") {
            if let spec = latestSpec {
                if spec.packSuggestions.isEmpty {
                    Text("No pack suggestions")
                        .foregroundStyle(.secondary)
                } else {
                    let suggestions = sortedPackSuggestions(spec.packSuggestions)
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.packId)
                                .font(.headline)
                            Text("Confidence \(suggestion.confidence.formatted(.percent.precision(.fractionLength(0))))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                NavigationLink("Open Pack Execution") {
                    PackExecutionView(record: record, spec: spec)
                }
            } else {
                Text("No pack suggestions available")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    @MainActor
    private func loadLatestExtractionSpec() async {
        do {
            let repository = ScreenFlowRepository(modelContext: modelContext)
            let extractionResults = try repository.listExtractionResults(screenID: record.id)
            let latest = extractionResults.first
            latestExtraction = latest

            guard let latest else {
                latestSpec = nil
                return
            }

            let specPath = latest.userOverridesJSONPath ?? latest.entitiesJSONPath
            let data = try Data(contentsOf: URL(fileURLWithPath: specPath))
            let spec = try JSONDecoder().decode(ScreenFlowSpecV1.self, from: data)
            latestSpec = spec
        } catch {
            latestSpec = nil
            loadErrorMessage = "Failed to load extraction details: \(error.localizedDescription)"
        }
    }

    private func sortedPackSuggestions(_ suggestions: [ActionPackSuggestion]) -> [ActionPackSuggestion] {
        suggestions.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.packId < rhs.packId
        }
    }

    private func makeEntityRows(from entities: ScreenFlowEntities) -> [(key: String, value: String)] {
        var rows: [(key: String, value: String)] = []

        if let job = entities.job {
            appendRow(&rows, key: "job.company", value: job.company)
            appendRow(&rows, key: "job.role", value: job.role)
            appendRow(&rows, key: "job.location", value: job.location)
            appendRow(&rows, key: "job.skills", value: job.skills?.joined(separator: ", "))
            appendRow(&rows, key: "job.link", value: job.link)

            if let salaryRange = job.salaryRange {
                let minimum = salaryRange.min.map { String($0) }
                let maximum = salaryRange.max.map { String($0) }
                let currency = salaryRange.currency
                let salaryValue = [minimum, maximum, currency]
                    .compactMap { $0 }
                    .joined(separator: " / ")
                appendRow(&rows, key: "job.salaryRange", value: salaryValue)
            }
        }

        if let event = entities.event {
            appendRow(&rows, key: "event.title", value: event.title)
            appendRow(&rows, key: "event.dateTime", value: event.dateTime)
            appendRow(&rows, key: "event.venue", value: event.venue)
            appendRow(&rows, key: "event.address", value: event.address)
            appendRow(&rows, key: "event.link", value: event.link)
        }

        if let error = entities.error {
            appendRow(&rows, key: "error.errorType", value: error.errorType)
            appendRow(&rows, key: "error.message", value: error.message)
            appendRow(&rows, key: "error.toolName", value: error.toolName)
            appendRow(&rows, key: "error.filePaths", value: error.filePaths?.joined(separator: ", "))
            appendRow(&rows, key: "error.stackTrace", value: error.stackTrace)
        }

        return rows.sorted { $0.key < $1.key }
    }

    private func appendRow(_ rows: inout [(key: String, value: String)], key: String, value: String?) {
        guard let value, !value.isEmpty else { return }
        rows.append((key: key, value: value))
    }
}
