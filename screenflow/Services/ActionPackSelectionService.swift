import Foundation

struct ActionPackSelectionService {
    private let registryService: ActionPackRegistryService

    init(registryService: ActionPackRegistryService? = nil) {
        self.registryService = registryService ?? ActionPackRegistryService()
    }

    func selectPacks(from spec: ScreenFlowSpecV1) -> [ActionPackSelection] {
        let availablePacks = registryService
            .allPacks()
            .filter { $0.scenario == spec.scenario }
        let packsByID = Dictionary(uniqueKeysWithValues: availablePacks.map { ($0.id, $0) })

        let sortedSuggestions = spec.packSuggestions.sorted(by: compareSuggestions)
        var selected: [ActionPackSelection] = []
        var seenPackIDs = Set<String>()

        for suggestion in sortedSuggestions {
            guard let pack = packsByID[suggestion.packId], !seenPackIDs.contains(pack.id) else {
                continue
            }
            seenPackIDs.insert(pack.id)
            selected.append(
                ActionPackSelection(
                    pack: pack,
                    suggestedBindings: suggestion.bindings
                )
            )
        }

        for pack in availablePacks where !seenPackIDs.contains(pack.id) {
            selected.append(
                ActionPackSelection(
                    pack: pack,
                    suggestedBindings: [:]
                )
            )
        }

        return selected
    }

    private func compareSuggestions(lhs: ActionPackSuggestion, rhs: ActionPackSuggestion) -> Bool {
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        return lhs.packId < rhs.packId
    }
}
