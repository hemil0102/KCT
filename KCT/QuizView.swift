//
//  QuizView.swift
//  KCT
//
//  퀴즈 진행 화면.
//  - 진척 기반 출제: 처음엔 전부 2지선다, 맞히면 다음 세션에서 승급.
//  - 디자인: 큰 글씨 · 고대비 미니멀 (70대 어르신 친화) + 문제 낭독.
//  - 채점 화면: "틀렸다" 표현 없이 맞힌 것을 칭찬하고 누적 정답 수를 강조. (고대비 카드)
//

import SwiftUI
import SwiftData

struct QuizView: View {
    /// 이번 세션의 성격. 실전 모드에서는 형광펜 같은 도움 장치를 끈다.
    var sessionMode: SessionMode = .practice

    /// 출제할 문제집. (번들 JSON → 나중에 서버에서 교체)
    @Environment(QuestionCatalog.self) private var catalog

    @Environment(\.modelContext) private var modelContext
    /// 문제별 학습 진척. (SwiftData에서 로드)
    @Query private var progresses: [QuestionProgress]

    /// 이번 세션의 출제 항목. `startSession()`에서 진척을 반영해 구성한다.
    @State private var quiz: [PracticeItem] = []

    /// 현재 몇 번째 문제를 풀고 있는지 (0부터 시작)
    @State private var currentIndex = 0

    /// 현재 문제에 입력/선택 중인 답
    @State private var userAnswer = ""

    /// 사용자가 제출한 답 기록 (문제 id → 답)
    @State private var submittedAnswers: [Int: String] = [:]

    /// 채점 결과 (문제 id → 결과)
    @State private var results: [Int: GradingResult] = [:]

    /// 채점이 진행 중인지 여부
    @State private var isGrading = false

    /// 문제 낭독 도우미
    @State private var speaker = SpeechReader()

    /// 기록 초기화 확인창 표시 여부
    @State private var showResetConfirm = false

    /// "답을 고르세요" 안내 표시 여부. (답을 고르면 사라진다)
    @State private var showsAnswerHint = false

    /// 백그라운드 분석 작업. 세션이 바뀌면 취소한다.
    @State private var focusWarmingTask: Task<Void, Never>?

    private let grader = AnswerGrader()

    /// 이번 세션 문제 수
    private let sessionSize = 5

    // MARK: 색상 (시그니처 #745CF4 기준 · 흰 배경에서 또렷하게)
    private let signature = AppColor.signature
    private let correctGreen = AppColor.correct
    private let reviewBlue = AppColor.review
    private let masterOrange = AppColor.mastered
    private let textMuted = AppColor.textMuted

    /// 모든 문제를 다 풀었는지 여부
    private var isFinished: Bool { !quiz.isEmpty && currentIndex >= quiz.count }

    /// 이번 세션에서 맞힌 문제 개수
    private var correctCount: Int {
        results.values.filter { $0.isCorrect }.count
    }

    /// 지금까지(모든 세션 누적) 맞힌 총 횟수
    private var cumulativeCorrect: Int {
        progresses.reduce(0) { $0 + $1.totalCorrect }
    }

    /// 완전히 익힌(마스터한) 문제 개수
    private var masteredCount: Int {
        progresses.filter(\.isMastered).count
    }

