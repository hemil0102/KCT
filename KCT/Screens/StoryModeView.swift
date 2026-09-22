//
//  StoryModeView.swift
//  KCT
//
//  역할 : 스토리 모드 자리(seam). 챕터·콘텐츠 설계 전까지 "준비 중" 안내만 보여준다
//  요점 : 이 화면은 안내판일 뿐이다 — 문제를 구역으로 나누는 실제 로직은 아직 없다
//
//  ── 구성 ──────────────────────────────────────────────
//  StoryModeView
//  └─ body     "준비 중" 안내 하나. 네 줄기 이름만 미리 보여준다
//
//  ── 흐름 ──────────────────────────────────────────────
//  MyHistoryView의 "스토리 모드 시작하기" → 여기로 push
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : MyHistoryView ("스토리 모드 시작하기" → NavigationLink)
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 출제 로직 — SessionBuilder.isUnlocked 게이트는 여기서 손대지
//                    않는다. 지금도 모든 문제가 항상 열려 있다
//
//  11차 후속 — 들어오면 하단 탭바가 숨는다(.toolbar(.hidden, for: .tabBar)). 나갈 때는
//  기본 뒤로가기 버튼을 그대로 쓴다 — 눌러서 나의 이력으로 돌아가면 탭바가 다시 보인다.
//
//  11차 — 스토리모드_구상.md(2026-09-05)에 이미 네 줄기(시간 이야기·살아가는
//  이야기·나라의 뼈대·한 해의 이야기)와 storyID·chapterID·orderInChapter 설계,
//  "이야기로 배우고 낱개로 확인한다"는 원칙까지 정리돼 있다. 그 문서가 정한
//  순서(① 해설 확인 → ② 문항 확장 → ③ 태그 붙이기 → ④ "한 해의 이야기"부터
//  → ⑤ 확장)를 그대로 따르기로 해서, 지금은 실제 챕터를 만들지 않고 이 안내
//  화면만 둔다. 다음 단계는 그 문서의 ④번(국경일·명절 문항으로 첫 줄기 만들기)이다.
//

import SwiftUI

/// 스토리 모드가 들어설 자리.
///
/// 실제 챕터 화면이 생기기 전까지 이 화면 하나로 "여기로 들어오면 스토리 모드"라는
/// 문만 만들어 둡니다. 어머니가 눌러 보셔도 당황하지 않도록 "준비 중"임을 분명히
/// 알리고, 곧 무엇이 생길지 짧게 보여줍니다.
struct StoryModeView: View {
    var body: some View {
        VStack(spacing: 18) {
            Text("🚧")
                .font(.system(size: 64))

            Text("스토리 모드는 준비 중이에요")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)

            Text("문제를 하나씩 따로 푸는 대신,\n이야기를 따라가며 풀 수 있게 만들고 있어요.")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)

            comingStemsCard
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("스토리 모드")
        .navigationBarTitleDisplayMode(.inline)
        // 11차 후속 — 나의 이력에서 여기로 들어오면 하단 탭바를 숨긴다. 뒤로가기는
        // NavigationStack 기본 동작을 그대로 쓰므로, 누르면 나의 이력으로 나가며
        // 탭바가 다시 보인다(따로 dismiss 처리를 하지 않아도 된다).
        .toolbar(.hidden, for: .tabBar)
    }

    /// 나중에 생길 네 줄기 이름을 미리 살짝 보여준다. (스토리모드_구상.md)
    private var comingStemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("앞으로 생길 이야기")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColor.textMuted)

            ForEach(["한 해의 이야기 (명절·국경일)", "시간 이야기 (역사)",
                     "살아가는 이야기 (제도와 생활)", "나라의 뼈대 (정치)"], id: \.self) { stem in
                Label(stem, systemImage: "book.closed.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.softBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        StoryModeView()
    }
}
