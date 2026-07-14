//
//  QuestionListView.swift
//  KCT
//
//  1a 디자인 반영 — 카테고리/난이도 필터 + 즐겨찾기 카드 리스트
//

import SwiftUI

struct QuestionListView: View {
    let store: QuestionStore
    @AppStorage("questionFontSize") private var fontSizeRaw: String = QuestionFontSize.medium.rawValue

    @State private var selectedCategory: String = "전체"
    @State private var selectedLevel: String = "전체"

    private var fontSize: QuestionFontSize {
        QuestionFontSize(rawValue: fontSizeRaw) ?? .medium
    }

    private var categories: [String] {
        let unique = Set(store.questions.map { $0.category })
        return ["전체"] + unique.sorted()
    }

    private var levels: [String] {
        let unique = Set(store.questions.map { $0.level })
        return ["전체"] + unique.sorted()
    }

    private var filteredQuestions: [Question] {
        store.questions.filter { q in
            let matchCategory = (selectedCategory == "전체") || (q.category == selectedCategory)
            let matchLevel = (selectedLevel == "전체") || (q.level == selectedLevel)
            return matchCategory && matchLevel
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    Picker("카테고리", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                } label: {
                    filterChip("카테고리: \(selectedCategory)")
                }

                Menu {
                    Picker("난이도", selection: $selectedLevel) {
                        ForEach(levels, id: \.self) { lvl in
                            Text(lvl).tag(lvl)
                        }
                    }
                } label: {
                    filterChip("난이도: \(selectedLevel)")
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

            List(filteredQuestions) { question in
                QuestionCard(question: question, fontSize: fontSize.titleSize) {
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

    private func filterChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(KCTTheme.chipText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(KCTTheme.chipBg)
            .clipShape(Capsule())
    }
}

struct QuestionCard: View {
    let question: Question
    var fontSize: CGFloat = 19
    var onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(question.category) · \(question.level)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(KCTTheme.orangeBottom)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(KCTTheme.chipBg.opacity(0.6))
                    .clipShape(Capsule())

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: question.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(question.isFavorite ? .red : .gray.opacity(0.4))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }

            Text(question.title)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(KCTTheme.textDark)

            Text("답변 보기 ›")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(KCTTheme.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.orange.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KCTTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    QuestionListView(store: QuestionStore())
}
