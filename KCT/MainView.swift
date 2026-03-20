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
                VStack(spacing: 0) {
                    TopView()
                        .frame(height: 160)
                    QuestionListView()
                }
            }
            .tabItem {
                Label("면접 문제집", systemImage: "house")
            }

            NavigationStack {
                Text("화면")
                    .navigationTitle("문제 풀이")
            }
            .tabItem {
                Label("문제 풀이", systemImage: "document")
            }
            
            NavigationStack {
                Text("화면")
                    .navigationTitle("문제 기록")
            }
            .tabItem {
                Label("문제 기록", systemImage: "heart")
            }

            NavigationStack {
                Text("화면")
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
