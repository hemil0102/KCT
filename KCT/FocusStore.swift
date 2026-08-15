//
//  FocusStore.swift
//  KCT
//
//  "질문이 묻는 대상"을 어디서 가져올지 정하고, 모자란 것은 백그라운드로 채운다.
//
//  읽는 순서:
//    1) 서버가 내려준 값        — (아직 없음. 서버 도입 시 여기서 걸린다)
//    2) 모델 분석 캐시          — 한 번 분석해 둔 결과
//    3) 규칙 기반               — 즉시 계산. 항상 동작하는 안전망
//
//  3번 덕분에 새 문제가 언제 추가돼도 기다림 없이 바로 표시되고,
//  모델 분석은 뒤에서 조용히 진행되어 다음 노출부터 품질이 올라간다.
//

import Foundation
import SwiftData

@MainActor
struct FocusStore {
    let modelContext: ModelContext

    /// 문제들의 묻는 대상을 모아 온다. (캐시 우선, 없으면 규칙 기반)
    func focuses(for questions: [Question]) -> [Int: QuestionFocus] {
        let cached = cachedRecords()

        var result: [Int: QuestionFocus] = [:]
        for question in questions {
            if let record = cached[question.id],
               record.textHash == QuestionFocusRecord.hash(of: question.question) {
                result[question.id] = record.focus          // 2) 캐시
            } else if let rule = QuestionFocusExtractor.focus(in: question.question) {
                result[question.id] = rule                  // 3) 규칙 기반
            }
        }
        return result
    }

    /// 아직 분석하지 않은 문제를 백그라운드에서 모델로 분석해 캐시에 저장한다.
    /// 화면을 막지 않으며, 실패하면 규칙 기반 결과가 계속 쓰인다.
    func analyzeMissing(in questions: [Question], limit: Int = 5) async {
        guard FocusAnalyzer.isAvailable else { return }

        let cached = cachedRecords()
        let pending = questions.filter { question in
            guard let record = cached[question.id] else { return true }
            return record.textHash != QuestionFocusRecord.hash(of: question.question)
        }
        guard !pending.isEmpty else { return }

        let analyzer = FocusAnalyzer()
        for question in pending.prefix(limit) {
            if Task.isCancelled { return }
            guard let focus = try? await analyzer.analyze(question: question.question) else {
                continue    // 모델이 실패하거나 지어낸 답을 주면 건너뛴다
            }
            save(focus, for: question)
        }
        try? modelContext.save()
    }

    // MARK: - 저장소 다루기

    private func cachedRecords() -> [Int: QuestionFocusRecord] {
        let records = (try? modelContext.fetch(FetchDescriptor<QuestionFocusRecord>())) ?? []
        return Dictionary(records.map { ($0.questionID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func save(_ focus: QuestionFocus, for question: Question) {
        let hash = QuestionFocusRecord.hash(of: question.question)

        if let existing = cachedRecords()[question.id] {
            existing.phrase = focus.phrase
            existing.category = focus.category
            existing.textHash = hash
            existing.analyzedAt = .now
        } else {
            modelContext.insert(
                QuestionFocusRecord(
                    questionID: question.id,
                    textHash: hash,
                    phrase: focus.phrase,
                    category: focus.category
                )
            )
        }
    }
}