    /// 현재 입력/선택이 비어 있는지
    private var isAnswerEmpty: Bool {
        userAnswer.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 하단 버튼 문구. (무엇을 해야 하는지는 지문 위 안내가 담당한다)
    private var nextButtonTitle: String {
        currentIndex == quiz.count - 1 ? "제출" : "다음  →"
    }

    var body: some View {
        Group {
            if quiz.isEmpty {
                ProgressView()
            } else if isFinished {
                if isGrading {
                    gradingView
                } else {
                    resultView
                }
            } else {
                questionView
            }
        }
        .background(Color.white)
        .onAppear {
            if quiz.isEmpty { startSession() }
        }
        // 문제에 진입하면 지문을 자동으로 읽어준다.
        .onChange(of: currentIndex) { _, _ in
            speakCurrentQuestion()
        }
    }

    /// 현재 문제의 지문을 소리 내어 읽는다. (다 풀었으면 읽지 않음)
    private func speakCurrentQuestion() {
        guard !quiz.isEmpty, currentIndex < quiz.count else { return }
        speaker.speak(quiz[currentIndex].displayText)
    }

    // MARK: - 문제 풀이 화면

    private var questionView: some View {
        let item = quiz[currentIndex]

        return VStack(spacing: 0) {
            // 진행 상황 + 다시 읽기. (문제 유형은 표기하지 않는다)
            HStack(spacing: 16) {
                progressBar

                // 읽기 흐름을 끊지 않도록 지문 위쪽에 둔다.
                Button {
                    speaker.speak(item.displayText)
                } label: {
                    // 보조 행동: 같은 알약·같은 색 계열이되 채우지 않아 주 행동보다 가볍게.
                    Label("다시 읽기", systemImage: "speaker.wave.2.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(signature)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppColor.secondaryBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 지문: 왼쪽 정렬 + 한글 단어 단위 줄바꿈
                    // (O/X는 진술문을 보여주고, 판단 대상인 답을 시그니처 색으로 강조한다)
                    KoreanText(
                        text: item.displayText,
                        font: .systemFont(ofSize: 30, weight: .bold),
                        highlight: item.highlightText,
                        marker: sessionMode.showsFocusHighlight ? item.markerText : nil
                    )
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 12) {
                        // 무엇을 해야 하는지 알려 주는 한 줄 안내.
                        // 보기 묶음의 라벨 역할이라 작고 차분하게 둔다.
                        Text(item.actionGuide)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(textMuted)

                        inputArea(for: item)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 24)
            }

            // 아직 답을 고르지 않고 다음을 누른 경우의 안내. (답을 고르면 사라진다)
            if showsAnswerHint {
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

            // 다음/제출 버튼. 비활성처럼 보이지만 눌리며, 답이 없으면 안내를 띄운다.
            Button {
                if isAnswerEmpty {
                    showAnswerHint()
                } else {
                    submit()
                }
            } label: {
                Text(nextButtonTitle)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(isAnswerEmpty ? AppColor.disabledText : .white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(isAnswerEmpty ? AppColor.disabledBackground : signature,
                                in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.2), value: showsAnswerHint)
        // 답을 고르면 안내를 거둔다.
        .onChange(of: userAnswer) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                showsAnswerHint = false
            }
        }
    }

    /// 답을 고르라는 안내를 띄운다. (진동으로도 알려 준다)
    private func showAnswerHint() {
        showsAnswerHint = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// 진행 막대. 문제 수만큼 칸을 나눠, 숫자 없이도 전체 개수와 현재 위치를 함께 보여준다.
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(quiz.count, 1), id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? signature : AppColor.softBackground)
            }
        }
        .frame(height: 14)
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    /// 모드별 입력 영역.
    @ViewBuilder
    private func inputArea(for item: PracticeItem) -> some View {
        switch item.payload {
        case .choices(let options, _):
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    choiceButton(option, isSelected: userAnswer == option)
                }
            }
        case .trueFalse:
            // 판단 대상(진술문)은 위 본문에 이미 있으므로 버튼만 둔다.
            HStack(spacing: 14) {
                choiceButton(PracticeGrader.trueLabel, isSelected: userAnswer == PracticeGrader.trueLabel)
                choiceButton(PracticeGrader.falseLabel, isSelected: userAnswer == PracticeGrader.falseLabel)
            }
        case .freeText:
            ZStack {
                // 기본 placeholder가 연회색이라 흐려서, 진한 커스텀 placeholder를 얹는다.
                if userAnswer.isEmpty {
                    Text("답을 입력하세요")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(textMuted)
                }
                TextField("", text: $userAnswer)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .onSubmit(submit)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black, lineWidth: 1.5)
            )
        }
    }

    /// 탭하면 선택되는 큰 보기/OX 버튼.
    ///
    /// 선택은 "상태"이므로 옅은 배경 + 굵은 테두리 + 체크로 표시하고,
    /// 꽉 채운 시그니처 색은 "다음" 버튼(행동)에만 쓴다.
    private func choiceButton(_ label: String, isSelected: Bool) -> some View {
        Button {
            userAnswer = label
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? signature : Color.black.opacity(0.3))

                Text(label)
                    .font(.system(size: 22, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(isSelected ? AppColor.softBackground : Color.white,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? signature : Color.black.opacity(0.35),
                            lineWidth: isSelected ? 3 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 채점 중 화면

    private var gradingView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(AppColor.softBackground)
                    .frame(width: 120, height: 120)
                ProgressView()
                    .controlSize(.large)
                    .tint(signature)
                    .scaleEffect(1.6)
            }

            VStack(spacing: 8) {
                Text("채점 중이에요")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                Text("잠시만 기다려 주세요")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - 결과 화면 (맞힌 것을 칭찬, 누적 정답 강조 · 고대비 카드)

    private var resultView: some View {
        VStack(spacing: 20) {
            Text("잘하셨어요! 🎉")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.black)

            // 누적 정답 강조 카드 (시그니처 배경 · 흰 글씨)
            VStack(spacing: 6) {
                Text("지금까지 맞힌 문제")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(cumulativeCorrect)개")
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundStyle(.white)
                Text("오늘 \(quiz.count)문제 중 \(correctCount)개 맞혔어요")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(signature, in: RoundedRectangle(cornerRadius: 24))

            if masteredCount > 0 {
                Label("완전히 익힌 문제 \(masteredCount)개", systemImage: "star.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(masterOrange, in: Capsule())
            }

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(quiz) { item in
                        resultRow(for: item)
                    }
                }
            }

            Button {
                startSession()
            } label: {
                Text("다시 풀기")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(signature, in: Capsule())
            }
            .buttonStyle(.plain)

            // 학습 기록 초기화 (실수 방지를 위해 확인창을 거친다)
            Button("학습 기록 초기화") {
                showResetConfirm = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(textMuted)
            .confirmationDialog(
                "학습 기록을 모두 지울까요?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("모두 초기화", role: .destructive) { resetProgress() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("지금까지 맞힌 기록과 난이도가 모두 처음으로 돌아갑니다.")
            }
        }
        .padding(24)
    }

    /// 문제 하나에 대한 결과 카드. 맞히면 칭찬, 아니면 "다시 볼 문제"로 부드럽게.
    private func resultRow(for item: PracticeItem) -> some View {
        let isCorrect = results[item.id]?.isCorrect ?? false
        let isMastered = progress(for: item.id)?.isMastered == true
        let accent = isCorrect ? correctGreen : reviewBlue

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
                Text(isCorrect ? "정답!" : "다시 볼 문제")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                Spacer()
                if isMastered {
                    Label("완전히 익힘", systemImage: "star.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(masterOrange)
                }
            }

            Text(item.displayText)
                .font(.body.weight(.semibold))
                .foregroundStyle(.black)

            if isCorrect {
                Text("잘 맞히셨어요! 👍")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(correctGreen)
            } else {
                Text("정답: \(item.question.answer)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                Text("곧 다시 만나요 😊")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 동작

    /// 진척을 반영해 이번 세션을 구성한다. (없는 문제는 진척을 새로 만든다)
    private func startSession() {
        var byID = Dictionary(progresses.map { ($0.questionID, $0) }, uniquingKeysWith: { first, _ in first })
        for question in catalog.questions where byID[question.id] == nil {
            let progress = QuestionProgress(questionID: question.id)
            modelContext.insert(progress)
            byID[question.id] = progress
        }

        let store = FocusStore(modelContext: modelContext)
        quiz = SessionBuilder(catalog: catalog).build(
            size: sessionSize,
            progressByID: byID,
            focusByID: store.focuses(for: catalog.questions)
        )
        currentIndex = 0
        userAnswer = ""
        submittedAnswers = [:]
        results = [:]
        speakCurrentQuestion()   // 첫 문제도 자동으로 읽어준다

        // 어머니가 문제를 푸는 동안, 아직 분석하지 않은 문제를 뒤에서 채워 둔다.
        warmFocusCache()
    }

    /// 백그라운드로 묻는 대상을 분석해 캐시에 채운다. (화면을 막지 않는다)
    private func warmFocusCache() {
        focusWarmingTask?.cancel()
        let store = FocusStore(modelContext: modelContext)
        let questions = catalog.questions
        focusWarmingTask = Task {
            await store.analyzeMissing(in: questions)
        }
    }

    /// 학습 기록(진척)을 모두 지우고 처음부터 다시 시작한다.
    private func resetProgress() {
        try? modelContext.delete(model: QuestionProgress.self)
        try? modelContext.save()

        // @Query가 즉시 갱신되지 않을 수 있으므로, 새 진척을 직접 만들어 세션을 구성한다.
        var byID: [Int: QuestionProgress] = [:]
        for question in catalog.questions {
            let progress = QuestionProgress(questionID: question.id)
            modelContext.insert(progress)
            byID[question.id] = progress
        }
        try? modelContext.save()

        quiz = SessionBuilder(catalog: catalog).build(size: sessionSize, progressByID: byID)
        currentIndex = 0
        userAnswer = ""
        submittedAnswers = [:]
        results = [:]
        speakCurrentQuestion()
    }

    /// 현재 답을 기록하고 다음 문제로 넘어간다. 마지막 문제면 채점을 시작한다.
    private func submit() {
        let item = quiz[currentIndex]
        let trimmed = userAnswer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        submittedAnswers[item.id] = trimmed
        userAnswer = ""
        showsAnswerHint = false
        currentIndex += 1

        if isFinished {
            Task { await gradeAll() }
        }
    }

    /// 제출된 답들을 채점하고, 결과를 진척에 반영한다.
    /// 선다·O/X는 즉시 비교, 직접입력은 모델로 채점.
    private func gradeAll() async {
        isGrading = true
        defer { isGrading = false }

        let byID = Dictionary(progresses.map { ($0.questionID, $0) }, uniquingKeysWith: { first, _ in first })

        for item in quiz {
            let answer = submittedAnswers[item.id] ?? ""
            let isCorrect: Bool

            if let deterministic = PracticeGrader.grade(item, userAnswer: answer) {
                isCorrect = deterministic
                results[item.id] = GradingResult(isCorrect: deterministic, reason: "")
            } else {
                do {
                    let result = try await grader.grade(question: item.question, userAnswer: answer)
                    isCorrect = result.isCorrect
                    results[item.id] = result
                } catch {
                    // 채점 실패 시 조용히 오답 처리 (부정적 표현은 화면에 노출하지 않음)
                    isCorrect = false
                    results[item.id] = GradingResult(isCorrect: false, reason: "")
                }
            }

            if item.affectsProgress, let progress = byID[item.id] {
                progress.record(correct: isCorrect)
            }
        }

        try? modelContext.save()
    }

    private func progress(for id: Int) -> QuestionProgress? {
        progresses.first { $0.questionID == id }
    }
}

#Preview {
    QuizView()
        .environment(QuestionCatalog.bundled())
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self], inMemory: true)
}
