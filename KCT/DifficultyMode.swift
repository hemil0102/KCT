//
//  DifficultyMode.swift
//  KCT
//
//  [축 B] 어머니의 학습 레벨 = 출제 모드. (문제별로 저장·변동)
//

import Foundation

/// 문제별 난이도 사다리. rawValue가 곧 레벨(0..3)이며, 낮을수록 쉽다.
///
/// 정답이면 한 단계 올라가고(승급), 오답이면 한 단계 내려간다(강등).
/// 최고 단계(``typing``)에서 정답이면 그 문제는 "마스터"로 본다.
enum DifficultyMode: Int, CaseIterable, Codable, Comparable {
    case binaryChoice   = 0   // 2지선다
    case trueOrFalse    = 1   // O/X
    case multipleChoice = 2   // 4지선다
    case typing         = 3   // 직접입력 (음성은 이 단계의 대체 입력수단)

    /// 마스터로 간주하는 최고 단계.
    static let mastery = DifficultyMode.typing

    static func < (lhs: DifficultyMode, rhs: DifficultyMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 화면에 표시할 짧은 이름.
    var title: String {
        switch self {
        case .binaryChoice:   "2지선다"
        case .trueOrFalse:    "O / X"
        case .multipleChoice: "4지선다"
        case .typing:         "직접 입력"
        }
    }
}
