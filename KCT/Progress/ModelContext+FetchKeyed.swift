//
//  ModelContext+FetchKeyed.swift
//  KCT
//
//  역할 : SwiftData 저장소에서 한 타입을 통째로 읽어 **id 로 찾을 수 있게** 만든다
//  요점 : 「읽어서 Dictionary 로 바꾸기」가 세 곳에서 되풀이됐다. 한 줄로 줄인다
//
//  ── 구성 ──────────────────────────────────────────────
//  ModelContext.fetchKeyed(by:)   키패스로 키를 골라 [키: 객체] 표를 만든다
//
//  ── 왜 첫 것을 남기나 ──────────────────────────────────
//  `uniquingKeysWith: { first, _ in first }` — 같은 키가 둘 있으면 **먼저 읽은 것**을
//  남긴다. QuestionProgress 는 `@Attribute(.unique)` 라 원래 겹칠 수 없지만, 겹쳤을 때
//  조용히 뒤엣것으로 덮어쓰면 **어느 쪽이 살아남았는지 알 수 없게** 된다. 늘 같은 쪽을
//  남기면 적어도 결과가 일관된다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.fetchProgressByID(), FocusStore.cachedRecords()
//  기대는 것    : SwiftData 뿐
//  건드리지 않는 것 : 무엇을 읽을지·읽은 뒤 무엇을 할지 — 부르는 쪽이 정한다.
//                    조건을 걸어 일부만 읽는 일도 여기서 안 한다(그때는 부르는 쪽이
//                    FetchDescriptor 를 직접 쓴다 — ObsUploader 가 그렇게 한다)
//

import Foundation
import SwiftData

extension ModelContext {

    /// 저장된 것을 모두 읽어 **키로 찾을 수 있는 표**로 돌려준다.
    ///
    /// 읽기에 실패하면 **빈 표**입니다 — 던지지 않습니다. 진척을 못 읽었을 때 앱이
    /// 죽는 것보다, 「아직 아무것도 안 풀었다」로 보고 새로 만드는 편이 낫습니다
    /// (``QuizSession/start()`` 가 없는 진척을 만들어 채웁니다).
    ///
    /// - Parameter key: 무엇을 키로 쓸지 (예: `\QuestionProgress.questionID`).
    func fetchKeyed<Model: PersistentModel, Key: Hashable>(
        by key: KeyPath<Model, Key>
    ) -> [Key: Model] {
        let rows = (try? fetch(FetchDescriptor<Model>())) ?? []
        return Dictionary(rows.map { ($0[keyPath: key], $0) },
                          uniquingKeysWith: { first, _ in first })
    }
}
