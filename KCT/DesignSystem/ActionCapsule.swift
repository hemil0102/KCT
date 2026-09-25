//
//  ActionCapsule.swift
//  KCT
//
//  역할 : 앱의 큰 알약 버튼 두 무게와, 화면 맨 위 제목 한 줄
//  요점 : 「꽉 채운 시그니처」는 지금 눌러야 할 행동 하나에만. 고르는 행동은 흰 알약
//
//  ── 구성 ──────────────────────────────────────────────
//  ActionCapsuleLabel     시그니처 채움 알약 — 버튼이 아니라 **라벨**이다
//  │                      (Button 과 NavigationLink 가 같은 모습을 쓰게 하려면
//  │                       라벨과 버튼을 나눠야 한다)
//  SecondaryActionButton  흰 알약 + 시그니처 글자 — 한 단계 가벼운 무게
//  ScreenTitle            34pt 굵은 검정, 왼쪽 정렬. 탭 첫 화면의 제목
//
//  ── 무게가 셋인 이유 ───────────────────────────────────
//  채움(ActionCapsuleLabel)  = "이걸 누르면 계속 진행된다"   — 다음 / 제출 / 종합 연습
//  흰 알약(Secondary)        = "원하면 고르는 부가 행동"      — 정답 해설 보기 / 닫기
//  테두리만(ChoiceButton)    = "상태다. 행동이 아니다"        — 보기 선택
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : PrimaryActionButton · PracticeHomeView · MyHistoryView ·
//                CorrectAnswerSheet · GlossaryPanel
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 눌렀을 때 할 일 — 전부 부르는 쪽이 정한다
//

import SwiftUI

/// 시그니처 색을 꽉 채운 알약 **라벨**.
///
/// 버튼이 아니라 라벨인 이유 — 같은 모습을 `Button`(``PrimaryActionButton``)과
/// `NavigationLink`(「종합 연습」·「스토리 모드 시작하기」)가 함께 써야 하는데,
/// SwiftUI 에서 그 둘은 라벨을 받는 자리가 서로 다릅니다. **모습만 떼어 두면 둘 다 쓸 수 있습니다.**
struct ActionCapsuleLabel: View {
    let title: String

    /// 버튼 높이. 결과 화면의 「다시 풀기」와 탭 첫 화면의 진입 버튼은 60을 쓴다.
    var minHeight: CGFloat = 56

    /// 지금 진행할 준비가 됐는지. **겉모습만** 바꾼다.
    var isReady: Bool = true

    var body: some View {
        Text(title)
            .font(.system(size: 23, weight: .bold))
            .foregroundStyle(isReady ? .white : AppColor.disabledText)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(isReady ? AppColor.signature : AppColor.disabledBackground,
                        in: Capsule())
    }
}

/// 흰 알약 + 시그니처 글자. 채움 버튼보다 **한 단계 가벼운** 무게.
///
/// 「반드시 눌러야 진행되는」 자리가 아니라 **원하면 고르는 부가 행동**에 씁니다 —
/// 정답 해설 창의 「정답 해설 보기」(안 보고 바로 다음 문제로 갈 수 있다), 낱말 사전의
/// 「닫기」(배경을 눌러도 답을 골라도 똑같이 닫힌다).
struct SecondaryActionButton: View {
    let title: String

    var minHeight: CGFloat = CommentaryMetrics.buttonHeight

    /// 기다리는 중이면 글자 대신 도는 인디케이터를 보여준다 — 알약의 자리·크기는
    /// 그대로 지킨다. ``CorrectAnswerSheet``의 「정답 해설 보기」가 쓴다(13차
    /// 후속) — 눌렀을 때 시트가 바로 커지지 않고, 해설이 준비되는 동안 이
    /// 버튼이 로딩 중임을 보여준다.
    var isLoading: Bool = false

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(AppColor.signature)
                } else {
                    Text(title)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(AppColor.signature)
                }
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 탭 첫 화면의 제목 한 줄.
///
/// 글자색을 `.black` 으로 **못 박아 둡니다.** 기본값(`.primary`)이면 기기가 다크 모드일 때
/// 흰 글자가 되는데, 이 앱은 배경을 전부 흰색으로 고정해 두었으므로 흰 배경 위 흰 글자가
/// 되어 **글자만 안 보입니다.**
struct ScreenTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 16) {
        ScreenTitle("문제 풀기")
        ActionCapsuleLabel(title: "다음  →")
        ActionCapsuleLabel(title: "다음  →", isReady: false)
        ActionCapsuleLabel(title: "종합 연습", minHeight: 60)
        SecondaryActionButton(title: "정답 해설 보기") {}
    }
    .padding(24)
    .background(AppColor.signature.opacity(0.2))
}
