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
//        ├─ 끝났고 채점 중이다  → GradingScreen
//        └─ 끝나고 채점도 됐다  → ResultScreen
//    → 문제가 넘어가면 (currentIndex 변화) → readAloud() 로 새 지문을 읽어준다
//    → ResultScreen 의 "다시 풀기" → restart() → session.start() → 낭독
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : RootView
//  기대는 것    : QuestionCatalog·ModelContext(환경에서 받음), QuizSession,
//                QuestionScreen·GradingScreen·ResultScreen, SpeechReader
//  건드리지 않는 것 : 출제·채점·진척 저장 — 전부 QuizSession 의 몫이다
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
    @Environment(QuestionCatalog.self) private var catalog

    @Environment(\.modelContext) private var modelContext

    /// 회차의 상태와 판단. 환경 값이 필요해서 `.task` 에서 만든다.
    @State private var session: QuizSession?

    /// 문제 낭독 도우미.
    @State private var speaker = SpeechReader()

    var body: some View {
        Group {
            if let session, !session.isEmpty {
                screen(for: session)
            } else {
                // 회차를 준비하는 아주 짧은 순간, 또는 문제집이 비어 있을 때.
                ProgressView()
            }
        }
        .sheet(
            isPresented: Binding(
                get: { session?.feedback != nil },
                set: { _ in }
            )
        ) {
            if let session, let feedback = session.feedback {
                FeedbackSheet(feedback: feedback) {
                    session.dismissFeedback()
                }
            }
        }
        .background(Color.white)
        .task { prepareSession() }
    }

    // MARK: - 어느 화면을 보여줄까

    @ViewBuilder
    private func screen(for session: QuizSession) -> some View {
        if session.isGrading {
            GradingScreen()
        } else if session.isFinished {
            ResultScreen(
                session: session,
                onRestart: { restart(session) },
                onEraseProgress: { erase(session) }
            )
        } else {
            QuestionScreen(session: session, sessionMode: sessionMode) {
                readAloud(session.current)
            }
            // 문제가 넘어가면 새 지문을 자동으로 읽어준다.
            // QuestionScreen 에 붙였으므로 회차가 끝난 뒤에는 울리지 않는다.
            .onChange(of: session.currentIndex) { _, _ in
                readAloud(session.current)
            }
        }
    }

    // MARK: - 회차 준비

    /// 첫 진입에 회차를 만든다. 이미 있으면 아무것도 하지 않는다.
    private func prepareSession() {
        guard session == nil else { return }

        let newSession = QuizSession(catalog: catalog, modelContext: modelContext)
        newSession.start()
        session = newSession

        readAloud(newSession.current)   // 첫 문제도 자동으로 읽어준다
    }

    /// 새 회차를 시작한다. (결과 화면의 "다시 풀기")
    private func restart(_ session: QuizSession) {
        session.start()
        readAloud(session.current)
    }

    /// 학습 기록을 모두 지우고 새 회차를 시작한다. (결과 화면의 "학습 기록 초기화")
    private func erase(_ session: QuizSession) {
        session.eraseAllProgress()
        readAloud(session.current)
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
        .environment(QuestionCatalog.bundled())
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self], inMemory: true)
}
