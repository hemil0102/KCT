//
//  SessionProgressBar.swift
//  KCT
//
//  역할 : 회차의 진행 상황을 문제 수만큼 나눈 칸으로 보여준다
//  요점 : 숫자를 쓰지 않는다. "3 / 5" 를 읽는 것보다 칸이 채워지는 것이 빠르다
//
//  ── 구성 ──────────────────────────────────────────────
//  SessionProgressBar
//  ├─ total          이번 회차 문제 수 = 칸 개수
//  └─ currentIndex   지금 몇 번째인가 (0부터). 이 칸까지 채워진다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen 상단
//  기대는 것    : AppColor 뿐
//

import SwiftUI

/// 문제 수만큼 칸을 나눈 진행 막대.
///
/// 칸의 개수가 전체 분량을, 채워진 칸이 현재 위치를 동시에 알려 주므로 "몇 문제 중 몇 번째" 라는 글자가 따로 필요하지 않습니다.
struct SessionProgressBar: View {
    let total: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            // 문제가 없을 때도 막대 모양은 유지되도록 최소 1칸을 그린다.
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? AppColor.signature : AppColor.softBackground)
            }
        }
        .frame(height: 14)
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }
}

#Preview {
    VStack(spacing: 24) {
        SessionProgressBar(total: 5, currentIndex: 0)
        SessionProgressBar(total: 5, currentIndex: 2)
        SessionProgressBar(total: 5, currentIndex: 4)
    }
    .padding(24)
}
