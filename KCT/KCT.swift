//
//  KCT.swift
//  KCT
//
//  Created by harryho on 7/1/26.
//

import SwiftUI
import SwiftData

@main
struct KCT: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: QuestionProgress.self)
    }
}
