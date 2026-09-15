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
    
    /// 시트에 띄울 낱말 하나. 이 값이 있으면 시트가 열리고, nil이면 닫힌다.
    ///
    /// - Note: `openGlossary`(내용)와 `isGlossaryPresented`(열림 여부)를 따로 두면,
    ///   이번 화면에서 시트가 처음 만들어지는 순간 내용이 아직 `nil`인 채로 한 번
    ///   그려질 수 있다 — 그러면 `.presentationDetents`를 가진 뷰가 없어 iOS가
    ///   기본값인 큰 화면으로 연다. 값 하나로 합치고 `.sheet(item:)`을 쓰면 이 틈이
    ///   사라진다 (9차 계획 4-A).
    ///
    /// - Important: `id`를 낱말마다 다르게(예: `UUID()`를 매번 새로) 두면 안 된다.
    ///   시트가 뒤 배경을 계속 탭할 수 있게 두면서(`.presentationBackgroundInteraction`),
    ///   열려 있는 동안 **다른 낱말을 또 탭하는 경로**가 생겼다. 그때 `id`가 바뀌면
    ///   SwiftUI는 "다른 항목"으로 보고 지금 시트를 닫았다가 새로 여는데, 그 새로 여는
    ///   순간이 처음 열 때와 같은 조건이라 다시 크게 뜬다(4-A와 같은 원인). `id`를
    ///   항상 같은 값으로 고정하면 내용만 그 자리에서 바뀌고, 시트는 다시 열리지 않는다.
    ///
    /// - Note: 답을 고르거나, "다시 읽기"를 누르거나, 배경(지문·여백)을 탭하면
    ///   ``dismissGlossaryIfNeeded()``가 이 값을 nil로 되돌려 시트를 닫는다 —
    ///   "낱말이 아닌 다른 걸 하겠다"는 뜻으로 본다. 아래로 쓸어내려 닫는 기본
    ///   동작(iOS 가 대신 처리)도 그대로 된다.
    private struct GlossarySelection: Identifiable {
        let id = "glossary"
        let word: String
        let gloss: String
        let examples: [String]
    }

    @State private var glossarySelection: GlossarySelection?
    /// 6단계 생성 예문의 진행 상태. `GlossaryPanel`이 로딩 중/완성/불가를 구분해서 보여준다.
    @State private var exampleState: GlossaryExampleState = .unavailable
    /// 낱말을 탭할 때마다 하나씩 올라간다. 배경 탭으로 시트를 닫는 처리와, 낱말 탭으로
    /// 시트를 여는/바꾸는 처리가 **같은 손가락 탭 한 번**에서 동시에 걸릴 수 있어서
    /// (KoreanText 는 UIKit `UITapGestureRecognizer`를 직접 쓰고, 배경 탭은 SwiftUI
    /// `.onTapGesture`를 쓴다 — 이 둘 사이의 발생 순서는 iOS가 보장하지 않는다) 필요하다.
    /// 아래 `dismissGlossaryIfNeeded()`가 배경 탭에서는 이 값을 한 번 저장해 두고, 다음
    /// 실행 루프 틱에서 값이 그대로면 진짜 배경 탭으로 보고 닫는다 — 그 사이 낱말 탭이
    /// 끼어들어 값이 바뀌었으면 낱말 탭이 이긴 것으로 보고 닫지 않는다.
    @State private var glossaryOpenToken = 0
    
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

    // MARK: - 상단 (진행 상황 + 다시 읽기)

    /// 문제 유형은 표기하지 않는다. 무엇을 해야 하는지는 보기 위의 한 줄 안내가 담당한다.
    private func header(for item: QuizItem) -> some View {
        HStack(spacing: 16) {
            SessionProgressBar(total: session.items.count, currentIndex: session.currentIndex)

            // 읽기 흐름을 끊지 않도록 지문 위쪽에 둔다.
            // 보조 행동이므로 같은 색 계열이되 채우지 않아 주 행동보다 가볍게.
            Button(action: {
                dismissGlossaryIfNeeded()
                onReadAloud()
            }) {
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
        // 낱말 사전 시트가 열려 있을 때 배경(지문·여백)을 탭하면 닫는다. contentShape 로
        // 빈 여백까지 탭 판정 범위에 넣는다 — 버튼·보기·텍스트필드 같은 자식 뷰는 원래
        // 자기 탭을 먼저 가져가므로 이 제스처와 부딪히지 않는다.
        .contentShape(Rectangle())
        .onTapGesture {
            dismissGlossaryFromBackgroundTap()
        }
        .animation(.easeInOut(duration: 0.2), value: session.needsAnswerHint)
        // 답을 고르는 것도 "낱말이 아닌 다른 걸 하겠다"는 신호라 시트를 닫는다.
        .onChange(of: session.userAnswer) { _, _ in
            dismissGlossaryIfNeeded()
        }
        .sheet(item: $glossarySelection) { selection in
            GlossaryPanel(
                word: selection.word, gloss: selection.gloss,
                exampleState: exampleState,
                relatedWords: selection.examples
            )
        }
    }

    /// 낱말 사전 시트가 열려 있으면 닫는다. 답을 고르거나, 다시 읽기를 눌렀을 때는
    /// 그 자리에서 바로 닫는다 — 각각 자기 버튼의 탭이라 낱말 탭과 겹칠 일이 없다.
    private func dismissGlossaryIfNeeded() {
        guard glossarySelection != nil else { return }
        glossarySelection = nil
    }

    /// 배경(지문·여백)을 탭했을 때 부른다. 같은 탭이 KoreanText 의 낱말 탭과 겹쳐
    /// 들어올 수 있어(위 `glossaryOpenToken` 설명 참고) 바로 닫지 않고, 한 틱 뒤에
    /// 토큰이 그대로인지 보고 진짜 배경 탭일 때만 닫는다.
    private func dismissGlossaryFromBackgroundTap() {
        guard glossarySelection != nil else { return }
        let tokenAtTap = glossaryOpenToken
        DispatchQueue.main.async {
            guard glossaryOpenToken == tokenAtTap else { return }
            dismissGlossaryIfNeeded()
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
                    marker: sessionMode.showsFocusHighlight ? item.markerText : nil,
                    // 사전 시트가 열려 있는 낱말만 배경색을 칠한다. 시트가 닫히면
                    // glossarySelection 이 nil이 되어 이 값도 nil이 되고, 배경도 함께 사라진다.
                    selectedWord: glossarySelection?.word,
                    glossary: item.glossary,
                    onTapWord: { entry in
                        // 배경 탭 닫기 처리와 경합하지 않도록, 낱말 탭이 일어났다는
                        // 사실을 먼저 표시해 둔다 — dismissGlossaryIfNeeded() 설명 참고.
                        glossaryOpenToken += 1
                        exampleState = .loading
                        glossarySelection = GlossarySelection(
                            word: entry.word,
                            gloss: entry.gloss,
                            examples: entry.examples
                        )
                        Task {
                            // 6단계: text 가 nil 이면 "기기 미지원" 또는 "생성 실패"(세이프티
                            // 가드레일 포함) — 화면에는 둘 다 unavailable 로 합쳐 보여준다.
                            // 실패(writing.failure)는 QuizSession 에 넘겨 model_failure 표로
                            // 올라가게 한다 — 어떤 프롬프트가 걸렸는지는 거기서 되짚는다.
                            // "기리다"처럼 모델이 활용형을 헷갈리는 낱말은 questions.json 의
                            // referenceSentence 에 사람이 미리 써 둔 예문이 있으면 그걸 참고
                            // 시킨다 — 대부분은 없어(nil) 모델이 그대로 알아서 만든다.
                            let referenceSentence = entry.referenceSentence

                            let writing = await composeExample(
                                word: entry.word,
                                gloss: entry.gloss,
                                relatedWords: entry.examples,
                                referenceSentence: referenceSentence,
                                questionText: item.displayText,
                                questionID: item.id
                            )
                            // 이미 펼쳐 본 상태(showsExample)라면 로딩 문구에서 실제 예문으로
                            // 부드럽게 바뀌도록 애니메이션을 준다.
                            withAnimation(.easeOut(duration: 0.25)) {
                                exampleState = writing.text.map(GlossaryExampleState.ready) ?? .unavailable
                            }
                            session.saveFailures([writing.failure])
                            // 회차가 끝나거나 새로 시작할 때까지 기다리지 않고 바로
                            // 올려 본다 — 낱말 사전 실패는 자주 있는 일이 아니라서,
                            // 회차 경계를 기다리게 두면 언제 확인될지 알기 어렵다.
                            if writing.failure != nil {
                                session.uploadFailuresNow()
                            }
                        }
                    }
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
                Text("터치하여 입력")
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
            title: session.isGrading
                ? "채점 중이에요"
                : (session.isLastQuestion ? "제출" : "다음  →"),
            isReady: session.hasAnswer && !session.isGrading
        ) {
            if session.isGrading { return }

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
