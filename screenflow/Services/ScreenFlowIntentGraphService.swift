import Foundation

struct ScreenFlowIntentGraphService {
    func buildGraph(from spec: ScreenFlowSpecV1) -> IntentGraphV1 {
        var nodes: [IntentGraphNode] = []
        var edges: [IntentGraphEdge] = []

        let scenarioNode = IntentGraphNode(
            id: "scenario:\(spec.scenario.rawValue)",
            type: .scenario,
            keyPath: "scenario",
            stringValue: spec.scenario.rawValue,
            numberValue: nil
        )
        nodes.append(scenarioNode)

        let confidenceNode = IntentGraphNode(
            id: "scenario:confidence",
            type: .attribute,
            keyPath: "scenarioConfidence",
            stringValue: nil,
            numberValue: spec.scenarioConfidence
        )
        nodes.append(confidenceNode)
        edges.append(
            IntentGraphEdge(
                id: "edge:\(scenarioNode.id)->\(confidenceNode.id)",
                sourceNodeID: scenarioNode.id,
                targetNodeID: confidenceNode.id,
                type: .hasAttribute
            )
        )

        if let job = spec.entities.job {
            appendJobNodes(job, scenarioNodeID: scenarioNode.id, nodes: &nodes, edges: &edges)
        }
        if let event = spec.entities.event {
            appendEventNodes(event, scenarioNodeID: scenarioNode.id, nodes: &nodes, edges: &edges)
        }
        if let error = spec.entities.error {
            appendErrorNodes(error, scenarioNodeID: scenarioNode.id, nodes: &nodes, edges: &edges)
        }

        return IntentGraphV1(
            schemaVersion: "IntentGraph.v1",
            nodes: nodes.sorted(by: compareNode),
            edges: edges.sorted(by: compareEdge)
        )
    }

