//
//  QuestionFocus.swift
//  KCT
//
//  질문이 "무엇을 묻고 있는지" 찾아낸다.
//  한국어 의문사는 닫힌 집합(누구·어디·언제·무엇·몇…)이라 규칙만으로 대부분 잡힌다.
//
//  나중에 서버가 분석값을 내려주거나 온디바이스 모델이 보강할 수 있도록,
//  결과 타입(`QuestionFocus`)과 추출기(`QuestionFocusExtractor`)를 분리해 둔다.
//

import Foundation

/// 질문이 묻는 대상.
struct QuestionFocus: Hashable {
    /// 지문에서 강조할 부분. (반드시 지문에 그대로 존재하는 문자열)
    let phrase: String
    /// 묻는 대상의 종류. (예: "사람", "나라") 판단하지 못하면 nil.
    let category: String?
}

enum QuestionFocusExtractor {
    /// 한국어 의문사 (닫힌 집합)
    private static let interrogatives = ["누구", "어디", "언제", "무엇", "무슨", "어느", "몇"]

    /// 의문사 앞 명사로 종류를 판단한다. 구체적인 것을 먼저 두어 우선 매칭시킨다.
    /// (예: "나라의 이름은" → 일반적인 "이름"보다 "나라"를 고른다)
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

    /// 질문에서 묻는 대상을 찾는다.
    static func focus(in question: String) -> QuestionFocus? {
        if let found = focusUsingInterrogative(in: question) { return found }
        return focusUsingImperative(in: question)
    }

    // MARK: - 의문사가 있는 경우 ("…왕(시조)는 누구입니까?")

    private static func focusUsingInterrogative(in question: String) -> QuestionFocus? {
        // 가장 먼저 나타나는 의문사를 찾는다.
        let found = interrogatives
            .compactMap { word -> (word: String, range: Range<String.Index>)? in
                question.range(of: word).map { (word, $0) }
            }
            .min { $0.range.lowerBound < $1.range.lowerBound }

        guard let found else { return nil }

        let before = String(question[question.startIndex..<found.range.lowerBound])
        let words = before.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        // 종류는 의문사 앞 두 단어 안에서 찾는다.
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

    /// 주어진 구간에서 묻는 대상의 종류를 찾는다.
    private static func category(in text: String) -> String? {
        categoryByNoun.first { text.contains($0.noun) }?.category
    }
}

// MARK: - 조사 붙이기

extension String {
    /// 받침 여부에 따라 "을"/"를"을 붙인다. (예: 사람 → 사람을, 나라 → 나라를)
    var withObjectParticle: String {
        guard let last = unicodeScalars.last else { return self }
        let isHangulSyllable = (0xAC00...0xD7A3).contains(last.value)
        guard isHangulSyllable else { return self + "을" }

        let hasFinalConsonant = (last.value - 0xAC00) % 28 != 0
        return self + (hasFinalConsonant ? "을" : "를")
    }
}
