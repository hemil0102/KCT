//
//  PracticeView.swift
//  KCT
//
//  1a 디자인 반영 — 문제 풀이 (플래시카드)
//

import SwiftUI

struct PracticeView: View {
    let store: QuestionStore
    @State private var index: Int = 0
    @State private var revealed: Bool = false

    private var questions: [Question] { store.questions }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("문제 풀이")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(KCTTheme.textDark)
                Text("\(min(index + 1, questions.count)) / \(questions.count)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(KCTTheme.chipMuted)
            }
            .padding(.top, 24)
            .padding(.bottom, 12)

            Spacer()

            if let question = questions[safe: index] {
                VStack(spacing: 18) {
                    Text("\(question.category) · \(question.level)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(KCTTheme.orangeBottom)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(KCTTheme.chipBg.opacity(0.6))
                        .clipShape(Capsule())

                    Text(revealed ? question.answer : question.title)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(KCTTheme.textDark)
                        .animation(.easeInOut(duration: 0.2), value: revealed)
                }
                .padding(32)
                .frame(maxWidth: .infinity, minHeight: 280)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.orange.opacity(0.12), radius: 20, x: 0, y: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(KCTTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 28)
                .onTapGesture { revealed.toggle() }

                HStack(spacing: 6) {
                    ForEach(0..<min(questions.count, 10), id: \.self) { i in
                        Circle()
                            .fill(i == index % max(questions.count, 1) ? KCTTheme.orangeBottom : KCTTheme.cardBorder)
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.top, 22)

                Button {
                    revealed = true
                } label: {
                    Text("정답 보기")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(KCTTheme.orangeGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: KCTTheme.orangeBottom.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)

                Button {
                    revealed = false
                    index = (index + 1) % max(questions.count, 1)
                } label: {
                    Text("다음 문제 ›")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(KCTTheme.textMuted)
                }
                .padding(.top, 14)
            } else {
                Text("문제가 없어요")
                    .foregroundStyle(KCTTheme.chipMuted)
            }

            Spacer()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    PracticeView(store: QuestionStore())
}
