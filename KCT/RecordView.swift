//
//  RecordView.swift
//  KCT
//
//  1a 디자인 반영 — 문제 기록 (즐겨찾기)
//

import SwiftUI

struct RecordView: View {
    let store: QuestionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("문제 기록")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(KCTTheme.textDark)
                Text("즐겨찾기한 문제 · \(store.favorites.count)개")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(KCTTheme.chipMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if store.favorites.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("🤍")
                        .font(.system(size: 40))
                    Text("아직 즐겨찾기한 문제가 없어요")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(KCTTheme.chipMuted)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(store.favorites) { question in
                    QuestionCard(question: question) {
                        store.toggleFavorite(question)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.bottom, 4)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

#Preview {
    RecordView(store: QuestionStore())
}
