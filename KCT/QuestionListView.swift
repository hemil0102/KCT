//
//  QuestionListView.swift
//  KCT
//
//  Created by harryho on 3/12/26.
//

import SwiftUI

struct Question: Identifiable, Hashable {
    let id = UUID()
    let title: String   // 질문
    let answer: String  // 답변
}

// 샘플 데이터 (실제 앱에서는 ViewModel이나 외부에서 주입 가능)
private let sampleQuestions: [Question] = [
    Question(title: "우리 나라의 국호는 무엇인가요?", answer: "대한민국"),
    Question(title: "수도의 이름은 무엇인가요?", answer: "서울"),
    Question(title: "한글을 만든 왕은 누구인가요?", answer: "세종대왕"),
]

struct QuestionListView: View {
    let questions: [Question] = sampleQuestions
    
    var body: some View {
        List(questions) { question in
            ZStack(alignment: .topLeading) {
                // 외곽 영역 라운드를 지정하는 라운드 네모
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 16) {
                    Text("질문: \(question.title)")
                    Text("답변: \(question.answer)")
                }
                .padding(12)
                .frame(minHeight: 120)
                .foregroundStyle(.primary)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .padding(.vertical, 12)
    }
}

#Preview {
    QuestionListView()
}
