//
//  SessionMode.swift
//  KCT
//
//  세션의 성격. 연습은 도움을 주고, 실전은 도움 없이 실제 시험처럼 진행한다.
//

import Foundation

enum SessionMode {
    /// 연습 모드 — 학습을 돕는 장치를 제공한다.
    case practice
    /// 실전 모드 — 실제 시험처럼 도움 없이 푼다.
    case exam

    /// 질문에서 묻는 대상을 형광펜으로 강조할지 여부.
    /// (연습에서만 제공하고, 실전에서는 스스로 읽고 판단하게 한다)
    var showsFocusHighlight: Bool {
        self == .practice
    }
}
