//
//  RootView.swift
//  KCT
//
//  역할 : 앱이 처음 보여줄 화면을 정한다
//  요점 : 지금은 곧바로 퀴즈로 간다. 나중에 홈·모드 선택이 들어올 자리
//
//  ── 구성 ──────────────────────────────────────────────
//  RootView
//  └─ body     QuizView 를 그대로 띄운다 (연습 모드가 기본값)
//
//  ── 흐름 ──────────────────────────────────────────────
//  KCTApp → RootView → QuizView(sessionMode: .practice)
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KCTApp
//  기대는 것    : QuizView
//  건드리지 않는 것 : 회차 진행 전부 — 이 파일은 "어디로 갈지" 만 정한다
//

import SwiftUI
import SwiftData

/// 앱의 첫 화면.
///
/// 어르신이 앱을 열면 아무것도 고르지 않고 곧바로 문제를 만나야 하므로, 홈이나 모드 선택 없이 바로 ``QuizView`` 로 갑니다.
///
/// - Note: 실전 모드(``SessionMode/exam``) 입구가 필요해지면 여기에 붙습니다.
struct RootView: View {
    var body: some View {
        QuizView()
    }
}

#Preview {
    RootView()
        .environment(QuestionCatalog.bundled())
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self], inMemory: true)
}
