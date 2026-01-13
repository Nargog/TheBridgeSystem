import SwiftUI
import SwiftData

struct BidNodeInputView: View {
    @Environment(\.modelContext) private var modelContext

    // All opening bids (parent == nil)
    @Query(filter: #Predicate<BidNode> { $0.parent == nil }, sort: \BidNode.creationDate)
    private var openingBids: [BidNode]

    @State private var newBidName: String = ""
    @State private var newMeaning: String = ""
    @State private var selectedParent: BidNode? = nil

    // Batch input (one per line: "Budname — Meaning")
    @State private var batchText: String = ""
    @State private var showBatchSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Quick add section
                GroupBox("Snabbinmatning") {
                    VStack(alignment: .leading, spacing: 8) {
                        // Parent picker (nil => opening bid)
                        ParentPicker(selectedParent: $selectedParent, openingBids: openingBids)

                        TextField("Bud (t.ex. 1 Klöver)", text: $newBidName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)

                        TextField("Betydelse (t.ex. 12+ hp, 3+ klöver)", text: $newMeaning, axis: .vertical)
                            .lineLimit(2...4)
                            .submitLabel(.done)

                        HStack {
                            Button {
                                addSingle()
                            } label: {
                                Label("Lägg till", systemImage: "plus.circle.fill")
                            }
                            .disabled(newBidName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Spacer()

                            Button {
                                showBatchSheet = true
                            } label: {
                                Label("Batch", systemImage: "list.bullet.rectangle.portrait")
                            }
                            .accessibilityHint("Klistra in flera rader för att skapa många bud snabbt")
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Tree list
                List {
                    Section("Öppningsbud") {
                        if openingBids.isEmpty {
                            Text("Inga öppningsbud ännu").foregroundStyle(.secondary)
                        } else {
                            ForEach(openingBids) { node in
                                NodeRow(node: node)
                            }
                            .onDelete(perform: deleteOpening)
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .navigationTitle("Beslutsträd")
        }
        .sheet(isPresented: $showBatchSheet) {
            BatchInputView(selectedParent: selectedParent) { pairs in
                addBatch(pairs: pairs)
            }
        }
    }

    private func addSingle() {
        let name = newBidName.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = newMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let node = BidNode(bidName: name, meaning: desc, parent: selectedParent)
        if let parent = selectedParent {
            parent.responses.append(node)
        } else {
            modelContext.insert(node)
        }
        newBidName = ""
        newMeaning = ""
    }

    private func addBatch(pairs: [(String, String)]) {
        for (name, meaning) in pairs {
            let node = BidNode(bidName: name, meaning: meaning, parent: selectedParent)
            if let parent = selectedParent {
                parent.responses.append(node)
            } else {
                modelContext.insert(node)
            }
        }
    }

    private func deleteOpening(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(openingBids[index]) }
    }
}

// MARK: - Parent Picker
private struct ParentPicker: View {
    @Binding var selectedParent: BidNode?
    var openingBids: [BidNode]

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Förälder:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showPicker.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down.circle")
                        Text(selectedParent?.bidName ?? "(Öppningsbud)")
                            .lineLimit(1)
                    }
                }
            }
            if showPicker {
                ParentTreeList(selectedParent: $selectedParent, roots: openingBids)
                    .frame(maxHeight: 220)
                    .transition(.opacity)
            }
        }
    }
}

private struct ParentTreeList: View {
    @Binding var selectedParent: BidNode?
    var roots: [BidNode]

    var body: some View {
        List {
            Button {
                selectedParent = nil
            } label: {
                Label("(Öppningsbud)", systemImage: selectedParent == nil ? "checkmark.circle.fill" : "circle")
            }

            ForEach(roots) { root in
                ParentNodeRow(node: root, selectedParent: $selectedParent)
            }
        }
        .listStyle(.plain)
    }
}

private struct ParentNodeRow: View {
    var node: BidNode
    @Binding var selectedParent: BidNode?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    selectedParent = node
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedParent?.id == node.id ? "checkmark.circle.fill" : "circle")
                        Text(node.bidName)
                    }
                }
                .buttonStyle(.plain)
            }

            if isExpanded, !node.responses.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(node.responses.sorted(by: { $0.creationDate < $1.creationDate })) { child in
                        ParentNodeRow(node: child, selectedParent: $selectedParent)
                            .padding(.leading, 18)
                    }
                }
            }
        }
    }
}

// MARK: - Tree rows
private struct NodeRow: View {
    @State var node: BidNode
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Button { isExpanded.toggle() } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.bidName).font(.headline)
                    if !node.meaning.isEmpty {
                        Text(node.meaning).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if isExpanded, !node.responses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(node.responses.sorted(by: { $0.creationDate < $1.creationDate })) { child in
                        NodeRow(node: child)
                            .padding(.leading, 18)
                    }
                }
            }
        }
    }
}

// MARK: - Batch input sheet
private struct BatchInputView: View {
    var selectedParent: BidNode?
    var onCommit: ([(String, String)]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Klistra in flera rader. Format: Bud — Beskrivning")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    )

                HStack {
                    Spacer()
                    Button("Lägg till") {
                        let pairs = parse(text: text)
                        onCommit(pairs)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle(selectedParent == nil ? "Batch: Öppningsbud" : "Batch: Svar på \(selectedParent!.bidName)")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } } }
        }
    }

    private func parse(text: String) -> [(String, String)] {
        let lines = text.split(separator: "\n").map { String($0) }
        var result: [(String, String)] = []
        for line in lines {
            let parts = line.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                result.append((parts[0], parts[1]))
            } else if parts.count == 1 {
                result.append((parts[0], ""))
            }
        }
        return result
    }
}

#Preview {
    BidNodeInputView()
}
