//
//  QuestionScreen.swift
//  KCT
//
//  역할 : 문제 하나를 크게 보여주고 답을 받는 화면
//  요점 : 질문이 화면의 유일한 주인공이다. 나머지는 모두 작고 차분하게 둔다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuestionScreen               한 문제를 그리는 화면. 판단은 하지 않는다
//  ├─ header(for:)              진행 막대 + "다시 읽기"
//  ├─ questionArea(for:)        지문(KoreanText) + 행동 안내 한 줄 + 입력 영역
//  ├─ inputArea(for:)           모드에 따라 보기 · O/X · 직접입력 중 하나
//  ├─ hintBanner                답 없이 다음을 눌렀을 때의 안내
//  ├─ nextButton                다음 / 제출
//  └─ showAnswerHint()          안내 표시 + 진동 (진동은 화면의 몫)
//
//  ── 흐름 ──────────────────────────────────────────────
//  session.current 를 받아 그린다
//    → 사용자가 보기 탭 → session.userAnswer 에 대입 (안내는 session 이 스스로 거둔다)
//    → "다음" 탭
//        ├─ 답이 있으면  → session.submitCurrent()
//        └─ 답이 없으면  → session.requestAnswerHint() + 진동
//    → "다시 읽기" 탭 → onReadAloud() 로 위(QuizView)에 부탁한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView
//  기대는 것    : QuizSession(상태·판단), KoreanText·ChoiceButton·PrimaryActionButton
//                ·SessionProgressBar(표현), SessionMode(형광펜 여부)
//  건드리지 않는 것 : 채점과 낭독 — 정답 여부는 QuizSession 이, 소리는 QuizView 가 맡는다
//

import SwiftUI

/// 문제 하나를 보여주고 답을 받는 화면.
///
/// 이 화면은 **무엇이 정답인지 모릅니다.** 고른 값을 ``QuizSession/userAnswer`` 에
/// 넘기고, 판정은 회차가 끝난 뒤 세션이 합니다. 덕분에 채점 규칙이 바뀌어도
/// 이 파일은 그대로입니다.
struct QuestionScreen: View {
    /// 회차의 상태. `TextField` 에 묶기 위해 `@Bindable` 로 받는다.
    @Bindable var session: QuizSession

    /// 연습인지 실전인지. 실전에서는 형광펜 같은 도움 장치를 끈다.
    let sessionMode: SessionMode

    /// 지문을 다시 읽어 달라는 부탁. 소리는 위쪽(``QuizView``)이 맡는다.
    let onReadAloud: () -> Void

    var body: some View {
        if let item = session.current {
            content(for: item)
        }
    }

    private func content(for item: QuizItem) -> some View {
        VStack(spacing: 0) {
            header(for: item)
            questionArea(for: item)

            if session.needsAnswerHint {
                hintBanner
            }

            nextButton
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.2), value: session.needsAnswerHint)
    }

    // MARK: - 상단 (진행 상황 + 다시 읽기)

    /// 문제 유형은 표기하지 않는다. 무엇을 해야 하는지는 보기 위의 한 줄 안내가 담당한다.
    private func header(for item: QuizItem) -> some View {
        HStack(spacing: 16) {
            SessionProgressBar(total: session.items.count, currentIndex: session.currentIndex)

            // 읽기 흐름을 끊지 않도록 지문 위쪽에 둔다.
            // 보조 행동이므로 같은 색 계열이되 채우지 않아 주 행동보다 가볍게.
            Button(action: onReadAloud) {
                Label("다시 읽기", systemImage: "speaker.wave.2.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.signature)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppColor.secondaryBackground, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 지문과 입력

    private func questionArea(for item: QuizItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 지문: 왼쪽 정렬 + 한글 단어 단위 줄바꿈.
                // O/X 는 진술문을 보여주고, 판단 대상인 답을 시그니처 색으로 강조한다.
                KoreanText(
                    text: item.displayText,
                    font: .systemFont(ofSize: 30, weight: .bold),
                    highlight: item.highlightText,
                    marker: sessionMode.showsFocusHighlight ? item.markerText : nil
                )
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 12) {
                    // 보기 묶음의 라벨 역할이라 작고 차분하게 둔다.
                    Text(item.actionGuide)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AppColor.textMuted)

                    inputArea(for: item)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 24)
        }
    }

    /// 묻는 방식에 따라 입력 수단을 고른다.
    @ViewBuilder
    private func inputArea(for item: QuizItem) -> some View {
        switch item.payload {
        case .choices(let options, _):
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    ChoiceButton(label: option, isSelected: session.userAnswer == option) {
                        session.userAnswer = option
                    }
                }
            }

        case .trueFalse:
            // 판단 대상(진술문)은 이미 지문에 있으므로 버튼만 둔다.
            HStack(spacing: 14) {
                trueFalseButton(RuleGrader.trueLabel)
                trueFalseButton(RuleGrader.falseLabel)
            }

        case .freeText:
            freeTextField
        }
    }

    private func trueFalseButton(_ label: String) -> some View {
        ChoiceButton(label: label, isSelected: session.userAnswer == label) {
            session.userAnswer = label
        }
    }

    private var freeTextField: some View {
        ZStack {
            // 기본 placeholder 가 연회색이라 흐려서, 진한 커스텀 placeholder 를 얹는다.
            if session.userAnswer.isEmpty {
                Text("답을 입력하세요")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColor.textMuted)
            }
            TextField("", text: $session.userAnswer)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .onSubmit { session.submitCurrent() }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.black, lineWidth: 1.5)
        )
    }

    // MARK: - 하단 (안내 + 다음)

    private var hintBanner: some View {
        Text("문제를 고르면 다음으로 갈 수 있어요.")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.black, in: Capsule())
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var nextButton: some View {
        PrimaryActionButton(
            title: session.isLastQuestion ? "제출" : "다음  →",
            isReady: session.hasAnswer
        ) {
            if session.hasAnswer {
                session.submitCurrent()
            } else {
                showAnswerHint()
            }
        }
    }

    /// 답을 고르라고 알린다. 눈(안내)과 몸(진동) 두 가지로 전한다.
    private func showAnswerHint() {
        session.requestAnswerHint()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
