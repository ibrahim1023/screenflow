import SwiftUI

private enum PackStepProgressStatus {
    case pending
    case running
    case success
    case failed
}

private struct PackStepProgress: Identifiable {
    let id: String
    let stepID: String
    let stepType: ActionPackStepType
    var status: PackStepProgressStatus
    var outputPath: String?
    var message: String?

    init(step: ActionPackStepDefinition, status: PackStepProgressStatus = .pending, outputPath: String? = nil, message: String? = nil) {
        self.id = step.id
        self.stepID = step.id
        self.stepType = step.type
        self.status = status
        self.outputPath = outputPath
        self.message = message
    }
}

struct PackExecutionView: View {
    let record: ScreenRecord
    let spec: ScreenFlowSpecV1

    @Environment(\.modelContext) private var modelContext

    @State private var selectedPackID: String?
    @State private var isExecuting = false
    @State private var executionErrorMessage: String?
    @State private var executedRunID: String?
    @State private var executionSteps: [PackStepProgress] = []

    private let selectionService = ActionPackSelectionService()

    private var packSelections: [ActionPackSelection] {
        selectionService.selectPacks(from: spec)
    }

    private var selectedSelection: ActionPackSelection? {
        guard let selectedPackID else { return packSelections.first }
        return packSelections.first(where: { $0.pack.id == selectedPackID }) ?? packSelections.first
    }

    var body: some View {
        List {
            availablePacksSection
            executionPlanSection
            executionOutputSection
        }
        .navigationTitle("Pack Execution")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isExecuting ? "Running..." : "Run") {
                    runSelectedPack()
                }
                .disabled(isExecuting || selectedSelection == nil)
            }
        }
        .onAppear {
            if selectedPackID == nil {
                selectedPackID = packSelections.first?.pack.id
            }
        }
        .alert("Execution Error", isPresented: Binding(
            get: { executionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    executionErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                executionErrorMessage = nil
            }
        } message: {
            Text(executionErrorMessage ?? "Unknown error")
        }
    }

    private var availablePacksSection: some View {
        Section("Available Packs") {
            if packSelections.isEmpty {
                Text("No packs available for this scenario.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(packSelections, id: \.pack.id) { selection in
                    Button {
                        selectedPackID = selection.pack.id
                        resetExecutionPlan(for: selection)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selection.pack.id)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("v\(selection.pack.version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedSelection?.pack.id == selection.pack.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var executionPlanSection: some View {
        Section("Step-by-Step Progress") {
            if executionSteps.isEmpty, let selectedSelection {
                ForEach(selectedSelection.pack.steps, id: \.id) { step in
                    stepRow(stepID: step.id, stepType: step.type, status: .pending, outputPath: nil, message: nil)
                }
            } else if executionSteps.isEmpty {
                Text("Select a pack to view execution plan.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(executionSteps) { step in
                    stepRow(stepID: step.stepID, stepType: step.stepType, status: step.status, outputPath: step.outputPath, message: step.message)
                }
            }
        }
    }

    private var executionOutputSection: some View {
        Section("Execution Outputs") {
            if let executedRunID {
                Text("Run ID")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(executedRunID)
                    .textSelection(.enabled)

                let outputPaths = executionSteps.compactMap(\.outputPath)
                if outputPaths.isEmpty {
                    Text("No output artifacts yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(outputPaths, id: \.self) { path in
                        Text(path)
                            .font(.footnote)
                            .textSelection(.enabled)
                    }
                }
            } else {
                Text("No pack run yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepRow(
        stepID: String,
        stepType: ActionPackStepType,
        status: PackStepProgressStatus,
        outputPath: String?,
        message: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconName(for: status))
                    .foregroundStyle(color(for: status))
                Text(stepID)
                    .font(.subheadline)
                Spacer()
                Text(stepType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let outputPath {
                Text(outputPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    private func iconName(for status: PackStepProgressStatus) -> String {
        switch status {
        case .pending:
            return "circle"
        case .running:
            return "hourglass"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    private func color(for status: PackStepProgressStatus) -> Color {
        switch status {
        case .pending:
            return .secondary
        case .running:
            return .orange
        case .success:
            return .green
        case .failed:
            return .red
        }
    }

    private func resetExecutionPlan(for selection: ActionPackSelection) {
        executionSteps = selection.pack.steps.map { PackStepProgress(step: $0) }
    }

    @MainActor
    private func runSelectedPack() {
        guard let selectedSelection else { return }

        isExecuting = true
        executionErrorMessage = nil
        executedRunID = nil
        resetExecutionPlan(for: selectedSelection)

        Task {
            do {
                let repository = ScreenFlowRepository(modelContext: modelContext)
                let executionService = ActionPackExecutionService()

                markInitialRunningStep()

                let run = try executionService.execute(
                    selection: selectedSelection,
                    spec: spec,
                    screenID: record.id,
                    repository: repository
                ) { stepTrace in
                    applyCompletedStep(stepTrace)
                }

                executedRunID = run.id
            } catch {
                executionErrorMessage = "Pack execution failed: \(error.localizedDescription)"
            }

            isExecuting = false
        }
    }

    @MainActor
    private func markInitialRunningStep() {
        guard !executionSteps.isEmpty else { return }
        executionSteps[0].status = .running
    }

    @MainActor
    private func applyCompletedStep(_ trace: ActionPackStepTrace) {
        guard let index = executionSteps.firstIndex(where: { $0.stepID == trace.stepID }) else {
            return
        }

        executionSteps[index].status = trace.status == .success ? .success : .failed
        executionSteps[index].outputPath = trace.outputPath
        executionSteps[index].message = trace.message

        if trace.status == .success {
            let nextIndex = index + 1
            if nextIndex < executionSteps.count, executionSteps[nextIndex].status == .pending {
                executionSteps[nextIndex].status = .running
            }
        }
    }
}
