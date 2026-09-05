//
//  KCTApp.swift
//  KCT
//
//  역할 : 앱의 시작점. 문제집을 준비하고 저장소를 연결한 뒤 첫 화면을 띄운다
//  요점 : 앱 전체가 같은 문제집·같은 저장소를 보게 만드는 곳
//
//  ── 구성 ──────────────────────────────────────────────
//  KCTApp (@main)
//  ├─ catalog              앱이 쓸 문제집. 번들 JSON 에서 읽는다
//  ├─ WindowGroup          RootView 를 담는 창
//  ├─ .environment(catalog)      아래 모든 화면이 문제집을 꺼내 쓸 수 있게
//  └─ .modelContainer(for:)      SwiftData 저장소 — 진척 · 하이라이트 캐시 · 관찰 기록
//
//  ── 흐름 ──────────────────────────────────────────────
//  앱 실행
//    → QuestionCatalog.bundled() : questions.json 을 읽어 문제집 준비
//    → modelContainer : QuestionProgress·QuestionFocusRecord·ObsRecord 를 저장할 곳 마련
//    → RootView → QuizView 가 environment 에서 둘을 꺼내 회차를 시작
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : 시스템 (@main)
//  기대는 것    : QuestionCatalog(문제집), QuestionProgress·QuestionFocusRecord(저장 타입), RootView
//  건드리지 않는 것 : 출제·채점·화면 — 준비만 하고 판단은 아래에 맡긴다
//

import SwiftUI
import SwiftData

/// 앱의 시작점.
///
/// 하는 일은 준비 두 가지뿐입니다 — 문제집을 읽어 두고, 저장소를 연결합니다. 그 뒤의 판단은 아래 화면들과 ``QuizSession`` 이 합니다.
///
/// - Note: 타입 이름이 `KCTApp` 인 것은 모듈 이름(`KCT`)과 겹쳐 모호해지지 않게 하기 위해서입니다.
@main
struct KCTApp: App {

    /// 앱이 사용할 문제집.
    ///
    /// 지금은 번들 JSON 에서 읽습니다. 서버 문제집으로 바꿀 때는 ``QuestionCatalog/replace(with:)`` 를 안전한 시점에 부르면 됩니다.
    @State private var catalog = QuestionCatalog.bundled()

    var body: some Scene {
        WindowGroup {
            RootView()
                // 문제집을 환경에 실어 두면 화면마다 손으로 넘기지 않아도 된다.
                .environment(catalog)
        }
        // 디스크에 남길 타입들. 이 목록에 없으면 저장되지 않는다.
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self, ObsRecord.self])
    }
}
