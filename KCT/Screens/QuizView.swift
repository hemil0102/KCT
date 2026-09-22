//
//  QuizView.swift
//  KCT
//
//  역할 : 회차를 준비하고, 지금 어느 화면을 보여줄지 고른다. 그리고 지문을 읽어준다
//  요점 : 그리기는 아래 세 화면에, 판단은 QuizSession 에 맡긴다. 여기는 교통정리만 한다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuizView                     퀴즈의 입구. 화면 전환과 낭독만 책임진다
//  ├─ sessionMode               연습 / 실전 — 아래로 그대로 전달
//  ├─ session                   회차의 상태와 판단 (QuizSession)
//  ├─ speaker                   낭독 도우미. 소리는 이 층에서만 다룬다
//  ├─ screen(for:)              어느 화면을 보여줄지 고르는 유일한 판단
//  ├─ prepareSession()          첫 진입에 회차를 만들고 첫 문제를 읽어준다
//  ├─ restart(_:) / erase(_:)   결과 화면의 부탁을 받아 세션에 전달
//  └─ readAloud(_:)             지문을 소리로 읽는다
//
//  ── 흐름 ──────────────────────────────────────────────
//  화면 진입 (.task)
//    → prepareSession() : QuizSession 생성 → start() → 첫 문제 낭독
//    → screen(for:) 이 세션에 물어 화면을 고른다
//        ├─ 아직 안 끝났다      → QuestionScreen
//        ├─ 끝났고 마무리 3초다 → GradingScreen
//        └─ 끝나고 채점도 됐다  → ResultScreen
//    → 문제가 넘어가면 (currentIndex 변화) → readAloud() 로 새 지문을 읽어준다
//    → ResultScreen 의 "다시 풀기" → restart() → session.start() → 낭독
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : PracticeHomeView ("종합 연습" 버튼 → NavigationLink)
//  기대는 것    : QuestionCatalog·ModelContext(환경에서 받음), QuizSession,
//                QuestionScreen·GradingScreen·ResultScreen·FeedbackSheet·CorrectAnswerSheet, SpeechReader
//  건드리지 않는 것 : 출제·채점·진척 저장 — 전부 QuizSession 의 몫이다
//
//  11차 후속 — 맞혔을 때도 CorrectAnswerSheet(정답 해설)를 띄운다. session.feedback
//  (오답)과 session.correctFeedback(정답)을 각각 `.sheet(item:)`으로 따로 띄우는데,
//  한 문제는 맞거나 틀리거나 둘 중 하나라 두 값이 동시에 채워지는 일은 없다.
//
//  11차 후속 — 예전에는 RootView 의 탭 하나가 곧 이 화면이었다. 이제는
//  PracticeHomeView 의 "종합 연습" 버튼을 눌러 들어오는 화면이 됐다. 들어오면
//  하단 탭바가 숨고(.toolbar(.hidden, for: .tabBar)), 내비게이션 바도 통째로
//  숨긴다(.toolbar(.hidden, for: .navigationBar)) — X 버튼을 내비게이션 바
//  자리에 두면 QuestionScreen 의 진행 막대 줄 위에 빈 공간이 하나 더 생기기
//  때문이다. X는 QuestionScreen 이 진행 막대와 같은 줄에 직접 그리고, 누르면
//  onClose 를 통해 여기의 dismiss() 가 불려 PracticeHomeView 로 돌아가며
//  탭바가 다시 보인다.
//

import SwiftUI
import SwiftData

/// 퀴즈 화면의 입구.
///
/// 이 뷰가 하는 일은 **셋뿐**입니다. 회차를 준비하고, 어느 화면을 보여줄지 고르고,
/// 지문을 읽어줍니다. 무엇을 낼지·무엇이 맞는지는 ``QuizSession`` 이 결정하고,
/// 어떻게 보일지는 ``QuestionScreen``·``GradingScreen``·``ResultScreen`` 이 정합니다.
///
/// - Note: 낭독을 여기 둔 이유 — 소리는 "지금 화면에 무엇이 떠 있나" 에 달린 일이지
///   회차의 규칙이 아닙니다. ``QuizSession`` 은 소리를 전혀 모릅니다.
struct QuizView: View {
    /// 이번 회차의 성격. 실전 모드에서는 형광펜 같은 도움 장치를 끈다.
    var sessionMode: SessionMode = .practice

