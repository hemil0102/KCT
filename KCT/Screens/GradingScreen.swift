//
//  GradingScreen.swift
//  KCT
//
//  역할 : 회차를 마무리하는 3초 동안 보여주는 화면
//  요점 : 상태가 없다. 오직 "기다리는 중"만 알린다
//
//  ── 구성 ──────────────────────────────────────────────
//  GradingScreen   빙글빙글 도는 표시 + 안심시키는 두 줄
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView — session.isWrappingUp 이 true 인 3초 동안
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 채점 자체 — 채점은 문항마다 이미 끝나 있다
//

import SwiftUI

/// 마지막 문제를 넘긴 뒤 결과 화면 앞에서 3초 동안 보여주는 화면.
///
/// 채점 자체는 문항마다 이미 끝나 있습니다. 그래도 한 박자를 두는 이유는,
/// 마지막 답을 누른 손이 그대로 결과 화면의 버튼을 누르는 것을 막고
/// **회차가 끝났다는 것을 몸으로 알리기** 위해서입니다.
struct GradingScreen: View {
    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(AppColor.softBackground)
                    .frame(width: 120, height: 120)
                ProgressView()
                    .controlSize(.large)
                    .tint(AppColor.signature)
                    .scaleEffect(1.6)
            }

            VStack(spacing: 8) {
                Text("채점 중이에요")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                Text("잠시만 기다려 주세요")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

#Preview {
    GradingScreen()
}
