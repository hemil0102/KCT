//
//  SessionProgressBar.swift
//  KCT
//
//  역할 : 회차의 진행 상황을 칸 수만큼 나눠 보여준다
//  요점 : 숫자를 쓰지 않는다. "3 / 7" 을 읽는 것보다 칸이 채워지는 것이 빠르다
//
//  ── 구성 ──────────────────────────────────────────────
//  SessionProgressBar
//  ├─ total              이번 회차 칸 수 = 막대 칸 개수
//  ├─ currentIndex       지금 몇 번째 칸인가 (0부터)
//  ├─ currentIsComplete  **지금 칸을 이미 채워진 것으로 볼지** (기본 true)
//  ├─ upcomingFill       아직 안 지난 칸의 색 (기본 옅은 보라)
//  └─ fill(for:)         칸 하나의 색을 정하는 유일한 판단
//
//  ── 칸이 세 단계인 이유 ────────────────────────────────
//  일반 문제(QuestionScreen)에서는 지금 칸도 **이미 채워진 것**으로 그린다 —
//  "회차 안에서 지금 몇 번째인지"를 보여주는 용도라 정답 여부와 무관하다.
//
//  연결 문제(MatchingQuestionScreen)에서는 **다 맞혀야 칸이 오른다**. 그래서
//  "아직(회색) · 지금 푸는 중(옅은 보라) · 다 맞힘(진한 보라)" 세 단계가 필요하고,
//  그 화면이 currentIsComplete 에 allMatched 를 넘긴다. 예전에는 그 화면이 막대를
//  **따로 한 벌 더 그리고 있었다.**
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen(상단), MatchingQuestionScreen(상단)
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 진행 판단 — 몇 번째인지·다 맞혔는지는 부르는 쪽이 넘긴다
//

import SwiftUI

/// 칸 수만큼 나눈 진행 막대.
///
/// 칸의 개수가 전체 분량을, 채워진 칸이 현재 위치를 동시에 알려 주므로
/// "몇 문제 중 몇 번째" 라는 글자가 따로 필요하지 않습니다.
struct SessionProgressBar: View {
    let total: Int
    let currentIndex: Int

    /// 지금 칸을 **이미 채워진 것**으로 볼지.
    ///
    /// `false` 면 지금 칸이 옅은 보라("푸는 중")로 남습니다 — 연결 문제처럼
    /// 다 맞혀야 칸이 오르는 자리에 씁니다.
    var currentIsComplete: Bool = true

    /// 아직 안 지난 칸의 색.
    ///
    /// 일반 문제는 옅은 보라(기본값), 연결 문제는 회색(``AppColor/disabledBackground``)을
    /// 씁니다 — 연결 문제 화면은 "푸는 중" 칸이 옅은 보라를 이미 쓰고 있어, 안 지난 칸을
    /// 같은 색으로 두면 둘이 구별되지 않습니다.
    var upcomingFill: Color = AppColor.softBackground

    var body: some View {
        HStack(spacing: 6) {
            // 문제가 없을 때도 막대 모양은 유지되도록 최소 1칸을 그린다.
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
            }
        }
        .frame(height: 14)
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
        .animation(.easeInOut(duration: 0.25), value: currentIsComplete)
    }

    private func fill(for index: Int) -> Color {
        if index < currentIndex { return AppColor.signature }
        if index == currentIndex {
            return currentIsComplete ? AppColor.signature : AppColor.softBackground
        }
        return upcomingFill
    }
}

#Preview("일반 문제 — 지금 칸도 채워진다") {
    VStack(spacing: 24) {
        SessionProgressBar(total: 7, currentIndex: 0)
        SessionProgressBar(total: 7, currentIndex: 3)
        SessionProgressBar(total: 7, currentIndex: 6)
    }
    .padding(24)
}

#Preview("연결 문제 — 다 맞혀야 오른다") {
    VStack(spacing: 24) {
        SessionProgressBar(total: 7, currentIndex: 2,
                           currentIsComplete: false,
                           upcomingFill: AppColor.disabledBackground)
        SessionProgressBar(total: 7, currentIndex: 2,
                           currentIsComplete: true,
                           upcomingFill: AppColor.disabledBackground)
    }
    .padding(24)
}
