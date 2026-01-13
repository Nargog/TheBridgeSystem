//
//  TheBridgeSystemApp.swift
//  TheBridgeSystem
//
//  Created by Mats Hammarqvist on 2026-01-12.
//

import SwiftUI
import SwiftData

@main  //   HÄR FINNS MAIN DÄR PRROGRAMMET BÖRJAR!!! -----------------------------------
struct TheBridgeSystemApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: BidNode.self, Item.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    
    // HÄR ANROPAS FÖRSTA VIEW
    var body: some Scene {
        WindowGroup {
            BidSequenceBuilderView()
            // ContentView()  // originalview
            // Jag har bytt till att starta en annan vieew !!!
        }
        .modelContainer(sharedModelContainer)
    }
}

