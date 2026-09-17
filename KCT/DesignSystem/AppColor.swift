//
//  AppColor.swift
//  KCT
//
//  역할 : 앱 전체의 색. 시그니처 #745CF4 를 기준으로 톤을 통일한다
//  요점 : 색이 곧 위계다. "꽉 채운 시그니처" 는 지금 눌러야 할 행동 하나에만 쓴다
//
//  ── 구성 ──────────────────────────────────────────────
//  AppColor (enum — 값만 모아 둔 곳)
//  ├─ signature            시그니처 #745CF4
//  ├─ softBackground       옅은 보라 (진행 막대 트랙, 선택된 보기)
//  ├─ secondaryBackground  보조 행동 배경 (다시 읽기)
//  ├─ disabledBackground   아직 이른 버튼 배경 — 회색조로 보조 행동과 구분
//  ├─ disabledText         아직 이른 버튼 글씨
//  ├─ correct              정답 표시 (진한 초록)
//  ├─ review               다시 볼 문제 표시 (= signature)
//  ├─ mastered             완전히 익힘 표시 (주황)
//  ├─ chosenAnswer         고른 답 (주황)
//  ├─ answerAccent         정답 (파랑) · answerBackground 옅은 파랑
//  ├─ wrongAccent          모달 안의 고르신 답 (붉은색) · wrongBackground 옅은 붉은색
//  ├─ textMuted            보조 텍스트 (흰 배경에서도 또렷한 진회색)
//  ├─ marker               형광펜 (연노랑) — 묻는 대상
//  ├─ wordBadgeBackground  낱말에 칠하는 연라벤더 배지 배경(모달 헤더·해설·지문 공용) —
//  │                        보라 한 계열 안에서 밝은 쪽
//  └─ wordBadgeText        그 배지 위 낱말 글자색 — 같은 보라 계열의 짙은 쪽. "뜻"은
//                          이 팔레트에서 배지 없이 흰 글자(Color.white)를 그대로 쓴다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : DesignSystem 부품들, Screens 전부, KoreanText
//  기대는 것    : SwiftUI 뿐
//  건드리지 않는 것 : 도메인 — 이 파일은 문제도 진척도 모른다
//

import SwiftUI

/// 앱 전반의 색 팔레트.
///
/// **채움은 주 행동 하나에만** 씁니다. 선택된 보기까지 꽉 채우면 무엇을 눌러야 할지 알 수 없으므로, 상태와 행동은 다른 신호로 둡니다.
///
/// - Note: 어르신 대비를 위해 보조 텍스트도 연회색 대신 진회색(``textMuted``)을 씁니다.
enum AppColor {

    /// 시그니처 색 #745CF4
    static let signature = Color(red: 0x74 / 255, green: 0x5C / 255, blue: 0xF4 / 255)

    /// 시그니처 톤의 옅은 배경 (진행 막대 트랙, 선택된 보기)
    static let softBackground = signature.opacity(0.12)

    // MARK: 버튼 위계

    /// 보조 행동 버튼 배경 (예: 다시 읽기)
    static let secondaryBackground = signature.opacity(0.14)

    /// 아직 진행할 수 없을 때의 버튼 배경.
    ///
    /// 같은 보라 계열이면 "누를 수 있는 보조 버튼" 으로 오해하므로 회색조로 둡니다.
    static let disabledBackground = Color(red: 0.90, green: 0.90, blue: 0.92)

    /// 아직 진행할 수 없을 때의 버튼 글씨
    static let disabledText = Color(red: 0.42, green: 0.42, blue: 0.45)

    // MARK: 상태 표시

    /// 정답·성공 표시
    static let correct = Color(red: 0.12, green: 0.52, blue: 0.30)

    /// 다시 볼 문제 표시.
    ///
    /// 빨강을 쓰지 않습니다. "틀렸다" 가 아니라 "또 만날 문제" 라는 뜻이므로 시그니처 색을 그대로 씁니다.
    static let review = signature

    /// 마스터(완전히 익힘) 표시
    static let mastered = Color(red: 0.80, green: 0.46, blue: 0.08)

