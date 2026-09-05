//
//  QuestionFocusRecord.swift
//  KCT
//
//  역할 : 모델이 분석한 "묻는 대상" 을 저장해 두는 캐시. 하이라이트 2층의 저장소
//  요점 : 질문 문구가 수정되면 해시가 어긋나 캐시가 저절로 무효화된다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuestionFocusRecord (@Model)
//  ├─ questionID       어느 문제인지. 문제당 하나(.unique)
//  ├─ textHash         분석 당시 질문 텍스트의 SHA256 — 캐시 무효화 판단용
//  ├─ phrase           강조할 부분
//  ├─ category         묻는 대상의 종류
//  ├─ analyzedAt       분석한 시각
//  ├─ focus            QuestionFocus 로 꺼내 쓰기
//  └─ hash(of:)        저장해도 안전한 해시 만들기
//
//  ── 흐름 ──────────────────────────────────────────────
//  FocusAnalyzer 가 분석에 성공하면
//    → FocusStore.save() 가 이 객체를 만들거나 갱신한다 (textHash 함께 기록)
//  다음 회차에 FocusStore.focuses()
//    → 저장된 textHash 와 현재 질문의 해시를 비교
//    → 같으면 캐시 채택 / 다르면 문구가 바뀐 것이므로 버리고 다시 분석 대상에 올림
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : FocusStore (읽기·쓰기) — 단 지금은 스위치가 꺼져 쓰이지 않는다
//  기대는 것    : QuestionFocus, CryptoKit, SwiftData
//  건드리지 않는 것 : 분석 자체 — 모델을 부르는 것은 FocusAnalyzer 의 몫
//

import Foundation
import CryptoKit
import SwiftData

/// 모델이 분석한 "묻는 대상" 을 저장해 두는 캐시.
///
/// 질문 텍스트의 해시를 함께 저장해, 문구를 한 글자만 고쳐도 낡은 분석 결과가 저절로 무효화됩니다.
///
/// - Important: ``FocusStore/usesModelAnalysis`` 가 `false` 라 지금 이 캐시는 채워지지 않습니다.
@Model
final class QuestionFocusRecord {

    /// 대응하는 문제의 고유 번호. 문제당 하나만 존재한다.
    @Attribute(.unique) var questionID: Int

    /// 분석 당시 질문 텍스트의 해시. 문구가 수정되면 캐시를 무효화하는 데 쓴다.
    var textHash: String

    /// 강조할 부분.
    var phrase: String

    /// 묻는 대상의 종류.
    var category: String?

    /// 분석한 시각.
    var analyzedAt: Date

    init(questionID: Int, textHash: String, phrase: String, category: String?) {
        self.questionID = questionID
        self.textHash = textHash
        self.phrase = phrase
        self.category = category
        self.analyzedAt = .now
    }

    /// 저장된 값을 ``QuestionFocus`` 로 꺼낸다.
    var focus: QuestionFocus {
        QuestionFocus(phrase: phrase, category: category)
    }

    /// 질문 텍스트의 **안정적인** 해시.
    ///
    /// Swift 의 `hashValue` 는 실행할 때마다 값이 달라져 저장용으로 쓸 수 없으므로 SHA256을 씁니다.
    static func hash(of text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
