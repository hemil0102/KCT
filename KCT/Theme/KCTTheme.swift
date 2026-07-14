//
//  KCTTheme.swift
//  KCT

import SwiftUI

enum KCTTheme {
    static let cream = Color(red: 1.0, green: 0.976, blue: 0.949)      // #FFF9F2
    static let orangeTop = Color(red: 1.0, green: 0.541, blue: 0.239)  // #FF8A3D
    static let orangeBottom = Color(red: 1.0, green: 0.439, blue: 0.157) // #FF7028
    static let cardBorder = Color(red: 0.941, green: 0.894, blue: 0.847) // #F0E4D8
    static let textDark = Color(red: 0.227, green: 0.180, blue: 0.133)  // #3A2E22
    static let textMuted = Color(red: 0.541, green: 0.478, blue: 0.416) // #8A7A6A
    static let chipMuted = Color(red: 0.718, green: 0.655, blue: 0.588) // #B7A796
    static let chipBg = Color(red: 1.0, green: 0.910, blue: 0.824)     // #FFE8D2
    static let chipText = Color(red: 0.710, green: 0.329, blue: 0.102) // #B5541A
    static let tabBarBg = Color(red: 1.0, green: 0.953, blue: 0.910)   // #FFF3E8

    static let orangeGradient = LinearGradient(
        colors: [orangeTop, orangeBottom],
        startPoint: .top, endPoint: .bottom
    )
}

// 설정 탭에서 바꾸는 "문제 글자 크기" — 다른 화면에서 @AppStorage("questionFontSize")로 읽어서 사용
enum QuestionFontSize: String, CaseIterable {
    case small = "작게", medium = "보통", large = "크게"

    var titleSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 19
        case .large: return 23
        }
    }
}
