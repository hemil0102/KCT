//
//  AppColor.swift
//  KCT
//
//  앱 전반의 색상. 시그니처 색(#745CF4)을 기준으로 톤을 통일한다.
//

import SwiftUI

enum AppColor {
    /// 시그니처 색 #745CF4
    static let signature = Color(red: 0x74 / 255, green: 0x5C / 255, blue: 0xF4 / 255)

    /// 시그니처 톤의 옅은 배경 (진행률 트랙, 보조 버튼 등)
    static let softBackground = signature.opacity(0.12)

    // MARK: 버튼 위계
    // 채움(시그니처) = 지금 해야 할 주 행동 / 옅은 보라 = 보조 행동 / 회색 = 아직 누를 수 없음

    /// 보조 행동 버튼 배경 (예: 다시 읽기)
    static let secondaryBackground = signature.opacity(0.14)

    /// 비활성 버튼 배경. 보조 행동과 헷갈리지 않도록 회색조로 둔다.
    static let disabledBackground = Color(red: 0.90, green: 0.90, blue: 0.92)

    /// 비활성 버튼 글씨
    static let disabledText = Color(red: 0.42, green: 0.42, blue: 0.45)

    /// 정답·성공 표시
    static let correct = Color(red: 0.12, green: 0.52, blue: 0.30)

    /// 다시 볼 문제 표시
    static let review = signature

    /// 마스터(완전히 익힘) 표시
    static let mastered = Color(red: 0.80, green: 0.46, blue: 0.08)

    /// 본문 보조 텍스트 (흰 배경에서도 또렷한 진한 회색)
    static let textMuted = Color(red: 0.26, green: 0.26, blue: 0.28)

    /// 질문에서 묻는 대상을 칠하는 형광펜. (O/X의 밑줄 강조와 구분되도록 배경색으로)
    static let marker = Color(red: 1.0, green: 0.92, blue: 0.45)
}
