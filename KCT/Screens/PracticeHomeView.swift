//
//  PracticeHomeView.swift
//  KCT
//
//  역할 : "문제 풀기" 탭의 첫 화면. 어떤 방식으로 풀지 고르는 메뉴
//  요점 : 지금은 "종합 연습" 하나뿐이다. 실전 모드 등은 여기에 버튼만 더하면 된다
//
//  ── 구성 ──────────────────────────────────────────────
//  PracticeHomeView
//  └─ body     제목 + "종합 연습" 버튼. 누르면 QuizView 로 들어간다
//
//  ── 흐름 ──────────────────────────────────────────────
//  RootView의 "문제 풀기" 탭이 이 화면을 띄운다
//    → "종합 연습" 탭 → QuizView(sessionMode: .practice) 로 push
//        (QuizView 쪽에서 하단 탭바를 숨기고 왼쪽 위에 X 를 단다)
//    → X 를 누르면 QuizView 가 스스로 dismiss() 해 이 화면으로 되돌아온다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : RootView
//  기대는 것    : QuizView, AppColor
//  건드리지 않는 것 : 회차 진행 전부 — 이 화면은 "어디로 들어갈지" 만 고른다
//
//  11차(문제 풀기 탭 분리) — 예전에는 "문제 풀기" 탭을 누르면 QuizView 가 곧바로
//  떠서 문제가 시작됐다. 지금은 그 앞에 이 메뉴 화면을 하나 두었다 — 나중에
//  "종합 연습" 말고 다른 방식(스토리 모드에서 배운 것만 복습 등)이 늘어날 자리를
//  미리 만들어 둔 것이다. "종합 연습"이라는 이름은 지금 유일한 방식이 "전체
//  문제집에서 골고루 낸다"(SessionBuilder가 항상 해 온 일)는 뜻에서 붙였다.
//

import SwiftUI
import SwiftData

/// "문제 풀기" 탭의 메뉴 화면.
///
/// 지금은 선택지가 "종합 연습" 하나뿐이라 화면이 단출하지만, 어머니가 매번 앱을
/// 열자마자 문제를 만나던 흐름이 완전히 사라지지 않도록 버튼을 하나만, 크게 둡니다.
struct PracticeHomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ScreenTitle("문제 풀기")

                Spacer()

                practiceEntry

                Spacer()
            }
            .padding(24)
            .background(Color.white)
        }
    }

    /// 「나의 이력」 탭의 진입 버튼(``MyHistoryView``)과 **같은 모습**이다 —
    /// 두 탭의 입구가 같은 무게로 보여야 어느 쪽도 더 중요해 보이지 않는다.
    private var practiceEntry: some View {
        NavigationLink {
            QuizView()
        } label: {
            ActionCapsuleLabel(title: "종합 연습", minHeight: 60)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PracticeHomeView()
        .environment(QuestionCatalog.loaded())
        .environment(MatchingSetCatalog.loaded())
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self], inMemory: true)
}
