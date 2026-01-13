import SwiftUI
import SwiftData

enum Seat: String, CaseIterable, Identifiable {
    case south = "S", west = "W", north = "N", east = "E"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .south: return "Syd"
        case .west: return "Väst"
        case .north: return "Nord"
        case .east: return "Öst"
        }
    }
    func next() -> Seat {
        switch self {
        case .south: return .west
        case .west: return .north
        case .north: return .east
        case .east: return .south
        }
    }
    func prev() -> Seat {
        switch self {
        case .south: return .east
        case .west:  return .south
        case .north: return .west
        case .east:  return .north
        }
    }
}

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

    @State private var dealer: Seat = .south
    @State private var currentSeat: Seat = .south

    // Meaning editor prompt
    @State private var showMeaningSheet = false
    @State private var meaningDraft: String = ""
    @State private var shouldResetAfterSheet = false
    
    @State private var showDefinitionSheet = false

    @State private var consecutivePasses: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Giv: \(dealer.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("På tur:")
                            .font(.subheadline.weight(.semibold))
                        Text(currentSeat.displayName)
                            .font(.headline)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                BridgeBidGrid(
                    currentHighestBid: currentHighestBridgeBid,
                    onSelect: { bid in
                        handleSelect(bridgeBid: bid)
                    },
                    shouldMark: { bid in
                        let name = bidName(from: bid)
                        let parent = sequenceNodes.last
                        if let existing = findChild(named: name, under: parent) {
                            return existing.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        } else {
                            // If node doesn't exist yet, we consider it undefined => mark it
                            return true
                        }
                    }
                )
                HStack {
                    Spacer()
                    Button {
                        handlePass()
                    } label: {
                        Label("PASS", systemImage: "hand.raised")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .padding(.trailing, 12)
                }
                .padding(.vertical, 6)

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
                                    Button {
                                        showDefinitionSheet = true
                                    } label: {
                                        Label("Definition", systemImage: "slider.horizontal.3")
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
                                    if let removed = sequenceNodes.popLast() {
                                        // Step turn back
                                        currentSeat = currentSeat.prev()

                                        // Adjust consecutive passes
                                        if removed.bidName == "PASS" {
                                            consecutivePasses = max(0, consecutivePasses - 1)
                                        } else {
                                            consecutivePasses = 0
                                        }

                                        // Recompute highest bid lock from the last non-PASS
                                        if let lastNonPass = sequenceNodes.reversed().first(where: { $0.bidName != "PASS" }),
                                           let parsed = parseBridgeBid(from: lastNonPass.bidName) {
                                            currentHighestBridgeBid = parsed
                                        } else {
                                            currentHighestBridgeBid = nil
                                        }
                                    } else {
                                        // Nothing to undo; ensure state is clean
                                        currentSeat = .south
                                        currentHighestBridgeBid = nil
                                        consecutivePasses = 0
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
                if shouldResetAfterSheet {
                    clearSequence()
                    consecutivePasses = 0
                    shouldResetAfterSheet = false
                }
            }
        }
        .sheet(isPresented: $showDefinitionSheet) {
            if let node = sequenceNodes.last {
                DefinitionEditorSheet(node: node)
            }
        }
    }

    private func clearSequence() {
        sequenceNodes.removeAll()
        currentHighestBridgeBid = nil
        currentSeat = dealer
        consecutivePasses = 0
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

        node.bidder = currentSeat.rawValue

        consecutivePasses = 0

        sequenceNodes.append(node)
        currentHighestBridgeBid = bridgeBid

        currentSeat = currentSeat.next()

        // If no meaning, prompt to add
        if node.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            meaningDraft = ""
            showMeaningSheet = true
        }
    }

    private func handlePass() {
        // Create/find PASS as child of current parent
        let parent = sequenceNodes.last
        let name = "PASS"
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

        node.bidder = currentSeat.rawValue

        sequenceNodes.append(node)
        currentSeat = currentSeat.next()

        consecutivePasses += 1

        // Lock grid by clearing currentHighestBridgeBid to avoid further rank-based choices
        currentHighestBridgeBid = nil

        let shouldEnd = (consecutivePasses >= 3)
        let needsMeaning = node.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if needsMeaning {
            meaningDraft = ""
            shouldResetAfterSheet = shouldEnd
            showMeaningSheet = true
        } else if shouldEnd {
            clearSequence()
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

private struct DefinitionEditorSheet: View {
    @Bindable var node: BidNode
    @Environment(\.dismiss) private var dismiss

    @State private var minHP: Int = 0
    @State private var maxHP: Int = 0
    @State private var minClubs: Int = 0
    @State private var minDiamonds: Int = 0
    @State private var minHearts: Int = 0
    @State private var minSpades: Int = 0
    @State private var isBalanced: Bool = false
    @State private var tagsText: String = ""

    init(node: BidNode) {
        self._node = Bindable(wrappedValue: node)
        // Preload defaults from node in onAppear instead
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("HP") {
                    Stepper(value: $minHP, in: 0...37) { Text("Min HP: \(minHP)") }
                    Stepper(value: $maxHP, in: 0...37) { Text("Max HP: \(maxHP)") }
                }
                Section("Minsta längd i färg") {
                    Stepper(value: $minClubs, in: 0...7) { Text("Klöver: \(minClubs)") }
                    Stepper(value: $minDiamonds, in: 0...7) { Text("Ruter: \(minDiamonds)") }
                    Stepper(value: $minHearts, in: 0...7) { Text("Hjärter: \(minHearts)") }
                    Stepper(value: $minSpades, in: 0...7) { Text("Spader: \(minSpades)") }
                }
                Section("Balans & Taggar") {
                    Toggle("Balanserad", isOn: $isBalanced)
                    TextField("Taggar (kommaseparerade)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Definition: \(node.bidName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        node.minHP = minHP
                        node.maxHP = maxHP
                        node.minClubs = minClubs
                        node.minDiamonds = minDiamonds
                        node.minHearts = minHearts
                        node.minSpades = minSpades
                        node.isBalanced = isBalanced
                        node.tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        dismiss()
                    }
                }
            }
            .onAppear {
                minHP = node.minHP ?? 0
                maxHP = node.maxHP ?? 0
                minClubs = node.minClubs ?? 0
                minDiamonds = node.minDiamonds ?? 0
                minHearts = node.minHearts ?? 0
                minSpades = node.minSpades ?? 0
                isBalanced = node.isBalanced ?? false
                tagsText = node.tags.joined(separator: ", ")
            }
        }
    }
}

#Preview {
    BidSequenceBuilderView()
}
