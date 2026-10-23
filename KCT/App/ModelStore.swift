//
//  ModelStore.swift
//  KCT
//
//  역할 : SwiftData 저장소를 하나로 만든다 — 앱도 미리보기도 같은 「모델 목록」을 쓴다
//  요점 : 저장 모양에 **버전 번호(V1)** 를 붙여, 다음에 칸을 바꿀 때 어머니 기록을 옮길 길을 깔아 둔다
//
//  ── 구성 ──────────────────────────────────────────────
//  KCTSchemaV1 (VersionedSchema)   지금 저장 모양 그대로 — 모델 4개
//  KCTMigrationPlan                버전 사이를 잇는 계획. 지금은 V1 하나뿐이라 단계가 없다
//  ModelStore
//  ├─ shared       앱이 쓰는 디스크 저장소 (KCTApp)
//  └─ preview      미리보기용 메모리 저장소 — **앱과 같은 모델 4개**
//
//  ── 왜 지금 깔았나 (2차 리팩토링, 2026-10-23) ─────────────
//  예전에는 `.modelContainer(for: [모델들])` 로 버전 없이 열었다. 그러면 모델에 칸을 하나
//  더하거나 안 쓰는 모델(QuestionFocusRecord)을 지우는 순간, 기존 저장소를 어떻게 옮길지
//  말할 자리가 없다. 저장 모양은 **한 칸도 바꾸지 않고** 지금 모양을 V1 으로 얼려 두기만 했다.
//  다음에 모양을 바꿀 때: KCTSchemaV2 를 만들고 → schemas 에 넣고 → stages 에 V1→V2 단계를 넣는다.
//
//  미리보기 4곳이 모델 2개만 열던 것도 여기서 고쳤다 — 관찰 기록을 건드리는 길을 타면 미리보기가 죽었다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KCTApp(shared) · RootView · QuizView · MyHistoryView · PracticeHomeView 의 #Preview(preview)
//  기대는 것    : QuestionProgress · QuestionFocusRecord · ObsRecord · ModelFailure
//  건드리지 않는 것 : 무엇을 저장할지 — 각 모델 파일의 몫
//
//  참고: https://developer.apple.com/documentation/swiftdata/versionedschema
//        https://developer.apple.com/documentation/swiftdata/schemamigrationplan
//

import SwiftData

/// 저장 모양 1판. **2026-10-23 의 모양 그대로**이며, 이 목록은 앞으로 바꾸지 않는다 — 바꿀 일은 V2 를 만든다.
enum KCTSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [QuestionProgress.self, QuestionFocusRecord.self, ObsRecord.self, ModelFailure.self]
    }
}

/// 버전 사이를 잇는 계획. V1 하나라 아직 단계가 없다.
enum KCTMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [KCTSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

/// 앱 전체가 같은 저장소를 보게 하는 곳.
enum ModelStore {

    /// 앱이 쓰는 디스크 저장소.
    ///
    /// - Important: 여는 데 실패하면 앱을 멈춘다. 예전 `.modelContainer(for:)` 도 실패하면 같은 결과였다 —
    ///   기록 없이 조용히 돌면 어머니가 푼 것이 사라지는데 아무도 모른다. 멈추는 편이 바로 보인다.
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: KCTSchemaV1.self),
                migrationPlan: KCTMigrationPlan.self)
        } catch {
            fatalError("저장소를 열지 못했습니다: \(error)")
        }
    }()

    /// 미리보기용 저장소. 메모리에만 있고, 앱과 같은 모델 4개를 연다.
    static var preview: ModelContainer {
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: KCTSchemaV1.self),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("미리보기 저장소를 열지 못했습니다: \(error)")
        }
    }
}
