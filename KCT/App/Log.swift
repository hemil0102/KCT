//
//  Log.swift
//  KCT
//
//  역할 : 앱이 남기는 진단 기록의 이름표(카테고리)를 한 곳에 모은다
//  요점 : `print` 는 Xcode 에 붙어 있을 때만 보인다. `Logger` 는 **어머니 폰에서 난 일도** Mac 의 콘솔 앱으로 볼 수 있다
//
//  ── 구성 ──────────────────────────────────────────────
//  Log
//  ├─ grading   채점 (QuizSession.judge)
//  ├─ model     모델에게 글 시키기 (ModelCall · EncouragementWriter · GlossaryExampleWriter)
//  ├─ upload    관찰 기록 업로드 (ObsUploader)
//  └─ voice     음성 입력 (SpeechListener)
//
//  ── 보는 법 ─────────────────────────────────────────────
//  Mac 의 「콘솔」 앱 → 왼쪽에서 어머니 아이폰 → 검색창에 `subsystem:` + 앱 번들 ID → 카테고리로 거른다.
//  Xcode 로 실행 중이면 디버그 영역에 예전 print 처럼 그대로 나온다.
//
//  ── 개인정보 표시 ────────────────────────────────────────
//  `Logger` 는 글자 안에 끼운 값을 기본으로 가린다(<private>). 여기서 남기는 것은 에러 설명·개수·
//  모델 지침 같은 진단용이라 `privacy: .public` 으로 보이게 한다. **어머니가 입력한 답은 넣지 않는다.**
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : 위 구성의 파일들
//  기대는 것    : OSLog
//
//  참고: https://developer.apple.com/documentation/os/logger
//

import OSLog

/// 진단 기록의 이름표 모음. (2차 리팩토링 — 흩어져 있던 `print` 12곳을 옮겼다)
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "KCT"

    static let grading = Logger(subsystem: subsystem, category: "grading")
    static let model   = Logger(subsystem: subsystem, category: "model")
    static let upload  = Logger(subsystem: subsystem, category: "upload")
    static let voice   = Logger(subsystem: subsystem, category: "voice")
}
