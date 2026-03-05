import SwiftUI

private enum DataRetentionPolicy: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90
    case oneEightyDays = 180
    case forever = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sevenDays:
            return "7 days"
        case .thirtyDays:
            return "30 days"
        case .ninetyDays:
            return "90 days"
        case .oneEightyDays:
            return "180 days"
        case .forever:
            return "Keep forever"
        }
    }

    var subtitle: String {
        switch self {
        case .sevenDays:
            return "Fast cleanup for minimal storage footprint."
        case .thirtyDays:
            return "Balanced retention for recent history."
        case .ninetyDays:
            return "Default retention for ongoing tracking."
        case .oneEightyDays:
            return "Longer retention for historical analysis."
        case .forever:
            return "No automatic cleanup."
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("screenflow.settings.cloudDraftingEnabled")
    private var cloudDraftingEnabled = false

    @AppStorage("screenflow.settings.dataRetentionDays")
    private var dataRetentionDays = DataRetentionPolicy.ninetyDays.rawValue

    @AppStorage("screenflow.settings.privacyModeEnabled")
    private var privacyModeEnabled = false

    private var selectedRetention: DataRetentionPolicy {
        DataRetentionPolicy(rawValue: dataRetentionDays) ?? .ninetyDays
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cloud Drafting") {
                    Toggle("Enable Cloud Drafting", isOn: $cloudDraftingEnabled)
                    Text(cloudDraftingEnabled
                         ? "Cloud drafting is enabled for optional generated drafts."
                         : "Cloud drafting is disabled. Only local deterministic outputs are used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data Retention") {
                    Picker("Retention", selection: $dataRetentionDays) {
                        ForEach(DataRetentionPolicy.allCases) { policy in
                            Text(policy.title)
                                .tag(policy.rawValue)
                        }
                    }

                    Text(selectedRetention.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Toggle("Privacy Mode", isOn: $privacyModeEnabled)
                    Text(privacyModeEnabled
                         ? "Library and detail thumbnails are obscured."
                         : "Thumbnails are shown normally in the library and detail views.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