    private func appendJobNodes(
        _ job: JobEntities,
        scenarioNodeID: String,
        nodes: inout [IntentGraphNode],
        edges: inout [IntentGraphEdge]
    ) {
        let groupNode = IntentGraphNode(
            id: "entity:job",
            type: .entityGroup,
            keyPath: "entities.job",
            stringValue: nil,
            numberValue: nil
        )
        appendGroupNode(groupNode, scenarioNodeID: scenarioNodeID, nodes: &nodes, edges: &edges)

        appendStringAttribute(value: job.company, keyPath: "entities.job.company", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: job.role, keyPath: "entities.job.role", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: job.location, keyPath: "entities.job.location", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringArrayAttributes(values: job.skills, keyPath: "entities.job.skills", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: job.link, keyPath: "entities.job.link", parentID: groupNode.id, nodes: &nodes, edges: &edges)

        if let salaryRange = job.salaryRange {
            appendNumberAttribute(value: salaryRange.min, keyPath: "entities.job.salaryRange.min", parentID: groupNode.id, nodes: &nodes, edges: &edges)
            appendNumberAttribute(value: salaryRange.max, keyPath: "entities.job.salaryRange.max", parentID: groupNode.id, nodes: &nodes, edges: &edges)
            appendStringAttribute(value: salaryRange.currency, keyPath: "entities.job.salaryRange.currency", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        }
    }

    private func appendEventNodes(
        _ event: EventEntities,
        scenarioNodeID: String,
        nodes: inout [IntentGraphNode],
        edges: inout [IntentGraphEdge]
    ) {
        let groupNode = IntentGraphNode(
            id: "entity:event",
            type: .entityGroup,
            keyPath: "entities.event",
            stringValue: nil,
            numberValue: nil
        )
        appendGroupNode(groupNode, scenarioNodeID: scenarioNodeID, nodes: &nodes, edges: &edges)

        appendStringAttribute(value: event.title, keyPath: "entities.event.title", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: event.dateTime, keyPath: "entities.event.dateTime", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: event.venue, keyPath: "entities.event.venue", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: event.address, keyPath: "entities.event.address", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: event.link, keyPath: "entities.event.link", parentID: groupNode.id, nodes: &nodes, edges: &edges)
    }

    private func appendErrorNodes(
        _ error: ErrorEntities,
        scenarioNodeID: String,
        nodes: inout [IntentGraphNode],
        edges: inout [IntentGraphEdge]
    ) {
        let groupNode = IntentGraphNode(
            id: "entity:error",
            type: .entityGroup,
            keyPath: "entities.error",
            stringValue: nil,
            numberValue: nil
        )
        appendGroupNode(groupNode, scenarioNodeID: scenarioNodeID, nodes: &nodes, edges: &edges)

        appendStringAttribute(value: error.errorType, keyPath: "entities.error.errorType", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: error.message, keyPath: "entities.error.message", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: error.stackTrace, keyPath: "entities.error.stackTrace", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringAttribute(value: error.toolName, keyPath: "entities.error.toolName", parentID: groupNode.id, nodes: &nodes, edges: &edges)
        appendStringArrayAttributes(values: error.filePaths, keyPath: "entities.error.filePaths", parentID: groupNode.id, nodes: &nodes, edges: &edges)
    }

    private func appendGroupNode(
        _ groupNode: IntentGraphNode,
        scenarioNodeID: String,
        nodes: inout [IntentGraphNode],
        edges: inout [IntentGraphEdge]
    ) {
        nodes.append(groupNode)
        edges.append(
            IntentGraphEdge(
                id: "edge:\(scenarioNodeID)->\(groupNode.id)",
                sourceNodeID: scenarioNodeID,
                targetNodeID: groupNode.id,
                type: .contains
            )
        )
    }

    private func appendStringAttribute(
        value: String?,
        keyPath: String,
        parentID: String,
        nodes: inout [IntentGraphNode],
        edges: inout [IntentGraphEdge]
    ) {
        guard let value else { return }
        let nodeID = "field:\(keyPath)"
        let node = IntentGraphNode(
            id: nodeID,
            type: .attribute,
            keyPath: keyPath,
            stringValue: value,
            numberValue: nil
        )
        nodes.append(node)
        edges.append(
            IntentGraphEdge(
                id: "edge:\(parentID)->\(nodeID)",
                sourceNodeID: parentID,
                targetNodeID: nodeID,
                type: .hasAttribute
            )
        )
    }

    private func appendNumberAttribute(
        value: Double?,
        keyPath: String,
        parentID: String,
        nodes: inout [IntentGraphNode],
        edges: inout [IntentGraphEdge]
    ) {
        guard let value else { return }
        let nodeID = "field:\(keyPath)"
        let node = IntentGraphNode(
            id: nodeID,
            type: .attribute,
            keyPath: keyPath,
            stringValue: nil,
            numberValue: value
        )
        nodes.append(node)
        edges.append(
            IntentGraphEdge(
                id: "edge:\(parentID)->\(nodeID)",
                sourceNodeID: parentID,
                targetNodeID: nodeID,
                type: .hasAttribute
            )
        )
    }

    private func appendStringArrayAttributes(
        values: [String]?,
        keyPath: String,
        parentID: String,
        nodes: inout [IntentGraphNode],
        edges: inout [IntentGraphEdge]
    ) {
        guard let values else { return }
        for (index, value) in values.enumerated() {
            let itemKeyPath = "\(keyPath)[\(index)]"
            let nodeID = "field:\(itemKeyPath)"
            let node = IntentGraphNode(
                id: nodeID,
                type: .attribute,
                keyPath: itemKeyPath,
                stringValue: value,
                numberValue: nil
            )
            nodes.append(node)
            edges.append(
                IntentGraphEdge(
                    id: "edge:\(parentID)->\(nodeID)",
                    sourceNodeID: parentID,
                    targetNodeID: nodeID,
                    type: .hasAttribute
                )
            )
        }
    }

    private func compareNode(lhs: IntentGraphNode, rhs: IntentGraphNode) -> Bool {
        lhs.id < rhs.id
    }

    private func compareEdge(lhs: IntentGraphEdge, rhs: IntentGraphEdge) -> Bool {
        lhs.id < rhs.id
    }
}
