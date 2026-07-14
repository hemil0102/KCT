//
//  MainView.swift
//  KCT
//
//  1a 디자인 반영
//

import SwiftUI

struct MainView: View {
    @State private var store = QuestionStore()

    init() {
        // 탭바 배경을 테마 색으로
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 1.0, green: 0.953, blue: 0.910, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 0) {
                    TopView()
                    QuestionListView(store: store)
                }
                .background(KCTTheme.cream.ignoresSafeArea())
            }
            .tabItem {
                Label("면접 문제집", systemImage: "book.fill")
            }

            NavigationStack {
                PracticeView(store: store)
                    .background(KCTTheme.cream.ignoresSafeArea())
            }
            .tabItem {
                Label("문제 풀이", systemImage: "rectangle.stack.fill")
            }

            NavigationStack {
                RecordView(store: store)
                    .background(KCTTheme.cream.ignoresSafeArea())
            }
            .tabItem {
                Label("문제 기록", systemImage: "heart.fill")
            }

            NavigationStack {
                SettingsView()
                    .background(KCTTheme.cream.ignoresSafeArea())
            }
            .tabItem {
                Label("설정", systemImage: "gearshape.fill")
            }
        }
        .tint(KCTTheme.orangeBottom)
    }
}

#Preview {
    MainView()
}
