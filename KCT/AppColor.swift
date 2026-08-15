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

    /// 시그니처 톤의 옅은 배경 (진행률 트랙, 다시 읽기 버튼 등)
    static let softBackground = signature.opacity(0.12)

    /// 비활성 버튼 배경 (시그니처 톤을 옅게)
    static let disabledBackground = signature.opacity(0.18)

    /// 정답·성공 표시
    static let correct = Color(red: 0.12, green: 0.52, blue: 0.30)

    /// 다시 볼 문제 표시
    static let review = signature

    /// 마스터(완전히 익힘) 표시
    static let mastered = Color(red: 0.80, green: 0.46, blue: 0.08)

    /// 본문 보조 텍스트 (흰 배경에서도 또렷한 진한 회색)
    static let textMuted = Color(red: 0.26, green: 0.26, blue: 0.28)
}
