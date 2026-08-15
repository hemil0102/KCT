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
    /// 앱이 사용할 문제집. 지금은 번들 JSON에서 읽고, 나중에 서버 문제집으로 교체한다.
    @State private var catalog = QuestionCatalog.bundled()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(catalog)
        }
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self])
    }
}
