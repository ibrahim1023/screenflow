//
//  ContentView.swift
//  screenflow
//
//  Created by Ibrahim Arshad on 2/25/26.
//

import SwiftUI
import PhotosUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ScreenRecord.createdAt, order: .reverse) private var screenRecords: [ScreenRecord]
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationSplitView {
            List {
                if screenRecords.isEmpty {
                    ContentUnavailableView(
                        "No Screens Yet",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Import a screenshot to start generating deterministic action packs.")
                    )
                } else {
                    Section("Screens (\(screenRecords.count))") {
                        ForEach(screenRecords) { record in
                            NavigationLink {
                                Text(record.id)
                            } label: {
                                ScreenLibraryRow(record: record)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .navigationTitle("ScreenFlow")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Import Photo", systemImage: "photo.on.rectangle")
                    }
                }
            }
        } detail: {
            Text("Select a screen")
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }

            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        importErrorMessage = "Could not load selected photo data."
                        return
                    }

                    let repository = ScreenFlowRepository(modelContext: modelContext)
                    let importer = InAppPhotoImportService()
                    let screenRecord = try importer.importPhotoData(
                        data,
                        source: .photoPicker,
                        repository: repository
                    )
                    let ocrPipeline = OCRArtifactPipelineService()
                    _ = try ocrPipeline.runOCRAndPersist(
                        for: screenRecord,
                        repository: repository
                    )
                } catch {
                    importErrorMessage = "Photo import failed: \(error.localizedDescription)"
                }

                selectedPhotoItem = nil
            }
        }
        .task {
            await syncPendingShareImports()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await syncPendingShareImports()
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "Unknown error")
        }
    }

    @MainActor
    private func syncPendingShareImports() async {
        do {
            let repository = ScreenFlowRepository(modelContext: modelContext)
            try StorageBootstrapService().prepareRequiredDirectories()
            _ = try ShareSheetImportIngestionService().ingestPendingSharedScreens(repository: repository)
        } catch {
            importErrorMessage = "Share import sync failed: \(error.localizedDescription)"
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(screenRecords[index])
            }
        }
    }
}

private struct ScreenLibraryRow: View {
    let record: ScreenRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ScreenshotThumbnailView(imagePath: record.imagePath)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.scenario.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Label(record.source.displayName, systemImage: "square.and.arrow.down")
                    Text("Confidence \(record.scenarioConfidence.formatted(.percent.precision(.fractionLength(0))))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(record.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ScreenshotThumbnailView: View {
    let imagePath: String

    var body: some View {
        Group {
#if canImport(UIKit)
            if let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
#else
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
#endif
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

private extension ScenarioType {
    var displayName: String {
        switch self {
        case .unknown:
            return "Unknown Screen"
        case .jobListing:
            return "Job Listing"
        case .eventFlyer:
            return "Event Flyer"
        case .errorLog:
            return "Error Log"
        }
    }
}

private extension ScreenSource {
    var displayName: String {
        switch self {
        case .shareSheet:
            return "Share Sheet"
        case .photoPicker:
            return "Photo Picker"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ScreenRecord.self, inMemory: true)
}