    /// 출제할 문제집. (번들 JSON → 나중에 서버에서 교체)
    @Environment(QuestionCatalog.self) private var questionCatalog

    @Environment(\.modelContext) private var modelContext

    /// 회차의 상태와 판단. 환경 값이 필요해서 `.task` 에서 만든다.
    @State private var session: QuizSession?

    /// 문제 낭독 도우미.
    @State private var speaker = SpeechReader()

    /// 왼쪽 위 X 버튼으로 이 화면을 나갈 때 쓴다. (11차 후속 — 종합 연습 진입/이탈)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let session, !session.isEmpty {
                screen(for: session)
            } else {
                // 회차를 준비하는 아주 짧은 순간, 또는 문제집이 비어 있을 때.
                ProgressView()
            }
        }
        .onChange(of: session?.currentIndex) { _, _ in
            readAloud(session?.current)
        }
        // `session?.feedback`(내용)과 별도의 `Bool`(열림 여부)로 나누면, 이번 화면에서
        // 이 시트가 처음 뜨는 순간 내용이 아직 안 채워진 채로 한 번 열릴 수 있어
        // 시트가 크게 뜬다(9차에서 낱말 사전 시트로 먼저 겪은 버그와 같은 원인).
        // `.sheet(item:)`으로 값 자체를 열림/닫힘 신호로 쓰면 이 틈이 사라진다.
        .sheet(item: Binding(
            get: { session?.feedback },
            set: { _ in }
        )) { feedback in
            FeedbackSheet(feedback: feedback) {
                session?.dismissFeedback()
            }
        }
        // 11차 후속 — 맞혔을 때도 정답 해설 창을 띄운다. 위 오답 해설과 같은 이유로
        // `.sheet(item:)`을 따로 둔다 — 두 값이 동시에 채워지는 일은 없으므로
        // (한 문제는 맞거나 틀리거나 둘 중 하나다) 시트 두 개가 부딪히지 않는다.
        .sheet(item: Binding(
            get: { session?.correctFeedback },
            set: { _ in }
        )) { feedback in
            CorrectAnswerSheet(feedback: feedback) {
                session?.dismissCorrectFeedback()
            }
        }
        .background(Color.white)
        .task { prepareSession() }
        // 11차 후속 — "종합 연습"에서 들어온 화면이라 하단 탭바를 숨기고, 내비게이션
        // 바도 통째로 숨긴다. X·진행 막대·다시 읽기는 QuestionScreen 이 화면 맨 위에
        // 한 줄로 직접 그린다 — 내비게이션 바 자리를 따로 쓰지 않는다.
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 어느 화면을 보여줄까
    @ViewBuilder
    private func screen(for session: QuizSession) -> some View {
        if session.isFinished {
            // 결과를 보여주기 전 한 박자. 마지막 답을 누른 손이 그대로
            // 결과 화면의 버튼을 누르는 것을 막는다.
            if session.isWrappingUp {
                GradingScreen()
            } else {
                ResultScreen(
                    session: session,
                    onRestart: { restart(session) },
                    onEraseProgress: { erase(session) }
                )
            }
        } else {
            QuestionScreen(session: session, sessionMode: sessionMode, onClose: { dismiss() }) {
                readAloud(session.current)
            }
        }
    }

    // MARK: - 회차 준비

    /// 첫 진입에 회차를 만든다. 이미 있으면 아무것도 하지 않는다.
    private func prepareSession() {
        guard session == nil else { return }

        let newSession = QuizSession(catalog: questionCatalog, modelContext: modelContext)
        newSession.start()
        session = newSession
    }

    /// 새 회차를 시작한다. (결과 화면의 "다시 풀기")
    private func restart(_ session: QuizSession) {
        session.start()
    }

    /// 학습 기록을 모두 지우고 새 회차를 시작한다. (결과 화면의 "학습 기록 초기화")
    private func erase(_ session: QuizSession) {
        session.eraseAllProgress()
    }

    // MARK: - 낭독

    /// 주어진 문제의 지문을 소리 내어 읽는다. 문제가 없으면 읽지 않는다.
    private func readAloud(_ item: QuizItem?) {
        guard let item else { return }
        speaker.speak(item.displayText)
    }
}

#Preview {
    QuizView()
        .environment(QuestionCatalog.loaded())
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self], inMemory: true)
}
