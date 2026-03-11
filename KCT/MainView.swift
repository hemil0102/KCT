//
//  MainView.swift
//  KCT
//
//  Created by harryho on 3/7/26.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            NavigationStack {
                Text("홈 화면")
                    .navigationTitle("홈")
            }
            .tabItem {
                Label("홈", systemImage: "house")
            }

            NavigationStack {
                Text("검색 화면")
                    .navigationTitle("검색")
            }
            .tabItem {
                Label("검색", systemImage: "magnifyingglass")
            }

            NavigationStack {
                Text("설정 화면")
                    .navigationTitle("설정")
            }
            .tabItem {
                Label("설정", systemImage: "gear")
            }
        }
    }
}

#Preview {
    MainView()
}
