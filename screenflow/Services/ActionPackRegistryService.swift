import Foundation

struct ActionPackRegistryService {
    func allPacks() -> [ActionPackDefinition] {
        let jobSave = ActionPackDefinition(
            id: "job_listing.save_tracker",
            version: "1.0.0",
            scenario: .jobListing,
            requiredBindings: [
                ActionPackBindingRequirement(key: "job.company", valueType: .string),
                ActionPackBindingRequirement(key: "job.role", valueType: .string),
            ],
            optionalBindingKeys: ["job.location", "job.link", "job.salaryRange.min", "job.salaryRange.max", "job.salaryRange.currency"],
            preconditions: [],
            steps: [
                ActionPackStepDefinition(
                    id: "save-job-json",
                    type: .exportBindingsJSON,
                    outputFileName: "job-tracker.json",
                    template: nil
                )
            ]
        )

        let jobDraft = ActionPackDefinition(
            id: "job_listing.draft_application_email",
            version: "1.0.0",
            scenario: .jobListing,
            requiredBindings: [
                ActionPackBindingRequirement(key: "job.company", valueType: .string),
                ActionPackBindingRequirement(key: "job.role", valueType: .string),
            ],
            optionalBindingKeys: ["job.skills", "job.location", "job.link"],
            preconditions: [],
            steps: [
                ActionPackStepDefinition(
                    id: "render-email-outline",
                    type: .renderTextTemplate,
                    outputFileName: "application-email-outline.txt",
                    template: """
                    Application Draft
                    Company: {{job.company}}
                    Role: {{job.role}}
                    Location: {{job.location}}
                    Skills: {{job.skills}}
                    Link: {{job.link}}
                    """
                )
            ]
        )

        let eventCalendar = ActionPackDefinition(
            id: "event_flyer.add_to_calendar",
            version: "1.0.0",
            scenario: .eventFlyer,
            requiredBindings: [
                ActionPackBindingRequirement(key: "event.title", valueType: .string),
                ActionPackBindingRequirement(key: "event.dateTime", valueType: .string),
            ],
            optionalBindingKeys: ["event.venue", "event.address", "event.link"],
            preconditions: [],
            steps: [
                ActionPackStepDefinition(
                    id: "render-calendar-request",
                    type: .renderTextTemplate,
                    outputFileName: "calendar-request.txt",
                    template: """
                    Calendar Request
                    Title: {{event.title}}
                    DateTime: {{event.dateTime}}
                    Venue: {{event.venue}}
                    Address: {{event.address}}
                    Link: {{event.link}}
                    """
                )
            ]
        )

        let eventShare = ActionPackDefinition(
            id: "event_flyer.create_share_card",
            version: "1.0.0",
            scenario: .eventFlyer,
            requiredBindings: [ActionPackBindingRequirement(key: "event.title", valueType: .string)],
            optionalBindingKeys: ["event.dateTime", "event.venue", "event.address"],
            preconditions: [],
            steps: [
                ActionPackStepDefinition(
                    id: "render-share-card",
                    type: .renderTextTemplate,
                    outputFileName: "share-card.txt",
                    template: """
                    {{event.title}}
                    {{event.dateTime}}
                    {{event.venue}}
                    {{event.address}}
                    """
                )
            ]
        )

        let errorIssue = ActionPackDefinition(
            id: "error_log.generate_issue_template",
            version: "1.0.0",
            scenario: .errorLog,
            requiredBindings: [ActionPackBindingRequirement(key: "error.message", valueType: .string)],
            optionalBindingKeys: ["error.errorType", "error.toolName", "error.filePaths", "error.stackTrace"],
            preconditions: [],
            steps: [
                ActionPackStepDefinition(
                    id: "render-issue-template",
                    type: .renderTextTemplate,
                    outputFileName: "issue-template.md",
                    template: """
                    # Error Report
                    Type: {{error.errorType}}
                    Tool: {{error.toolName}}
                    Message: {{error.message}}
                    Files: {{error.filePaths}}

                    ## Stack Trace
                    {{error.stackTrace}}
                    """
                )
            ]
        )

        let errorChecklist = ActionPackDefinition(
            id: "error_log.create_debug_checklist",
            version: "1.0.0",
            scenario: .errorLog,
            requiredBindings: [ActionPackBindingRequirement(key: "error.message", valueType: .string)],
            optionalBindingKeys: ["error.filePaths"],
            preconditions: [],
            steps: [
                ActionPackStepDefinition(
                    id: "render-debug-checklist",
                    type: .renderTextTemplate,
                    outputFileName: "debug-checklist.txt",
                    template: """
                    Debug Checklist
                    [ ] Reproduce error: {{error.message}}
                    [ ] Inspect files: {{error.filePaths}}
                    [ ] Add test case
                    [ ] Verify fix
                    """
                )
            ]
        )

        return [jobSave, jobDraft, eventCalendar, eventShare, errorIssue, errorChecklist]
            .sorted { $0.id < $1.id }
    }
}
