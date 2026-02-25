//
//  screenflowTests.swift
//  screenflowTests
//
//  Created by Ibrahim Arshad on 2/25/26.
//

import Foundation
import Testing
@testable import screenflow

struct screenflowTests {
    @Test func screenRecordStoresDeterministicFields() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let record = ScreenRecord(
            id: "abc123",
            createdAt: fixedDate,
            source: .shareSheet,
            imagePath: "Screens/abc123.jpg",
            imageWidth: 1284,
            imageHeight: 2778,
            scenario: .jobListing,
            scenarioConfidence: 0.96,
            processingVersion: "1.0.0",
            lastOpenedAt: nil
        )

        #expect(record.id == "abc123")
        #expect(record.createdAt == fixedDate)
        #expect(record.source == ScreenSource.shareSheet)
        #expect(record.scenario == ScenarioType.jobListing)
        #expect(record.processingVersion == "1.0.0")
    }

    @Test func actionPackRunInitializesWithTypedStatus() async throws {
        let run = ActionPackRun(
            id: "run-1",
            screenId: "abc123",
            packId: "event_flyer.add_to_calendar",
            packVersion: "1.0.0",
            inputParamsJSONPath: "Runs/run-1.input.json",
            traceJSONPath: "Runs/run-1.trace.json",
            status: .success
        )

        #expect(run.status == .success)
        #expect(run.packId == "event_flyer.add_to_calendar")
        #expect(run.traceJSONPath == "Runs/run-1.trace.json")
    }

}
