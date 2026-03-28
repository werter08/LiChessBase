//
//  Chess_BaseApp.swift
//  Chess Base
//
//  Created by Begench Yangibayev on 23.03.2026.
//

import SwiftUI
import CoreData
import Resolver

@main
struct Chess_BaseApp: App {

    init() {
        Resolver.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
