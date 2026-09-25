//
//  AnswerMatcher.swift
//  KCT
//
//  역할 : 코드로 가릴 수 있는 답을 먼저 판정한다. 애매한 것만 모델로 넘긴다
//  요점 : 글자를 세는 일은 코드가 한다. 모델은 한 글자 차이를 못 본다
//
//  ── 구성 ──────────────────────────────────────────────
//  AnswerMatcher
//  ├─ Outcome            correct · wrong · needsModel
//  ├─ check(_:against:shape:from:)   판정 입구
//  │                     말로 한 답(.voice)은 셋이 다르다 — ① 한 글자 차이를 오타로
//  │                     끊지 않는다 ② 정답이 말 속에 통째로 있으면 맞다(containsAnswer)
//  │                     ③ 목록이 안 맞아도 오답으로 끊지 않고 모델에게 넘긴다
//  ├─ candidates(_:)     "/" 로 나눈 표기들 — 아무거나 맞다
//  ├─ items(_:)          목록을 집합으로 — 순서를 안 따진다
//  ├─ tidy(_:)           글자와 숫자만 남긴다
//  ├─ matchesConcatenated(_:expected:)   구분 기호 없이 붙여 쓴 답 확인
//  └─ sounds(_:)         발음 맞추기 (음성 입력에서 채운다)
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.judge() 의 ②층
//  기대는 것    : AnswerShape · AnswerSource · MatchBasis
//  건드리지 않는 것 : 뜻 판정 - 그것은 AnswerChecker 가 모델에게 맡긴다
//

import Foundation

/// 코드로 판정할 수 있는 것을 먼저 가려낸다. 애매한 것만 모델로 넘긴다.
///
/// 대부분의 정답은 여기서 끝납니다. 그래서 직접입력의 기다림이 줄고,
/// 모델을 부르는 횟수가 줄어 **안전 필터에 걸릴 기회도 그만큼 줄어듭니다.**

struct AnswerMatcher {
    
    /// 판정 결과. `needsModel` 이면 확실하지 않아 모델에게 넘긴다.
    enum Outcome {
        case correct(MatchBasis)
        case wrong(MatchBasis)
        case needsModel
    }
    
    /// - Parameter shape: 답의 모양. **글자를 보고 짐작하지 않고 문항이 밝힌 것을 쓴다.**
    ///   주제(``AnswerKind``)는 채점이 쓰지 않으므로 받지 않는다.
    static func check(
        _ answer: String,
        against correctAnswer: String,
        shape: AnswerShape,
        from source: AnswerSource
    ) -> Outcome {
        switch shape {
        case .sentence:
            // 뜻이 같은지는 코드로 못 본다. 모델이 볼 일이다.
            return .needsModel

        case .closedList:
            // 다 대야 한다. 집합이라 순서는 저절로 무시된다.
            let expected = items(correctAnswer)
            if items(answer) == expected { return .correct(.exactMatch) }
            // 공백 없이 붙여 썼을 수도 있다 — 항목들을 이어 붙여도 답과 같아지는지 본다.
            // 말로 한 목록은 「신라요」처럼 끝에 말이 붙어 항목이 안 맞을 수 있다 — 모델에게 넘긴다.
            return matchesConcatenated(answer, expected: expected)
                ? .correct(.exactMatch)
                : (source == .voice ? .needsModel : .wrong(.listMismatch))

        case .openList:
            // "등" 으로 끝나는 목록. 보기 중 셋 이상만 대면 된다.
            let expected = items(correctAnswer)
            if items(answer).intersection(expected).count >= 3 { return .correct(.exactMatch) }
            return matchesConcatenated(answer, expected: expected)
                ? .correct(.exactMatch)
                : (source == .voice ? .needsModel : .wrong(.listMismatch))
            
        case .word:
            break
        }

        let given = tidy(answer)

        if candidates(correctAnswer).contains(given) { return .correct(.exactMatch) }

        // 길이가 같은데 한 글자만 다르면 오타다. 모델은 「고죠선」을 여섯 번 통과시켰다.
        // 말로 한 답의 한 글자 차이는 오타가 아니라 인식기가 잘못 적은 것일 수 있다
        // (AnswerSource 참고) — 그래서 오답으로 끊지 않고 아래로 흘려보낸다.
        if source == .typed {
            for expected in candidates(correctAnswer) where expected.count == given.count {
                if zip(given, expected).filter({ $0 != $1 }).count == 1 { return .wrong(.typo) }
            }
        }

        // 말로 하면 「이순신 장군이요」처럼 정답 앞뒤에 말이 붙는다. 정답(두 글자 이상)이
        // 말 속에 통째로 들어 있으면 맞다. 한 글자 정답은 우연히 걸리기 쉬워 모델에게 둔다.
        if source == .voice,
           candidates(correctAnswer).contains(where: { $0.count >= 2 && given.contains($0) }) {
            return .correct(.containsAnswer)
        }

        if source == .voice,
           candidates(correctAnswer).contains(where: { sounds($0) == sounds(given) }) {
            return .correct(.phoneticMatch)
        }

        return .needsModel
    }
    
    
    /// 정답으로 인정할 표기들. `/` 로 나눈 것은 **아무거나 맞다**.
    ///
    /// 「삼일절/3.1절」은 둘 중 하나만 적어도 정답입니다. `,` 와 뜻이 다릅니다 —
    /// 쉼표는 **다 대야** 정답인 목록이고, 그쪽은 애초에 여기까지 오지 않습니다.
    ///
    /// - Note: `/` 가 없으면 후보가 하나라 그냥 글자 비교와 같습니다.
    ///   **특별한 경우를 만들지 않으려고** 이 모양으로 둡니다.
    private static func candidates(_ correctAnswer: String) -> Set<String> {
        Set(correctAnswer.split(separator: "/").map { tidy(String($0)) }.filter { !$0.isEmpty })
    }
    
