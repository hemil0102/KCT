//
//  CumulativeCountCard.swift
//  KCT
//
//  역할 : "지금까지 맞힌 문제 N개" 를 크게 보여주는 시그니처 카드와 마스터 배지
//  요점 : 이 앱이 강조하는 숫자는 **이번 회차 점수가 아니라 누적 개수**다
//
//  ── 구성 ──────────────────────────────────────────────
//  CumulativeCountCard
//  ├─ count      지금까지(모든 회차 누적) 맞힌 총 횟수 — 이 카드의 주인공
//  └─ caption    카드 맨 아래 한 줄. 부르는 화면마다 다르다
//                · 결과 화면  "오늘 7문제 중 5개 맞혔어요"
//                · 나의 이력  "전체 30문항 중 도전하고 있어요"
//
//  MasteredBadge
//  └─ count      완전히 익힌 문제 개수. 0개면 부르는 쪽이 아예 안 그린다
//
//  ── 왜 누적인가 ────────────────────────────────────────
//  매일 다섯 문제씩 푸는 사람에게 "5문제 중 3개" 는 작아 보이지만,
//  "지금까지 412개" 는 계속할 이유가 된다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : ResultScreen(회차 끝), MyHistoryView(나의 이력 탭)
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 세는 일 — 두 화면이 각자 @Query 로 읽어 센 값을 넘긴다
//

import SwiftUI

/// 누적 정답 개수를 크게 보여주는 보라 카드.
///
/// 두 화면이 **같은 부품**을 씁니다. 예전에는 각자 한 벌씩 들고 있어서 한 줄(caption)만
/// 다른 판박이였는데, 그러면 「카드 모서리를 더 둥글게」 같은 요청에 두 곳을 고쳐야 하고
/// 한쪽을 잊으면 같은 숫자가 탭마다 다르게 보입니다.
struct CumulativeCountCard: View {
    let count: Int
    let caption: String

    var body: some View {
        VStack(spacing: 6) {
            Text("지금까지 맞힌 문제")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("\(count)개")
                .font(.system(size: 52, weight: .heavy))
                .foregroundStyle(.white)

            Text(caption)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColor.signature, in: RoundedRectangle(cornerRadius: 24))
    }
}

/// "완전히 익힌 문제 N개" 배지. 주황(``AppColor/mastered``)을 쓰는 유일한 자리.
struct MasteredBadge: View {
    let count: Int

    var body: some View {
        Label("완전히 익힌 문제 \(count)개", systemImage: "star.fill")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppColor.mastered, in: Capsule())
    }
}

#Preview {
    VStack(spacing: 20) {
        CumulativeCountCard(count: 412, caption: "오늘 7문제 중 5개 맞혔어요")
        MasteredBadge(count: 3)
        CumulativeCountCard(count: 0, caption: "전체 30문항 중 도전하고 있어요")
    }
    .padding(24)
}
