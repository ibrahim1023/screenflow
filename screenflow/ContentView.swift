//
//  ContentView.swift
//  screenflow
//
//  Created by Ibrahim Arshad on 2/25/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenRecord.createdAt, order: .reverse) private var screenRecords: [ScreenRecord]

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
                    Button(action: addItem) {
                        Label("Add Sample Screen", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select a screen")
        }
    }

    private func addItem() {
        withAnimation {
            let sampleRecord = ScreenRecord(
                id: UUID().uuidString.lowercased(),
                source: .photoPicker,
                imagePath: "Screens/sample.jpg",
                imageWidth: 1179,
                imageHeight: 2556,
                processingVersion: "1.0.0"
            )
            modelContext.insert(sampleRecord)
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
