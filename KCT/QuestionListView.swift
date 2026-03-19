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
    let category: String // 분류
    let level: String // 난이도
}

// 샘플 데이터 (실제 앱에서는 ViewModel이나 외부에서 주입 가능)
private let sampleQuestions: [Question] = [
    Question(title: "우리 나라의 국호는 무엇인가요?", answer: "대한민국", category: "나라", level: "하"),
    Question(title: "수도의 이름은 무엇인가요?", answer: "서울", category: "나라", level: "하"),
    Question(title: "한글을 만든 왕은 누구인가요?", answer: "세종대왕", category: "인물", level: "하"),
]

struct QuestionListView: View {
    let questions: [Question] = sampleQuestions
    
    // 선택 상태
    @State private var selectedCategory: String = "전체"
    @State private var selectedLevel: String = "전체"

    // 선택지(데이터에서 추출 + "전체")
    private var categories: [String] {
        let unique = Set(questions.map { $0.category })
        return ["전체"] + unique.sorted()
    }
    private var levels: [String] {
        let unique = Set(questions.map { $0.level })
        return ["전체"] + unique.sorted()
    }

    // 필터된 결과
    private var filteredQuestions: [Question] {
        questions.filter { q in
            let matchCategory = (selectedCategory == "전체") || (q.category == selectedCategory)
            let matchLevel = (selectedLevel == "전체") || (q.level == selectedLevel)
            return matchCategory && matchLevel
        }
    }
    
    var body: some View {
        HStack{
            Text("귀화 질문 목록")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .padding(.leading, 16)
            
            Spacer()
            
            HStack(spacing: 16) {
                Menu {
                    Picker("카테고리", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                } label: {
                    HStack {
                        Text("카테고리:")
                        Text(selectedCategory)
                            .fontWeight(.semibold)
                    }
                }

                Menu {
                    Picker("난이도", selection: $selectedLevel) {
                        ForEach(levels, id: \.self) { lvl in
                            Text(lvl).tag(lvl)
                        }
                    }
                } label: {
                    HStack {
                        Text("난이도:")
                        Text(selectedLevel)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(.trailing, 16)
        }
        
        List(filteredQuestions) { question in
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
