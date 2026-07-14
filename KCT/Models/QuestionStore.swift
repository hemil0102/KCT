//
//  QuestionStore.swift
//  KCT

import SwiftUI

struct Question: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let answer: String
    let category: String
    let level: String
    var isFavorite: Bool = false
}

@Observable
final class QuestionStore {
    var questions: [Question] = [
        Question(title: "우리 나라의 국호는 무엇인가요?", answer: "대한민국", category: "나라", level: "하"),
        Question(title: "수도의 이름은 무엇인가요?", answer: "서울", category: "나라", level: "하", isFavorite: true),
        Question(title: "한글을 만든 왕은 누구인가요?", answer: "세종대왕", category: "인물", level: "하"),
        Question(title: "현재 대통령의 이름은 무엇인가요?", answer: "이재명", category: "인물", level: "중", isFavorite: true),
    ]

    func toggleFavorite(_ question: Question) {
        if let idx = questions.firstIndex(where: { $0.id == question.id }) {
            questions[idx].isFavorite.toggle()
        }
    }

    var favorites: [Question] {
        questions.filter { $0.isFavorite }
    }
}
