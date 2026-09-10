//
//  Glossary.swift
//  KCT
//
//  역할 : 낱말의 뜻을 들고 있다
//  요점 : 낱말은 여러 문항에 되풀이된다. 뜻은 한 벌만 있으면 된다
//
//  ── 구성 ──────────────────────────────────────────────
//  GlossaryEntry    낱말 하나 (낱말 · 뜻 · 보기)
//  GlossaryPayload  파일의 내용 (버전 + 낱말들)
//  Glossary         앱이 쓰는 사전
//  ├─ loaded()      ContentFile 로 읽는다
//  ├─ gloss(_:)     낱말 하나의 뜻
//  └─ words(in:)    문장 안에 들어 있는 낱말들
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KCTApp(생성) · QuestionScreen(5단계) · KnowledgeTool(7단계)
//  기대는 것    : ContentFile, 번들 안의 glossary.json
//  건드리지 않는 것 : 문제집 — 사전은 문항을 모른다
//

import Foundation

/// 낱말 하나.
struct Glossary: Codable, Hashable {
    let word: String
    let gloss: String

    /// 이 낱말에 속하는 것들. 「국경일」의 삼일절·제헌절처럼.
    var examples: [String] = []
    
    init(word: String, gloss: String, examples: [String] = []) {
        self.word = word
        self.gloss = gloss
        self.examples = examples
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        word     = try box.decode(String.self, forKey: .word)
        gloss    = try box.decode(String.self, forKey: .gloss)
        examples = try box.decodeIfPresent([String].self, forKey: .examples) ?? []
    }
}

/// 사전 파일의 내용.
struct GlossaryPayload: Codable {
    let version: Int
    let words: [Glossary]
}



