//
//  RootView.swift
//  KCT
//
//  역할 : 앱이 처음 보여줄 화면을 정한다
//  요점 : 하단 탭바로 "나의 이력"(왼쪽)·"문제 풀기"(오른쪽) 두 화면을 오간다.
//        처음 열면 "나의 이력" 이 보인다
//
//  ── 구성 ──────────────────────────────────────────────
//  RootView
//  ├─ MainTab            탭 두 개의 이름표 (history · quiz)
//  ├─ selectedTab         지금 보이는 탭. 시작 값은 .history
//  └─ body     TabView — 나의 이력(MyHistoryView) / 문제 풀기(PracticeHomeView)
//
//  ── 흐름 ──────────────────────────────────────────────
//  KCTApp → RootView
//    ├─ "나의 이력" 탭(왼쪽, 기본값) → MyHistoryView → "스토리 모드 시작하기" → StoryModeView
//    │     (스토리 모드로 들어가면 하단 탭바가 숨고, 뒤로가기로 나오면 다시 보인다)
//    └─ "문제 풀기" 탭(오른쪽) → PracticeHomeView → "종합 연습" → QuizView
//          (문제 풀기로 들어가면 하단 탭바가 숨고, 왼쪽 위 X 로 나오면 다시 보인다)
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KCTApp
//  기대는 것    : MyHistoryView, PracticeHomeView
//  건드리지 않는 것 : 회차 진행 전부 — 이 파일은 "어느 탭을 보여줄지" 만 정한다
//
//  11차(스토리 모드 진입) — 예전에는 앱을 열면 곧바로 QuizView 하나만 떴다.
//  스토리 모드를 넣으려면 "지금 풀고 있는 문제"와 "내 기록·스토리 모드 입구"를
//  오갈 자리가 필요해서 하단 탭바를 추가했다. 처음에는 기본 탭을 "문제 풀기"로
//  두어 예전 흐름을 그대로 지켰었다.
//
//  11차 후속 — 탭 순서를 "나의 이력(왼쪽) · 문제 풀기(오른쪽)"으로 바꿨다. 그리고
//  두 탭 다 이제 "메뉴 화면 → 실제 화면" 2단 구조가 됐다 — 각 메뉴 화면
//  (MyHistoryView·PracticeHomeView)에서 다음 화면(StoryModeView·QuizView)으로
//  들어가면 하단 탭바가 숨어 "지금은 이 흐름에 집중하는 중"임을 보여주고, 나오면
//  다시 나타난다. 탭바를 숨기고 보이는 것은 각 목적지 화면(StoryModeView·QuizView)이
//  스스로 `.toolbar(.hidden, for: .tabBar)` 로 정하며, 이 파일은 손대지 않는다.
//
//  11차 후속 2 — 기본 탭을 "문제 풀기"(.quiz)에서 "나의 이력"(.history)으로
//  바꿨다. 이제 앱을 열면 곧바로 문제가 아니라 나의 이력(누적 통계 + 스토리
//  모드 입구)이 먼저 보인다.
//

import SwiftUI
import SwiftData

/// 앱의 첫 화면.
///
/// 기본 탭을 "나의 이력" 으로 두어, 앱을 열면 곧바로 ``MyHistoryView`` 가 보이게
/// 합니다. "문제 풀기" 탭은 ``PracticeHomeView`` 를 거쳐 실제 문제 풀이로 들어가는
/// 입구입니다.
struct RootView: View {
    /// 탭 두 개의 이름표.
    enum MainTab: Hashable {
        case quiz
        case history
    }

    /// 지금 보이는 탭. 앱을 열면 항상 "나의 이력" 부터 보인다.
    @State private var selectedTab: MainTab = .history

    var body: some View {
        TabView(selection: $selectedTab) {
            MyHistoryView()
                .tabItem { Label("나의 이력", systemImage: "chart.bar.fill") }
                .tag(MainTab.history)

            PracticeHomeView()
                .tabItem { Label("문제 풀기", systemImage: "pencil.and.outline") }
                .tag(MainTab.quiz)
        }
        .tint(AppColor.signature)
    }
}

#Preview {
    RootView()
        .environment(QuestionCatalog.loaded())
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self], inMemory: true)
}
