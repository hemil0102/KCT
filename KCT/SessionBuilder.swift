//
//  SessionBuilder.swift
//  KCT
//
//  이번 세션에 출제할 문제와 모드를 자동으로 정한다. (어머니가 선택을 거의 안 해도 됨)
//  - 복습 반복: 미마스터 문제를 nextDueAt(이른 순)으로 다시 출제
//  - 신규 점진 도입: 새 문제를 difficulty(쉬운 순) + 단원 라운드로빈으로 조금씩
//  - 마스터 복습: 직접입력까지 맞힌 문제도 매 세션 한 칸 정도 랜덤으로 계속 등장
//  - 라운드 셰이핑: 첫/마지막 슬롯은 격려용 2지선다(진척 무영향)
//

import Foundation

struct SessionBuilder {
    /// 출제할 문제집.
    let catalog: QuestionCatalog

    /// 스토리 모드 게이트 seam. 프로토타입에서는 항상 개방(true).
    /// 향후 스토리 모드가 "읽은 콘텐츠"만 true로 바꾼다.
    var isUnlocked: (Question) -> Bool = { _ in true }

    /// 매 세션에 마스터 문제를 복습으로 끼워 넣을 최대 칸 수.
    private let masteredReviewSlots = 1

    /// 이번 세션의 출제 항목을 만든다.
    /// - Parameters:
    ///   - size: 출제할 문제 수
    ///   - progressByID: 문제 id → 진척
    ///   - now: 기준 시각 (복습 판정용)
    ///   - focusByID: 문제 id → 묻는 대상. 없으면 규칙 기반으로 즉시 계산된다.
    func build(
        size: Int,
        progressByID: [Int: QuestionProgress],
        focusByID: [Int: QuestionFocus] = [:],
        now: Date = .now
    ) -> [PracticeItem] {
        func prog(_ question: Question) -> QuestionProgress? { progressByID[question.id] }

        let unlocked = catalog.questions.filter(isUnlocked)

        // 마스터 문제 (복습용, 랜덤 순서)
        let mastered = unlocked.filter { prog($0)?.isMastered == true }.shuffled()

        // 학습 중(미마스터) 문제
        let unmastered = unlocked.filter { !(prog($0)?.isMastered ?? false) }

        // 복습 대상: 이미 도입된 문제. 다음 출제 예정이 이른 순 → 쉬운 순.
        let review = unmastered
            .filter { prog($0)?.isIntroduced == true }
            .sorted { lhs, rhs in
                let l = prog(lhs)?.nextDueAt ?? .distantPast
                let r = prog(rhs)?.nextDueAt ?? .distantPast
                if l != r { return l < r }
                return (lhs.difficulty, lhs.id) < (rhs.difficulty, rhs.id)
            }

        // 신규 도입: 아직 안 나온 문제. 쉬운 순 + 단원 라운드로빈.
        let newbies = introduceOrder(unmastered.filter { prog($0)?.isIntroduced != true })

        let learning = review + newbies

        // 마스터 복습용 칸을 예약하고, 나머지를 학습 문제로 채운다.
        var chosen: [Question] = []
        let reserve = mastered.isEmpty ? 0 : masteredReviewSlots
        let learningSlots = max(0, size - reserve)

        for question in learning where chosen.count < learningSlots {
            chosen.append(question)
        }
        for question in mastered where chosen.count < size {
            chosen.append(question)
        }
        // 학습/마스터가 모자라면 남은 학습 문제로 마저 채운다.
        for question in learning where chosen.count < size {
            if !chosen.contains(where: { $0.id == question.id }) {
                chosen.append(question)
            }
        }

        // 마스터 문제가 항상 같은 자리(끝)에만 오지 않도록 섞는다.
        chosen.shuffle()

        // 라운드 셰이핑: 첫/마지막 슬롯은 격려용 2지선다(진척에 반영 안 함)
        return chosen.enumerated().map { index, question in
            let isBookend = chosen.count >= 2 && (index == 0 || index == chosen.count - 1)
            let mode = isBookend ? .binaryChoice : (prog(question)?.mode ?? .binaryChoice)
            return PracticeItem.make(
                question,
                mode: mode,
                answerPool: catalog.answerPool,
                affectsProgress: !isBookend,
                focus: focusByID[question.id]
            )
        }
    }

    /// 신규 문제를 쉬운 순으로 두되, 단원을 번갈아(라운드로빈) 도입한다.
    private func introduceOrder(_ questions: [Question]) -> [Question] {
        let sorted = questions.sorted { ($0.difficulty, $0.id) < ($1.difficulty, $1.id) }

        // 단원별 큐로 나눈다. (처음 등장한 단원 순서 유지)
        var byUnit: [String: [Question]] = [:]
        var unitOrder: [String] = []
        for question in sorted {
            if byUnit[question.unit] == nil {
                byUnit[question.unit] = []
                unitOrder.append(question.unit)
            }
            byUnit[question.unit]?.append(question)
        }

        // 단원을 번갈아 하나씩 꺼낸다.
        var result: [Question] = []
        var didAppend = true
        while didAppend {
            didAppend = false
            for unit in unitOrder where !(byUnit[unit]?.isEmpty ?? true) {
                result.append(byUnit[unit]!.removeFirst())
                didAppend = true
            }
        }
        return result
    }
}
