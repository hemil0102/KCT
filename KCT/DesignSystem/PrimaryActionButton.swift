//
//  PrimaryActionButton.swift
//  KCT
//
//  역할 : "지금 눌러야 할 단 하나의 행동" 버튼. 다음 · 제출 · 다시 풀기
//  요점 : 준비가 안 됐을 때도 눌린다. 회색은 "못 누름"이 아니라 "아직 이르다"는 신호다
//
//  ── 구성 ──────────────────────────────────────────────
//  PrimaryActionButton
//  ├─ title      버튼 글자 ("다음  →", "제출", "다시 풀기")
//  ├─ isReady    겉모습만 바꾼다. 누를 수 있는지와는 무관하다
//  └─ action     항상 호출된다 — 준비가 안 됐으면 부르는 쪽이 안내를 띄운다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen(다음/제출), ResultScreen(다시 풀기)
//  기대는 것    : AppColor 뿐
//

import SwiftUI

/// 화면에서 가장 중요한 행동 하나를 담는 알약 버튼.
///
/// 시그니처 색을 꽉 채우는 것은 이 버튼뿐입니다. 보기 선택(``ChoiceButton``)은 상태이므로 채우지 않습니다.
///
/// - Important: `isReady` 가 `false` 여도 버튼은 눌립니다. 눌렀는데 아무 일도 일어나지 않으면 앱이 고장 났다고 생각하기 때문입니다.
struct PrimaryActionButton: View {
    let title: String

    /// 지금 진행할 준비가 됐는지. **겉모습만** 바꾼다.
    var isReady: Bool = true

    /// 버튼 높이. 결과 화면의 "다시 풀기" 는 조금 더 크게 쓴다.
    var minHeight: CGFloat = 56

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(isReady ? .white : AppColor.disabledText)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(isReady ? AppColor.signature : AppColor.disabledBackground,
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryActionButton(title: "다음  →") {}
        PrimaryActionButton(title: "다음  →", isReady: false) {}
        PrimaryActionButton(title: "다시 풀기", minHeight: 60) {}
    }
    .padding(24)
}
