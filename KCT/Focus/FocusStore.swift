//
//  FocusStore.swift
//  KCT
//
//  역할 : "묻는 대상" 을 어느 층에서 가져올지 정하고, 모자란 것은 백그라운드로 채운다
//  요점 : 3층(규칙 기반)이 항상 있으니 어떤 경우에도 기다리지 않는다
//
//  ── 구성 ──────────────────────────────────────────────
//  FocusStore
//  ├─ usesModelAnalysis        ⚠️ 모델 분석 층 on/off 스위치. 지금 false
//  ├─ modelContext             캐시를 읽고 쓸 저장소
//  ├─ focuses(for:)            문제들의 묻는 대상을 모아 온다 (즉시 반환)
//  ├─ analyzeMissing(in:limit:)  아직 분석 안 된 것을 백그라운드로 채운다
//  ├─ cachedRecords()          저장된 분석 결과를 id 로 찾을 수 있게
//  └─ save(_:for:)             분석 결과를 캐시에 기록
//
//  ── 세 개의 층 (읽는 순서) ────────────────────────────
//  1) 서버가 내려준 값   — 아직 없음. 서버 도입 시 여기서 걸린다
//  2) 모델 분석 캐시     — QuestionFocusRecord. **지금 꺼져 있음**
//  3) 규칙 기반         — QuestionFocusExtractor. 즉시 계산. 항상 동작하는 안전망
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.start()
//    → focuses(for: 문제들) : 캐시에 있으면 그것, 없으면 규칙 기반으로 즉시
//    → 결과를 SessionBuilder 에 넘겨 QuizItem.focus 로 심는다
//  QuizSession.warmFocusCache()  (기다리지 않음)
//    → analyzeMissing(in:) : 모델로 분석해 캐시에 저장 → 다음 노출부터 품질 향상
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession(start · warmFocusCache)
//  기대는 것    : QuestionFocusExtractor(3층), FocusAnalyzer(2층), QuestionFocusRecord(캐시)
//  건드리지 않는 것 : 화면 표시 — 무엇을 칠할지는 QuizItem.markerText 가 정한다
//

import Foundation
import SwiftData

/// "질문이 묻는 대상" 을 어디서 가져올지 정하는 곳.
///
/// ## 왜 세 층인가
///
/// | 층 | 무엇 | 지연 | 상태 |
/// |---|---|---|---|
/// | 1 | 서버가 내려준 값 | 0 | 아직 없음 |
/// | 2 | 모델 분석 캐시 | 0 (미리 계산됨) | **꺼짐** |
/// | 3 | 규칙 기반 | 0 (즉시 계산) | ✅ 동작 |
///
/// 3층이 항상 있기 때문에 **새 문제가 언제 추가돼도 기다림 없이** 형광펜이
/// 표시됩니다. 모델 분석은 뒤에서 조용히 진행되어 다음 노출부터 품질이 올라갑니다.
/// 즉 모델은 "있으면 좋은 것" 이고 없어도 앱이 성립합니다.
///
/// - Important: 지금 **2층은 꺼져 있습니다**(``usesModelAnalysis`` 가 `false`).
///   그래서 ``FocusAnalyzer`` 와 ``QuestionFocusRecord`` 는 호출되지 않습니다.
///   버그가 아니라 의도된 상태이며, 이유와 다시 켤 조건은 아래에 적어 두었습니다.
@MainActor
struct FocusStore {

    /// 모델 분석 층(2층)을 쓸지 여부.
    ///
    /// 지금은 꺼 둡니다 — 모델이 "묻는 대상" 대신 **질문 문장 전체를 돌려주는
    /// 경우가 많아** 지문이 통째로 형광펜 처리됐습니다. 규칙 기반(3층)만으로도
    /// 충분히 동작합니다.
    ///
    /// - Important: 다시 켤 때 `true` 로 바꾸는 것만으로는 같은 문제가 재발합니다.
    ///   **강조 길이 제한**(예: 지문 절반을 넘으면 버림) 같은 검증을 함께 넣으세요.
    ///   지금 있는 검증은 ``FocusAnalyzer`` 의 "지문에 실제로 있는 문자열인가" 하나뿐입니다.
    static let usesModelAnalysis = false

    let modelContext: ModelContext

    /// 문제들의 묻는 대상을 모아 온다. **기다리지 않고 즉시** 돌려준다.
    ///
    /// 캐시에 유효한 값이 있으면 그것을, 없으면 규칙 기반으로 그 자리에서 계산합니다.
    /// 둘 다 실패한 문제는 결과에 담기지 않고, 그 문제는 형광펜 없이 표시됩니다.
    func focuses(for questions: [Question]) -> [Int: QuestionFocus] {
        let cached = Self.usesModelAnalysis ? cachedRecords() : [:]

        var result: [Int: QuestionFocus] = [:]
        for question in questions {
            if let record = cached[question.id],
               record.textHash == QuestionFocusRecord.hash(of: question.question) {
                result[question.id] = record.focus              // 2) 캐시
            } else if let rule = QuestionFocusExtractor.focus(in: question.question) {
                result[question.id] = rule                      // 3) 규칙 기반
            }
        }
        return result
    }

    /// 아직 분석하지 않은 문제를 백그라운드에서 모델로 분석해 캐시에 저장한다.
    ///
    /// 화면을 막지 않으며, 실패하면 규칙 기반 결과가 계속 쓰입니다.
    ///
    /// - Parameters:
    ///   - questions: 검사할 문제들
    ///   - limit: 한 번에 분석할 최대 개수. 한꺼번에 1000개를 돌리면 기기가 뜨거워진다
    func analyzeMissing(in questions: [Question], limit: Int = 5) async {
        guard Self.usesModelAnalysis, FocusAnalyzer.isAvailable else { return }

        let cached = cachedRecords()

        // 캐시가 없거나, 질문 문구가 바뀌어 해시가 어긋난 것만 대상이다.
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

    // MARK: - 캐시 다루기

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
