//
//  QuestionFocus.swift
//  KCT
//
//  역할 : 질문이 "무엇을 묻고 있는지" 규칙으로 찾아낸다. 하이라이트 3층 중 3층(안전망)
//  요점 : 한국어 의문사는 닫힌 집합이라 규칙만으로 대부분 잡힌다. 모델이 필요 없다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuestionFocus (struct)          찾아낸 결과
//  ├─ phrase                       지문에서 강조할 부분 (지문에 그대로 있어야 한다)
//  └─ category                     묻는 대상의 종류 ("사람", "나라" …). 못 정하면 nil
//
//  QuestionFocusExtractor (enum)   규칙 기반 추출기
//  ├─ interrogatives               의문사 닫힌 집합 (누구·어디·언제·무엇·무슨·어느·몇)
//  ├─ categoryByNoun               의문사 앞 명사 → 종류 (구체적인 것을 앞에 둔다)
//  ├─ categoryByInterrogative      앞 명사로 못 정할 때 의문사 자체로 결정
//  ├─ focus(in:)                   입구 — 의문사 먼저, 없으면 명령형
//  ├─ focusUsingInterrogative(in:) "…왕은 누구입니까?"
//  ├─ focusUsingImperative(in:)    "…이름을 말해 보세요."
//  └─ category(in:)                주어진 구간에서 종류 찾기
//
//  ── 흐름 ──────────────────────────────────────────────
//  FocusStore.focuses(for:) 또는 QuizItem.make() 가
//    → focus(in: 질문문장) 호출
//    → 가장 먼저 나오는 의문사를 찾는다
//    → 그 앞 두 단어에서 "무엇을 묻는지" 종류를 판단한다
//    → 종류가 담긴 단어부터 문장 끝까지를 phrase 로 잡는다
//    → QuizItem.markerText 를 거쳐 KoreanText 가 형광펜으로 칠한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : FocusStore(층 결정), QuizItem.make(캐시 없을 때 즉시 계산)
//  기대는 것    : 없음 — Foundation 뿐. 모델도 저장소도 쓰지 않는다
//  건드리지 않는 것 : 저장·캐시 — 그것은 QuestionFocusRecord 와 FocusStore 의 몫
//

import Foundation

/// 질문이 묻는 대상.
///
/// - Important: ``phrase`` 는 지문에 그대로 존재하는 문자열이어야 합니다. 화면이 이 문자열을 찾아 형광펜을 칠하기 때문입니다.
struct QuestionFocus: Hashable {
    /// 지문에서 강조할 부분.
    let phrase: String

    /// 묻는 대상의 종류 (예: "사람", "나라"). 판단하지 못하면 `nil`.
    let category: String?
}

/// 규칙만으로 "묻는 대상" 을 찾아내는 추출기. **하이라이트의 안전망(3층)** 입니다.
///
/// 한국어 의문사는 닫힌 집합이라 목록으로 두고 찾으면 대부분 잡히고, 모델이 없는 기기에서도 새 문제를 넣은 직후에도 기다림 없이 동작합니다.
/// 결과 타입과 추출기를 나눈 것은 나중에 서버나 모델이 보강해도 만드는 쪽만 갈아끼우면 되게 하기 위해서입니다.
enum QuestionFocusExtractor {

    /// 한국어 의문사 (닫힌 집합)
    private static let interrogatives = ["누구", "어디", "언제", "무엇", "무슨", "어느", "몇"]

    /// 의문사 앞 명사로 종류를 판단한다.
    ///
    /// 배열 순서가 곧 우선순위입니다 — "나라의 이름은 무엇입니까?" 에서 일반적인 "이름" 보다 "나라" 를 골라야 합니다.
    private static let categoryByNoun: [(noun: String, category: String)] = [
        ("왕", "사람"), ("시조", "사람"), ("인물", "사람"), ("사람", "사람"),
        ("도읍지", "장소"), ("수도", "장소"), ("지역", "장소"), ("장소", "장소"),
        ("나라", "나라"), ("국가", "나라"),
        ("신화", "신화"), ("이야기", "신화"),
        ("제도", "제도"), ("법", "법"),
        ("연도", "시기"), ("날짜", "시기"), ("시대", "시기"),
        ("이름", "이름"),
    ]

    /// 앞 명사로 못 정하면 의문사 자체로 종류를 정한다.
    private static let categoryByInterrogative: [String: String] = [
        "누구": "사람",
        "어디": "장소",
        "언제": "시기",
        "몇": "개수",
    ]

    /// 질문에서 묻는 대상을 찾는다. 못 찾으면 `nil`(형광펜 없음).
    static func focus(in question: String) -> QuestionFocus? {
        if let found = focusUsingInterrogative(in: question) { return found }
        return focusUsingImperative(in: question)
    }

    // MARK: - 의문사가 있는 경우 ("…왕(시조)는 누구입니까?")

    private static func focusUsingInterrogative(in question: String) -> QuestionFocus? {
        // 의문사가 여러 개면 가장 먼저 나타나는 것이 묻는 대상이다.
        let found = interrogatives
            .compactMap { word -> (word: String, range: Range<String.Index>)? in
                question.range(of: word).map { (word, $0) }
            }
            .min { $0.range.lowerBound < $1.range.lowerBound }

        guard let found else { return nil }

        let before = String(question[question.startIndex..<found.range.lowerBound])
        let words = before.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        // 종류는 의문사 앞 두 단어 안에서 찾는다. 더 멀리 보면 엉뚱한 명사가 걸린다.
        let context = words.suffix(2)
        let category = category(in: context.joined(separator: " "))

        // 묻는 대상이 담긴 단어부터 문장 끝까지 강조한다.
        // (예: "한국의 최초 국가 이름은 무엇입니까?" → "국가 이름은 무엇입니까?")
        let headWord = context.first { word in
            categoryByNoun.contains { word.contains($0.noun) }
        } ?? words.last

        let phraseStart = headWord
            .flatMap { before.range(of: $0, options: .backwards)?.lowerBound }
            ?? found.range.lowerBound
        let phrase = String(question[phraseStart...]).trimmingCharacters(in: .whitespaces)

        return QuestionFocus(
            phrase: phrase,
            category: category ?? categoryByInterrogative[found.word]
        )
    }

    // MARK: - 의문사 없이 지시하는 경우 ("…이름을 말해 보세요.")

    private static func focusUsingImperative(in question: String) -> QuestionFocus? {
        guard let marker = question.range(of: "말해") else { return nil }

        let before = String(question[question.startIndex..<marker.lowerBound])
        let words = before.split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else { return nil }

        let context = words.suffix(2).joined(separator: " ")
        guard let phraseStart = before.range(of: context, options: .backwards)?.lowerBound else {
            return nil
        }

        let phrase = String(before[phraseStart...]).trimmingCharacters(in: .whitespaces)
        return QuestionFocus(phrase: phrase, category: category(in: context))
    }

    /// 주어진 구간에서 묻는 대상의 종류를 찾는다. 배열 순서가 우선순위다.
    private static func category(in text: String) -> String? {
        categoryByNoun.first { text.contains($0.noun) }?.category
    }
}
