//
//  ReviewIntroScreen.swift
//  KCT
//
//  역할 : 회차를 다 푼 뒤, 틀린 문제를 한 번 더 풀기 전에 한 번 보여주는 화면
//  요점 : 복습 문제 화면은 본 문제와 거의 같아서(맨 위 띠만 다르다) 복습인지 모르고
//         지나칠 수 있다. 그 알림을 이 한 장이 맡는다
//
//  ── 구성 ──────────────────────────────────────────────
//  ReviewIntroScreen
//  ├─ count      복습할 문제 수
//  ├─ onStart    「다시 풀어 보기」 → QuizSession.startReview()
//  └─ onClose    왼쪽 위 X — 다른 화면과 같이 연습을 나간다
//
//  ── 흐름 ──────────────────────────────────────────────
//  마지막 칸의 해설 창을 닫는다
//    → 틀린 문제가 있으면 QuizSession.isShowingReviewIntro 가 켜지고 QuizView 가 이 화면을 띄운다
//    → 「다시 풀어 보기」 → 복습 문제들(QuestionScreen, 맨 위에 「복습 1 / n」 띠)
//    → 다 풀면 「채점 중」 3초 → 결과 화면
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView
//  기대는 것    : AppColor, CircleIconButton, PrimaryActionButton
//  건드리지 않는 것 : 복습을 시작하는 일 — onStart 로 위에 부탁한다
//

import SwiftUI

struct ReviewIntroScreen: View {
    let count: Int
    let onStart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CircleIconButton(systemName: "xmark", action: onClose)
                Spacer()
            }

            Spacer(minLength: 40)

            Label("복습", systemImage: "arrow.clockwise")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(AppColor.signature, in: Capsule())

            Text("틀린 \(count)문제만\n한 번 더 볼게요")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black)
                .lineSpacing(6)
                .padding(.top, 18)

            Text("천천히 다시 풀어 보세요.\n맞히면 결과에 「다시 풀어서 정답」으로 남아요.")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColor.textMuted)
                .lineSpacing(6)
                .padding(.top, 12)

            Spacer()
            Spacer()

            PrimaryActionButton(title: "다시 풀어 보기  →",
                                minHeight: CommentaryMetrics.buttonHeight,
                                action: onStart)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(Color.white)
    }
}

#Preview {
    ReviewIntroScreen(count: 2, onStart: {}, onClose: {})
}
