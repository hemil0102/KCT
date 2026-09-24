//
//  CircleIconButton.swift
//  KCT
//
//  역할 : 글자 없이 아이콘만 있는 44pt 원형 버튼
//  요점 : X(닫기)와 다시 읽기가 같은 줄·같은 배경·같은 색이라 한 쌍으로 보여야 한다
//
//  ── 구성 ──────────────────────────────────────────────
//  CircleIconButton
//  ├─ systemName   SF Symbol 이름 ("xmark", "speaker.wave.2.fill")
//  └─ action       눌렀을 때 할 일
//
//  ── 왜 44pt 인가 ───────────────────────────────────────
//  애플 HIG 의 최소 터치 목표가 44×44pt 다. 진행 막대와 같은 줄에 두어야 해서
//  더 키울 수 없는 자리라, 최소선에 딱 맞춰 둔다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen(X · 다시 읽기), MatchingQuestionScreen(X)
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 화면을 닫는 일·소리를 내는 일 — 전부 부르는 쪽의 몫
//

import SwiftUI

/// 아이콘만 있는 원형 버튼.
///
/// 시그니처 보라 아이콘 + 옅은 보라 배경(``AppColor/secondaryBackground``)입니다.
/// X와 다시 읽기가 **같은 색까지 맞춰** 한 쌍으로 보이게 하려는 것입니다.
struct CircleIconButton: View {
    /// SF Symbol 이름.
    let systemName: String

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.signature)
                .frame(width: 44, height: 44)
                .background(AppColor.secondaryBackground, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        CircleIconButton(systemName: "xmark") {}
        CircleIconButton(systemName: "speaker.wave.2.fill") {}
    }
    .padding(24)
}
