//
//  GlossaryCatalog.swift
//  KCT
//
//  Created by harryho on 9/9/26.
//

/// 앱이 쓰는 낱말 사전.
///
/// 문제집과 **따로** 둡니다. 낱말은 여러 문항에 되풀이되므로 문항에 붙이면
/// 같은 뜻이 여러 벌 생기고, 고칠 때 여러 군데를 고쳐야 합니다.

import Foundation
import Observation

@Observable
final class GlossaryCatalog {
    
    private(set) var version: Int
    private(set) var words: [Glossary]
    
    init(payload: GlossaryPayload) {
        self.version = payload.version
        self.words = payload.words
    }
 
    /// 사전을 읽어 온다. 없으면 빈 사전.
    ///
    /// 사전이 비어도 앱은 그대로 돕니다 — 질문 아래 풀이가 안 붙을 뿐입니다.
    /// 그래서 문제집과 달리 `assertionFailure` 를 두지 않습니다.
    static func loaded() -> GlossaryCatalog {
        let payload = ContentFile<GlossaryPayload>(fileName: "glossary").load()
        return GlossaryCatalog(payload: payload ?? GlossaryPayload(version: 0, words: []))
    }
    
    // ❓아래 gloss, words 두개는 언제 사용되는 함수인가? 
    /// 낱말 하나의 뜻.
    func gloss(_ word: String) -> Glossary? {
        words.first { $0.word == word }
    }
    
    /// 문장 안에 들어 있는 낱말들. 질문 아래에 풀이를 붙일 때 씁니다.
    ///
    /// 긴 낱말이 먼저 오게 정렬합니다 — 「건국이념」이 있는데 「이념」만 잡히면 안 됩니다.
    func words(in sentence: String) -> [Glossary] {
        words
            .filter { sentence.contains($0.word) }
            .sorted { $0.word.count > $1.word.count }
    }
}
