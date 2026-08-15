//
//  QuestionFocusRecord.swift
//  KCT
//
//  온디바이스 모델이 분석한 "질문이 묻는 대상"을 저장해 두는 캐시.
//  같은 질문을 매번 다시 분석하지 않도록 한 번만 계산하고 재사용한다.
//

import Foundation
import CryptoKit
import SwiftData

@Model
final class QuestionFocusRecord {
    /// 대응하는 문제의 고유 번호. (문제당 하나)
    @Attribute(.unique) var questionID: Int
    /// 분석 당시 질문 텍스트의 해시. 문구가 수정되면 캐시를 무효화하는 데 쓴다.
    var textHash: String
    /// 강조할 부분
    var phrase: String
    /// 묻는 대상의 종류
    var category: String?
    var analyzedAt: Date

    init(questionID: Int, textHash: String, phrase: String, category: String?) {
        self.questionID = questionID
        self.textHash = textHash
        self.phrase = phrase
        self.category = category
        self.analyzedAt = .now
    }

    var focus: QuestionFocus {
        QuestionFocus(phrase: phrase, category: category)
    }

    /// 질문 텍스트의 안정적인 해시.
    ///
    /// Swift의 `hashValue`는 실행할 때마다 값이 달라져 저장용으로 쓸 수 없다.
    /// 앱을 껐다 켜도 같은 값이 나오도록 SHA256을 쓴다.
    static func hash(of text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
