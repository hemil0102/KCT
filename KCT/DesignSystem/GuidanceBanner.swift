//
//  GuidanceBanner.swift
//  KCT
//
//  역할 : 화면 아래쪽에 뜨는 검정 알약 안내 줄
//  요점 : 무엇을 해야 하는지 한 줄로 알린다. 나무라지 않는다
//
//  ── 구성 ──────────────────────────────────────────────
//  GuidanceBanner
//  ├─ text              보여줄 한 줄
//  ├─ fontSize          글자 크기 (두 화면이 18 / 17 로 다르다 — 아래 참고)
//  ├─ verticalPadding   위아래 여백 (12 / 13)
//  └─ bottomPadding     아래 여백 (12 / 14)
//
//  ── 크기를 인자로 받는 이유 ────────────────────────────
//  두 화면의 값이 원래 조금씩 달랐다(QuestionScreen 18pt·12·12,
//  MatchingQuestionScreen 17pt·13·14). 합치면서 한쪽으로 통일하면 **화면이
//  바뀌어 버리므로** 지금 값을 각자 그대로 넘기게 뒀다. 통일할지는 실기기에서
//  나란히 보고 정할 일이다.
//
//  나타나고 사라지는 방식(transition / opacity)도 두 화면이 다르므로 여기 넣지
//  않고 부르는 쪽에서 붙인다 — QuestionScreen 은 아래에서 밀려 올라오고,
//  MatchingQuestionScreen 은 자리에 있는 채로 흐려진다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen(답을 안 골랐을 때), MatchingQuestionScreen(짝 안내)
//  기대는 것    : SwiftUI 뿐 — 색도 AppColor 가 아니라 .black 을 쓴다
//  건드리지 않는 것 : 언제 띄울지 — 부르는 쪽이 정한다
//

import SwiftUI

/// 검정 알약 안내 줄.
///
/// 흰 배경 위 검정 알약이라 대비가 가장 큽니다 — 어르신이 놓치지 않아야 하는 줄입니다.
/// 색을 ``AppColor`` 에서 가져오지 않고 `.black` 을 쓰는 것은, 이 줄이 「앱의 색 위계」
/// 밖에 있는 **알림**이기 때문입니다.
struct GuidanceBanner: View {
    let text: String

    var fontSize: CGFloat = 18
    var verticalPadding: CGFloat = 12
    var bottomPadding: CGFloat = 12

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .background(.black, in: Capsule())
            .padding(.bottom, bottomPadding)
    }
}

#Preview {
    VStack {
        Spacer()
        GuidanceBanner(text: "문제를 고르면 다음으로 갈 수 있어요.")
        GuidanceBanner(text: "왼쪽에서 용어를 골라주세요.",
                       fontSize: 17, verticalPadding: 13, bottomPadding: 14)
    }
    .padding(24)
}
