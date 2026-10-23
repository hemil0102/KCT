//
//  MotionBeats.swift
//  KCT
//
//  역할 : 화면이 「잠깐 뒤에」 하는 일과 흔들림 세 박자를 한 곳에서 맡는다
//  요점 : GCD(`DispatchQueue.main.asyncAfter`) 대신 `Task.sleep` — 앱 전체가 async·await 하나로 간다
//
//  ── 구성 ──────────────────────────────────────────────
//  Beat
//  ├─ after(_:_:)     delay 뒤에 메인 액터에서 work 를 한 번 한다
//  └─ shake(_:)       흔들림 세 박자 (-6 → +6 → 0). 오답 보기·연결 카드가 같이 쓴다
//
//  ── 왜 따로 뺐나 (2차 리팩토링, 2026-10-23) ─────────────
//  같은 `shake` 가 QuestionScreen 과 MatchingQuestionScreen 에 글자까지 똑같이 둘 있었다.
//  결정 기록 「같은 모습은 같은 코드로 강제한다」를 따라 하나로 모았다.
//  박자 값(0.08 · 0.16 · 0.08초, ±6pt)은 실측값이라 **바꾸지 않았다.**
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen(오답 보기 소거·흔들림), MatchingQuestionScreen(카드 흔들림·안내 말풍선)
//  기대는 것    : SwiftUI 의 withAnimation 뿐
//  건드리지 않는 것 : 무엇을 흔들지·언제 그만둘지 — 부르는 쪽이 클로저와 가드로 정한다
//

import SwiftUI

/// 화면의 시간차 동작 모음.
///
/// - Note: 「그 사이 다음 문제로 넘어갔으면 건너뛴다」 같은 가드는 **부르는 쪽의 클로저 안에** 그대로 둔다.
///   여기는 기다리는 방법만 바꾼 것이라, 가드를 빼면 예전처럼 새 문제를 건드린다.
enum Beat {

    /// `delay` 뒤에 메인 액터에서 `work` 를 한 번 한다.
    ///
    /// `DispatchQueue.main.asyncAfter(deadline: .now() + 초)` 와 같은 일을 Swift 동시성으로 한다.
    static func after(_ delay: Duration, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            work()
        }
    }

    /// 흔들림 세 박자. CSS 의 `25% -6px · 75% +6px` 을 그대로 옮긴 것이다.
    ///
    /// - Parameter apply: 오프셋 값을 받아 제 자리에 넣어 주는 클로저.
    ///   (`Beat.shake { cardOffsetX[key] = $0 }` 처럼 쓴다)
    static func shake(_ apply: @escaping @MainActor (CGFloat) -> Void) {
        // 첫 박자는 누른 그 순간에 — 한 틱 늦으면 손가락과 흔들림이 어긋나 보인다.
        withAnimation(.easeInOut(duration: 0.08)) { apply(-6) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeInOut(duration: 0.16)) { apply(6) }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.easeInOut(duration: 0.08)) { apply(0) }
        }
    }
}
