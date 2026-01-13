import SwiftUI
import SwiftData

// Helper to map BridgeBid label to BidNode bidName
private func bidName(from bridgeBid: BridgeBid) -> String {
    return bridgeBid.labelText // e.g. "1 ♣" or "1 NT"
}

struct BidSequenceBuilderView: View {
    @Environment(\.modelContext) private var modelContext

    // Opening nodes (roots) for quick access if we need to create/find first node
    @Query(filter: #Predicate<BidNode> { $0.parent == nil }, sort: \BidNode.creationDate)
    private var openingBids: [BidNode]

    // Keeps the current path of nodes representing the sequence
    @State private var sequenceNodes: [BidNode] = []
    @State private var currentHighestBridgeBid: BridgeBid? = nil

    // Meaning editor prompt
    @State private var showMeaningSheet = false
    @State private var meaningDraft: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BridgeBidGrid(currentHighestBid: currentHighestBridgeBid) { bid in
                    handleSelect(bridgeBid: bid)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    if sequenceNodes.isEmpty {
                        Text("Ingen budsekvens ännu").foregroundStyle(.secondary)
                    } else {
                        Text("Sekvens:")
                            .font(.subheadline.weight(.semibold))
                        Text(sequenceNodes.map { $0.bidName }.joined(separator: " – "))
                            .font(.body.monospaced())

                        // Current node meaning
                        if let current = sequenceNodes.last {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Betydelse för \(current.bidName)")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button {
                                        meaningDraft = current.meaning
                                        showMeaningSheet = true
                                    } label: {
                                        Label(current.meaning.isEmpty ? "Lägg till" : "Redigera", systemImage: "square.and.pencil")
                                    }
                                }
                                if current.meaning.isEmpty {
                                    Text("Ingen beskrivning ännu").foregroundStyle(.secondary)
                                } else {
                                    Text(current.meaning)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack {
                            Button(role: .destructive) {
                                clearSequence()
                            } label: {
                                Label("Rensa", systemImage: "trash")
                            }

                            if !sequenceNodes.isEmpty {
                                Button {
                                    _ = sequenceNodes.popLast()
                                    // Recompute highest bid for grid lock
                                    if let last = sequenceNodes.last, let parsed = parseBridgeBid(from: last.bidName) {
                                        currentHighestBridgeBid = parsed
                                    } else {
                                        currentHighestBridgeBid = nil
                                    }
                                } label: {
                                    Label("Ångra", systemImage: "arrow.uturn.backward")
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Bygg budsekvens")
        }
        .sheet(isPresented: $showMeaningSheet) {
            MeaningEditorSheet(title: sequenceNodes.last?.bidName ?? "", text: $meaningDraft) {
                if let node = sequenceNodes.last {
                    node.meaning = meaningDraft
                }
            }
        }
    }

    private func clearSequence() {
        sequenceNodes.removeAll()
        currentHighestBridgeBid = nil
    }

    private func handleSelect(bridgeBid: BridgeBid) {
        // Find or create the node under current parent
        let name = bidName(from: bridgeBid)
        let parent = sequenceNodes.last

        let node: BidNode
        if let existing = findChild(named: name, under: parent) {
            node = existing
        } else {
            let newNode = BidNode(bidName: name, meaning: "", parent: parent)
            if let parent = parent {
                parent.responses.append(newNode)
            } else {
                modelContext.insert(newNode)
            }
            node = newNode
        }

        sequenceNodes.append(node)
        currentHighestBridgeBid = bridgeBid

        // If no meaning, prompt to add
        if node.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            meaningDraft = ""
            showMeaningSheet = true
        }
    }

    private func findChild(named name: String, under parent: BidNode?) -> BidNode? {
        if let parent = parent {
            return parent.responses.first { $0.bidName == name }
        } else {
            return openingBids.first { $0.bidName == name }
        }
    }

    // Parse back from a BidNode bidName (like "1 ♣" or "1 NT") to BridgeBid
    private func parseBridgeBid(from text: String) -> BridgeBid? {
        // Basic parsing: expect level first
        let parts = text.split(separator: " ")
        guard let first = parts.first, let level = Int(first) else { return nil }
        if parts.count >= 2 {
            let suit = parts[1]
            switch suit {
            case "♣": return BridgeBid(level: level, strain: .clubs)
            case "♦": return BridgeBid(level: level, strain: .diamonds)
            case "♥": return BridgeBid(level: level, strain: .hearts)
            case "♠": return BridgeBid(level: level, strain: .spades)
            case "NT": return BridgeBid(level: level, strain: .notrump)
            default: return nil
            }
        }
        return nil
    }
}

private struct MeaningEditorSheet: View {
    var title: String
    @Binding var text: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Beskrivning för \(title)")
                    .font(.headline)
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Spacer()
            }
            .padding()
            .navigationTitle("Beskrivning")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BidSequenceBuilderView()
}