    // MARK: 글자와 강조

    /// 본문 보조 텍스트 (흰 배경에서도 또렷한 진한 회색)
    static let textMuted = Color(red: 0.26, green: 0.26, blue: 0.28)

    /// 질문이 묻는 대상을 칠하는 형광펜.
    ///
    /// O/X 의 밑줄 강조와 구분되도록 글자색이 아니라 배경색으로 씁니다.
    static let marker = Color(red: 1.0, green: 0.92, blue: 0.45)
    
    /// 어머니가 고른 답을 적을 때. 시그니처(보라)와 반대편의 주황.
    static let chosenAnswer = Color(red: 0.80, green: 0.44, blue: 0.10)

    /// 낱말 사전 모달(시그니처 보라 배경) 위에서 낱말에 칠하는 배지 배경 — 헤더의
    /// 낱말, 해설 속 낱말, 지문에서 사전 시트가 열린 낱말 셋 다 이 색을 쓴다.
    ///
    /// 그동안 주황 계열로 여러 번 다시 조정했지만("노란빛 같다" → "갈색 같다" →
    /// "대비가 부족하다" 등으로 계속 미세조정이 필요했다) 마음에 드는 균형을 못
    /// 찾아서, 보라 하나만 쓰는 안 포함 데모 3개를 만들어 보여드렸고 "보라 톤
    /// 모노크롬"안으로 정했다. 시그니처(#745CF4)를 흰색 쪽으로 많이 섞어 만든
    /// 밝은 라벤더다 — 보라 한 계열 안에서 명도 차이로만 위계를 만드니 주황을
    /// 쓸 때처럼 "정확히 얼마나 주황다워야 하는지"를 미세조정할 일이 없다.
    static let wordBadgeBackground = Color(red: 0.92, green: 0.90, blue: 0.99)

    /// 위 `wordBadgeBackground` 배지 위에서 낱말 글자에 쓰는 색 — 시그니처를
    /// 검정 쪽으로 섞은 짙은 보라. 밝은 라벤더 배경 위에서 또렷이 읽힌다.
    ///
    /// "뜻"은 이 팔레트에서 별도 색을 만들지 않고 `Color.white`를 그대로
    /// 쓴다 — 보라 모노크롬안의 핵심이 "색상 하나(보라)의 명도 차이만으로
    /// 위계를 만든다"는 것이라, 뜻까지 보라 계열 색을 새로 만들면 오히려
    /// 구분이 흐려진다. 시그니처 보라 배경 위에 흰 글자가 가장 또렷하고,
    /// 낱말의 배지가 그보다 한 단계 더 강조되는 구조다.
    static let wordBadgeText = Color(red: 0.32, green: 0.25, blue: 0.67)

    /// 정답을 각인시키는 색. 정답이 나오는 모든 자리에 같은 색을 쓴다.
    ///
    /// 시그니처(#745CF4)와 같은 파랑 계열에서 한 칸 진하게 잡아, 보라 버튼 옆에 두어도
    /// 따로 놀지 않으면서 **글자로서 또렷하게** 읽힙니다.
    static let answerAccent = Color(red: 0.18, green: 0.36, blue: 0.82)

    /// 옅은 파랑 배경. 정답 칸을 감쌀 때.
    static let answerBackground = answerAccent.opacity(0.10)

    /// 고르신 답과 그 설명을 적을 때의 붉은색.
    ///
    /// 보라·파랑과 색상환에서 멀되 **채도를 낮춰** 놀라지 않게 합니다.
    /// 이 색은 **모달 안에서만** 씁니다 — 목록·결과 화면의 「다시 볼 문제」는 여전히
    /// ``review``(시그니처)입니다. 화면에서 「틀렸다」를 강조하지 않기로 한 원칙 때문입니다.
    static let wrongAccent = Color(red: 0.78, green: 0.22, blue: 0.24)

    /// 옅은 붉은 배경. 고르신 답 칸을 감쌀 때.
    static let wrongBackground = wrongAccent.opacity(0.08)

}
