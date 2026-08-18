//
//  GradingScreen.swift
//  KCT
//
//  역할 : 채점을 기다리는 동안 보여주는 화면
//  요점 : 상태가 없다. 오직 "기다리는 중"만 알린다
//
//  ── 구성 ──────────────────────────────────────────────
//  GradingScreen   빙글빙글 도는 표시 + 안심시키는 두 줄
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView — session.isGrading 이 true 인 동안
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 채점 자체 — 진행은 QuizSession.gradeAll() 이 한다
//

import SwiftUI

/// 채점이 끝날 때까지 보여주는 대기 화면.
///
/// 직접입력이 있는 회차는 온디바이스 모델을 부르므로 잠깐 시간이 걸립니다.
/// 그동안 화면이 멈춘 것처럼 보이면 어르신은 앱이 고장 났다고 생각하므로,
/// **무엇을 하고 있는지와 기다려도 된다는 것**을 함께 알립니다.
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
