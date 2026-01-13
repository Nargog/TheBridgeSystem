//
//  testClickFileView.swift
//  TheBridgeSystem
//
//  Created by Mats Hammarqvist on 2026-01-12.
//

import Foundation

import SwiftUI

// MARK: - Modell

enum Strain: CaseIterable, Identifiable {
    case clubs, diamonds, hearts, spades, notrump
    var id: String { name }

    var name: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        case .notrump: return "NT"
        }
    }

    /// Ordning inom samma nivå (lägsta till högsta): ♣ < ♦ < ♥ < ♠ < NT
    var orderIndex: Int {
        switch self {
        case .clubs: return 0
        case .diamonds: return 1
        case .hearts: return 2
        case .spades: return 3
        case .notrump: return 4
        }
    }

    /// SF Symbols för färgerna. NT har ingen symbol – använd text.
    var symbolName: String? {
        switch self {
        case .clubs: return "suit.club.fill"
        case .diamonds: return "suit.diamond.fill"
        case .hearts: return "suit.heart.fill"
        case .spades: return "suit.spade.fill"
        case .notrump: return nil
        }
    }

    /// Färg/stil per färg
    var foregroundColor: Color {
        switch self {
        case .diamonds, .hearts: return .red
        case .clubs, .spades, .notrump: return .primary
        }
    }
}

struct BridgeBid: Identifiable, Hashable {
    let id = UUID()
    let level: Int  // 1...7
    let strain: Strain

    var labelText: String {
        if strain == .notrump { return "\(level) NT" }
        return "\(level) \(strain.name)"
    }

    /// Global rangordning över alla bud, för jämförelse.
    /// Ex: 1♣ = 0, 1♦ = 1, ... 1NT = 4, 2♣ = 5, osv.
    var rankIndex: Int {
        (level - 1) * 5 + strain.orderIndex
    }
}

// MARK: - Tile

struct BidTile: View {
    let bid: BridgeBid
    let isEnabled: Bool
    let markUndefined: Bool

    var body: some View {
        let backgroundColor: Color = {
            return markUndefined ? Color.red.opacity(0.22) : Color.green.opacity(0.22)
        }()
        let strokeColor: Color = {
            if isEnabled {
                return markUndefined ? Color.red.opacity(0.5) : Color.green.opacity(0.5)
            } else {
                return Color.gray.opacity(0.4)
            }
        }()

        ZStack {
            VStack(spacing: 6) {
                if let symbol = bid.strain.symbolName {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(bid.strain.foregroundColor)
                        .accessibilityHidden(true)
                } else {
                    Text("NT")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(bid.strain.foregroundColor)
                }

                Text(bid.labelText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .opacity((isEnabled ? 1.0 : 0.45) * (markUndefined ? 0.9 : 1.0))
            .accessibilityLabel(bid.labelText + (isEnabled ? "" : " (låst)"))
        }
    }
}

// MARK: - Grid

struct BridgeBidGrid: View {
    let columns: [GridItem]
    let bids: [BridgeBid]
    var onSelect: ((BridgeBid) -> Void)? = nil

    /// Senaste (högsta) bud som låser lägre bud. Om nil är allt tillåtet.
    var currentHighestBid: BridgeBid?

    var shouldMark: ((BridgeBid) -> Bool)? = nil

    init(
        columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
        currentHighestBid: BridgeBid? = nil,
        onSelect: ((BridgeBid) -> Void)? = nil,
        shouldMark: ((BridgeBid) -> Bool)? = nil
    ) {
        self.columns = columns
        self.onSelect = onSelect
        self.currentHighestBid = currentHighestBid
        self.shouldMark = shouldMark
        self.bids = BridgeBidGrid.makeAllBids()
    }

    static func makeAllBids() -> [BridgeBid] {
        var all: [BridgeBid] = []
        for level in 1...7 {
            for strain in Strain.allCases {
                all.append(BridgeBid(level: level, strain: strain))
            }
        }
        return all
    }

    private func isEnabled(_ bid: BridgeBid) -> Bool {
        guard let current = currentHighestBid else { return true }
        return bid.rankIndex > current.rankIndex
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(bids) { bid in
                    let enabled = isEnabled(bid)

                    Group {
                        if let onSelect {
                            Button {
                                onSelect(bid)
                            } label: {
                                BidTile(bid: bid, isEnabled: enabled, markUndefined: (shouldMark?(bid) ?? false))
                            }
                            .buttonStyle(.plain)
                            .disabled(!enabled)
                        } else {
                            BidTile(bid: bid, isEnabled: enabled, markUndefined: (shouldMark?(bid) ?? false))
                        }
                    }
                    .contextMenu {
                        // Låt kopiering fungera även när knappen är låst
                        Button("Kopiera \(bid.labelText)") {
                            UIPasteboard.general.string = bid.labelText
                        }
                        if isEnabled(bid) {
                            Button("Välj \(bid.labelText)") {
                                onSelect?(bid)
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .navigationTitle("Bridgebud")
        .background(Color(.systemBackground))
    }
}

// MARK: - Exempelanvändning jag har bytt namn

struct tstContentView: View {
    @State private var lastSelection: BridgeBid? = nil
    @State private var auction: [BridgeBid] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                BridgeBidGrid(
                    currentHighestBid: lastSelection
                ) { bid in
                    // Tillåt bara giltiga bud (grid:en borde redan ha låst lägre)
                    guard lastSelection == nil || bid.rankIndex > (lastSelection?.rankIndex ?? -1) else { return }
                    auction.append(bid)
                    lastSelection = bid
                    print("Valde: \(bid.labelText)")
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if auction.isEmpty {
                        Text("Ingen budgivning ännu")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Budgivning:")
                            .font(.subheadline.weight(.semibold))
                        // Visa bud i följd
                        Text(auction.map { $0.labelText }.joined(separator: " – "))
                            .font(.body.monospaced())
                    }

                    HStack {
                        Button(role: .destructive) {
                            auction.removeAll()
                            lastSelection = nil
                        } label: {
                            Label("Rensa budgivning", systemImage: "trash")
                        }

                        if !auction.isEmpty {
                            Button {
                                _ = auction.popLast()
                                lastSelection = auction.last
                            } label: {
                                Label("Ångra", systemImage: "arrow.uturn.backward")
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 6)
                }
                .padding()
            }
        }
    }
}

// MARK: - Preview

struct BridgeBidGrid_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BridgeBidGrid(currentHighestBid: nil)
                .previewDisplayName("Grid (allt tillåtet)")
            BridgeBidGrid(currentHighestBid: BridgeBid(level: 1, strain: .notrump))
                .previewDisplayName("Efter 1NT (1♣–1♠ låsta)")
            ContentView()
                .previewDisplayName("Med låsning och historik")
        }
    }
}

