//
//  BuddyParkApp.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/8/11.
//

import SwiftUI

@main
struct BuddyParkApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
