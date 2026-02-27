//
//  ContentView.swift
//  screenflow
//
//  Created by Ibrahim Arshad on 2/25/26.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ScreenRecord.createdAt, order: .reverse) private var screenRecords: [ScreenRecord]
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(screenRecords) { record in
                    NavigationLink {
                        Text(record.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.scenario.rawValue)
                            Text(record.createdAt, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
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

#Preview {
    ContentView()
        .modelContainer(for: ScreenRecord.self, inMemory: true)
}