    /// 목록을 항목의 집합으로 만든다. 쉼표·빗금·공백으로 쪼갠다.
    ///
    /// 집합이라 **순서를 안 따집니다.** 「등」은 항목이 아니라 빼냅니다.
    ///
    /// - Note: 공백으로도 쪼개는 이유 — 어머니가 「신라 백제 고구려」처럼 쉼표 없이
    ///   적으실 수 있습니다. 대신 정답 쪽의 「한산도 대첩」도 두 조각이 됩니다.
    private static func items(_ text: String) -> Set<String> {
        Set(text.split { $0 == "," || $0 == "/" || $0.isWhitespace }
                .map { tidy(String($0)) }
                .filter { !$0.isEmpty && $0 != "등" })
    }

    /// 비교용으로 다듬는다. **글자와 숫자만 남긴다.**
    ///
    /// 빼는 쪽이 아니라 남기는 쪽으로 씁니다 — 뺄 것은 목록을 다 셀 수 없지만
    /// 남길 것은 둘뿐입니다. `isLetter` 는 한글·한자를 포함합니다(유니코드 `Lo`).
    ///
    /// - Note: `isPunctuation` 만 빼면 `~` `>` `+` 가 살아남습니다. 유니코드는 이것들을
    ///   문장부호가 아니라 **기호**로 봅니다. 문제집 정답 1,155개에 19군데 있습니다.
    private static func tidy(_ text: String) -> String {
        String(text.filter { $0.isLetter || $0.isNumber })
    }
    
    /// 구분 기호 없이 이어 쓴 답이 정답 항목을 다 담고 있는지 본다.
    ///
    /// 「고구려백제신라」처럼 공백도 쉼표도 없이 붙여 쓰면 ``items(_:)`` 는
    /// 이걸 통째로 한 항목으로 봅니다. 여기서는 정답 항목들을 어떤 순서로
    /// 이어 붙였을 때 답과 완전히 같아지는지를 대신 확인합니다.
    private static func matchesConcatenated(_ answer: String, expected: Set<String>) -> Bool {
        let given = tidy(answer)
        guard !given.isEmpty, !expected.isEmpty else { return false }
        return permutations(Array(expected)).contains { $0.joined() == given }
    }

    /// 작은 목록의 모든 순서(순열)를 만든다. `matchesConcatenated` 전용.
    ///
    /// 순열이란 몇 개 안 되는 항목을 늘어놓을 수 있는 **모든 순서**입니다.
    /// "고구려·백제·신라" 세 개면 순서는 6가지(3×2×1)뿐이라 다 만들어 봐도 느리지 않습니다.
    private static func permutations(_ items: [String]) -> [[String]] {
        guard items.count > 1 else { return [items] }
        return items.indices.flatMap { i -> [[String]] in
            var rest = items
            let item = rest.remove(at: i)
            return permutations(rest).map { [item] + $0 }
        }
    }

    /// 발음이 같은 글자를 한 모양으로 모은다.
    ///
    /// - Note: **아직 비어 있습니다.** 음성 입력을 붙일 때 채웁니다.
    ///   그때까지 ``AnswerSource/voice`` 가 들어올 일이 없어 이 자리는 안 쓰입니다.
    private static func sounds(_ text: String) -> String {
        text
    }
}
