import EventKit
import Foundation

enum CalendarEventCreationError: Error, Equatable {
    case accessNotAuthorized
    case calendarUnavailable
}

struct CalendarEventRequest: Equatable, Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let url: URL?
}

protocol CalendarEventCreating: Sendable {
    func createEvent(_ request: CalendarEventRequest) throws -> String?
}

struct EventKitCalendarEventService: CalendarEventCreating {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func createEvent(_ request: CalendarEventRequest) throws -> String? {
        guard hasWriteAccess else {
            throw CalendarEventCreationError.accessNotAuthorized
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw CalendarEventCreationError.calendarUnavailable
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = request.title
        event.startDate = request.startDate
        event.endDate = request.endDate
        event.location = request.location
        event.notes = request.notes
        event.url = request.url

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    private var hasWriteAccess: Bool {
        if #available(iOS 17.0, *) {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess, .writeOnly:
                return true
            default:
                return false
            }
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }
}
