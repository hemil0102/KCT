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
//  ├─ textMuted            보조 텍스트 (흰 배경에서도 또렷한 진회색)
//  └─ marker               형광펜 (연노랑) — 묻는 대상
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

    /// 정답을 각인시키는 연두. 정답이 나오는 모든 자리에 같은 색을 쓴다.
    static let answerAccent = Color(red: 0.33, green: 0.61, blue: 0.16)
}
