import SwiftUI
import SwiftData

// MARK: - DATAMODELL
// Detta är hjärtat i appen som SwiftData sparar åt dig.
@Model
class BidNode {
    var id: UUID
    var bidName: String       // T.ex. "1 Klöver"
    var meaning: String       // T.ex. "12+ HP, 3+ klöver..."
    var creationDate: Date
    
    // Relationer: Ett bud kan ha många svarsbud (Children)
    // .cascade betyder: Tar du bort "1 Klöver", försvinner alla svar på det automatiskt.
    @Relationship(deleteRule: .cascade) 
    var responses: [BidNode] = []
    
    // Relation: Ett bud har en förälder (budet innan), om det inte är ett öppningsbud.
    @Relationship(inverse: \BidNode.responses)
    var parent: BidNode?
    
    init(bidName: String, meaning: String, parent: BidNode? = nil) {
        self.id = UUID()
        self.bidName = bidName
        self.meaning = meaning
        self.parent = parent
        self.creationDate = Date()
    }
}

// MARK: - HUVUDVY (Navigering)
struct ContentView: View {
    // Hämtar data context från appen
    @Environment(\.modelContext) private var modelContext
    
    // Hämtar alla bud som INTE har en förälder (dvs. Öppningsbuden)
    @Query(filter: #Predicate<BidNode> { $0.parent == nil }, sort: \BidNode.creationDate)
    private var openingBids: [BidNode]
    
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(openingBids) { bid in
                    NavigationLink(value: bid) {
                        VStack(alignment: .leading) {
                            Text(bid.bidName)
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text(bid.meaning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteOpeningBids)
            }
            .navigationTitle("Öppningsbud")
            .navigationDestination(for: BidNode.self) { bid in
                BidDetailView(node: bid)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Nytt Bud", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBidView(parent: nil) // Parent nil = Öppningsbud
            }
        }
    }
    
    private func deleteOpeningBids(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(openingBids[index])
        }
    }
}

// MARK: - DETALJVY (Nivå 2, 3, 4...)
// Denna vy används återkommande för varje nivå i trädet.
struct BidDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var node: BidNode // @Bindable låter oss redigera noden direkt
    
    @State private var showingAddResponseSheet = false
    
    var body: some View {
        Form {
            // SEKTION 1: Redigera nuvarande bud
            Section(header: Text("Nuvarande Bud")) {
                TextField("Bud (t.ex. 1 Ruter)", text: $node.bidName)
                    .font(.headline)
                
                TextField("Betydelse", text: $node.meaning, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            // SEKTION 2: Svarsbuden (Nästa nivå)
            Section(header: Text("Svar på \(node.bidName)")) {
                if node.responses.isEmpty {
                    Text("Inga svarsbud inlagda än.")
                        .italic()
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(node.responses.sorted(by: { $0.creationDate < $1.creationDate })) { response in
                            NavigationLink(value: response) {
                                VStack(alignment: .leading) {
                                    Text(response.bidName)
                                        .font(.body)
                                        .bold()
                                    Text(response.meaning)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteResponse)
                    }
                }
                
                Button(action: { showingAddResponseSheet = true }) {
                    Label("Lägg till svarsbud", systemImage: "arrow.turn.down.right")
                }
            }
        }
        .navigationTitle(node.bidName)
        .sheet(isPresented: $showingAddResponseSheet) {
            AddBidView(parent: node)
        }
    }
    
    private func deleteResponse(offsets: IndexSet) {
        let sortedResponses = node.responses.sorted(by: { $0.creationDate < $1.creationDate })
        for index in offsets {
            modelContext.delete(sortedResponses[index])
        }
    }
}

// MARK: - LÄGG TILL NYTT BUD (Formulär)
struct AddBidView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var parent: BidNode? // Om nil, är det ett öppningsbud
    
    @State private var bidName = ""
    @State private var meaning = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Budgivning")) {
                    TextField("Bud (t.ex. 1 NT)", text: $bidName)
                    TextField("Beskrivning (Min 4 ruter, 6+ hp...)", text: $meaning, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(parent == nil ? "Nytt Öppningsbud" : "Svara på \(parent!.bidName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        let newBid = BidNode(bidName: bidName, meaning: meaning, parent: parent)
                        
                        if let parentNode = parent {
                            // Koppla ihop med föräldern
                            parentNode.responses.append(newBid)
                        } else {
                            // Inget förälder = Spara direkt till context (öppningsbud)
                            modelContext.insert(newBid)
                        }
                        
                        dismiss()
                    }
                    .disabled(bidName.isEmpty)
                }
            }
        }
    }
}