import SwiftUI

struct ScreenEntityEditorView: View {
    let extractionResult: ExtractionResult
    let baseSpec: ScreenFlowSpecV1
    let onSaved: (ScreenFlowSpecV1, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var includeJob: Bool
    @State private var includeEvent: Bool
    @State private var includeError: Bool

    @State private var jobCompany: String
    @State private var jobRole: String
    @State private var jobLocation: String
    @State private var jobSkills: String
    @State private var jobSalaryMin: String
    @State private var jobSalaryMax: String
    @State private var jobSalaryCurrency: String
    @State private var jobLink: String

    @State private var eventTitle: String
    @State private var eventDateTime: String
    @State private var eventVenue: String
    @State private var eventAddress: String
    @State private var eventLink: String

    @State private var errorType: String
    @State private var errorMessage: String
    @State private var errorToolName: String
    @State private var errorFilePaths: String
    @State private var errorStackTrace: String

    @State private var saveErrorMessage: String?

    init(
        extractionResult: ExtractionResult,
        baseSpec: ScreenFlowSpecV1,
        onSaved: @escaping (ScreenFlowSpecV1, String) -> Void
    ) {
        self.extractionResult = extractionResult
        self.baseSpec = baseSpec
        self.onSaved = onSaved

        let job = baseSpec.entities.job
        let event = baseSpec.entities.event
        let error = baseSpec.entities.error

        _includeJob = State(initialValue: job != nil)
        _includeEvent = State(initialValue: event != nil)
        _includeError = State(initialValue: error != nil)

        _jobCompany = State(initialValue: job?.company ?? "")
        _jobRole = State(initialValue: job?.role ?? "")
        _jobLocation = State(initialValue: job?.location ?? "")
        _jobSkills = State(initialValue: job?.skills?.joined(separator: ", ") ?? "")
        _jobSalaryMin = State(initialValue: job?.salaryRange?.min.map { String($0) } ?? "")
        _jobSalaryMax = State(initialValue: job?.salaryRange?.max.map { String($0) } ?? "")
        _jobSalaryCurrency = State(initialValue: job?.salaryRange?.currency ?? "")
        _jobLink = State(initialValue: job?.link ?? "")

        _eventTitle = State(initialValue: event?.title ?? "")
        _eventDateTime = State(initialValue: event?.dateTime ?? "")
        _eventVenue = State(initialValue: event?.venue ?? "")
        _eventAddress = State(initialValue: event?.address ?? "")
        _eventLink = State(initialValue: event?.link ?? "")

        _errorType = State(initialValue: error?.errorType ?? "")
        _errorMessage = State(initialValue: error?.message ?? "")
        _errorToolName = State(initialValue: error?.toolName ?? "")
        _errorFilePaths = State(initialValue: error?.filePaths?.joined(separator: ", ") ?? "")
        _errorStackTrace = State(initialValue: error?.stackTrace ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                sectionHeader("Choose Entity Groups")

                Toggle("Include Job", isOn: $includeJob)
                Toggle("Include Event", isOn: $includeEvent)
                Toggle("Include Error", isOn: $includeError)

                if includeJob {
                    Section("Job") {
                        TextField("Company", text: $jobCompany)
                        TextField("Role", text: $jobRole)
                        TextField("Location", text: $jobLocation)
                        TextField("Skills (comma separated)", text: $jobSkills)
                        TextField("Salary Min", text: $jobSalaryMin)
                            .keyboardType(.decimalPad)
                        TextField("Salary Max", text: $jobSalaryMax)
                            .keyboardType(.decimalPad)
                        TextField("Salary Currency", text: $jobSalaryCurrency)
                        TextField("Link", text: $jobLink)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                if includeEvent {
                    Section("Event") {
                        TextField("Title", text: $eventTitle)
                        TextField("Date Time (ISO8601)", text: $eventDateTime)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Venue", text: $eventVenue)
                        TextField("Address", text: $eventAddress)
                        TextField("Link", text: $eventLink)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                if includeError {
                    Section("Error") {
                        TextField("Error Type", text: $errorType)
                        TextField("Message", text: $errorMessage)
                        TextField("Tool Name", text: $errorToolName)
                        TextField("File Paths (comma separated)", text: $errorFilePaths)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stack Trace")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $errorStackTrace)
                                .frame(minHeight: 120)
                        }
                    }
                }
            }
            .navigationTitle("Edit Entities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveOverrides()
                    }
                }
            }
            .alert("Save Error", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        saveErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? "Unknown error")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Section {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func saveOverrides() {
        do {
            let editedSpec = ScreenFlowSpecV1(
                schemaVersion: baseSpec.schemaVersion,
                scenario: baseSpec.scenario,
                scenarioConfidence: baseSpec.scenarioConfidence,
                entities: ScreenFlowEntities(
                    job: buildJobEntities(),
                    event: buildEventEntities(),
                    error: buildErrorEntities()
                ),
                packSuggestions: baseSpec.packSuggestions,
                modelMeta: baseSpec.modelMeta
            )

            let validation = ScreenFlowSpecValidationService()
            let canonicalSpec = try validation.validateAndCanonicalize(editedSpec)

            let storagePathService = StoragePathService()
            let extractedDirectory = try storagePathService.applicationSupportPath(for: .extracted)
            try storagePathService.fileManager.createDirectory(at: extractedDirectory, withIntermediateDirectories: true)

            let overrideURL = extractedDirectory.appendingPathComponent("\(extractionResult.id).overrides.json", isDirectory: false)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let payload = try encoder.encode(canonicalSpec)
            try payload.write(to: overrideURL, options: .atomic)

            let repository = ScreenFlowRepository(modelContext: modelContext)
            _ = try repository.upsertExtractionResult(
                ExtractionResultInput(
                    id: extractionResult.id,
                    screenId: extractionResult.screenId,
                    schemaVersion: extractionResult.schemaVersion,
                    entitiesJSONPath: extractionResult.entitiesJSONPath,
                    intentGraphJSONPath: extractionResult.intentGraphJSONPath,
                    createdAt: extractionResult.createdAt,
                    userOverridesJSONPath: overrideURL.path
                )
            )

            onSaved(canonicalSpec, overrideURL.path)
            dismiss()
        } catch {
            saveErrorMessage = "Could not save overrides: \(error.localizedDescription)"
        }
    }

    private func buildJobEntities() -> JobEntities? {
        guard includeJob else { return nil }

        let minimum = normalizedOptional(jobSalaryMin).flatMap(Double.init)
        let maximum = normalizedOptional(jobSalaryMax).flatMap(Double.init)
        let currency = normalizedOptional(jobSalaryCurrency)

        let salaryRange: SalaryRange?
        if minimum != nil || maximum != nil || currency != nil {
            salaryRange = SalaryRange(min: minimum, max: maximum, currency: currency)
        } else {
            salaryRange = nil
        }

        return JobEntities(
            company: normalizedOptional(jobCompany),
            role: normalizedOptional(jobRole),
            location: normalizedOptional(jobLocation),
            skills: normalizedList(jobSkills),
            salaryRange: salaryRange,
            link: normalizedOptional(jobLink)
        )
    }

    private func buildEventEntities() -> EventEntities? {
        guard includeEvent else { return nil }

        return EventEntities(
            title: normalizedOptional(eventTitle),
            dateTime: normalizedOptional(eventDateTime),
            venue: normalizedOptional(eventVenue),
            address: normalizedOptional(eventAddress),
            link: normalizedOptional(eventLink)
        )
    }

    private func buildErrorEntities() -> ErrorEntities? {
        guard includeError else { return nil }

        return ErrorEntities(
            errorType: normalizedOptional(errorType),
            message: normalizedOptional(errorMessage),
            stackTrace: normalizedOptional(errorStackTrace),
            toolName: normalizedOptional(errorToolName),
            filePaths: normalizedList(errorFilePaths)
        )
    }

    private func normalizedOptional(_ value: String) -> String? {
        let cleaned = value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func normalizedList(_ value: String) -> [String]? {
        let items = value
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return items.isEmpty ? nil : items
    }
}
