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

    private let grader = AnswerGrader()

    /// 이번 세션 문제 수
    private let sessionSize = 5

    // MARK: 색상 (고대비 — 흰 배경에서 또렷하게)
    private let correctGreen = Color(red: 0.12, green: 0.52, blue: 0.30)
    private let reviewBlue = Color(red: 0.10, green: 0.40, blue: 0.72)
    private let masterOrange = Color(red: 0.80, green: 0.46, blue: 0.08)
    private let textMuted = Color(red: 0.26, green: 0.26, blue: 0.28)   // 진한 회색 (연회색 금지)

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
    }

    // MARK: - 문제 풀이 화면

    private var questionView: some View {
        let item = quiz[currentIndex]

        return VStack(spacing: 0) {
            // 진행 상황 + 현재 모드 표시
            HStack {
                Text("문제 \(currentIndex + 1) / \(quiz.count)")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(item.mode.title)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.08), in: Capsule())
            }
            .foregroundStyle(.black)

            ProgressView(value: Double(currentIndex), total: Double(quiz.count))
                .tint(.black)
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 24) {
                    Text(item.question.question)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.top, 32)

                    // 문제 읽어주기 버튼
                    Button {
                        speaker.speak(item.question.question)
                    } label: {
                        Label("문제 읽어주기", systemImage: "speaker.wave.2.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    inputArea(for: item)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 24)
            }

            // 다음/제출 버튼
            Button {
                submit()
            } label: {
                Text(currentIndex == quiz.count - 1 ? "제출" : "다음  →")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(isAnswerEmpty ? Color.gray : Color.black,
                                in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isAnswerEmpty)
        }
        .padding(24)
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
        case .trueFalse(let shownAnswer, _):
            VStack(spacing: 20) {
                Text("제시된 답: \(shownAnswer)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                HStack(spacing: 14) {
                    choiceButton(PracticeGrader.trueLabel, isSelected: userAnswer == PracticeGrader.trueLabel)
                    choiceButton(PracticeGrader.falseLabel, isSelected: userAnswer == PracticeGrader.falseLabel)
                }
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

    /// 탭하면 선택되는 큰 보기/OX 버튼. (고대비 미니멀)
    private func choiceButton(_ label: String, isSelected: Bool) -> some View {
        Button {
            userAnswer = label
        } label: {
            Text(label)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(isSelected ? Color.black : Color.white,
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 채점 중 화면

    private var gradingView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(correctGreen.opacity(0.12))
                    .frame(width: 120, height: 120)
                ProgressView()
                    .controlSize(.large)
                    .tint(correctGreen)
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

            // 누적 정답 강조 카드 (진초록 배경 · 흰 글씨)
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
            .background(correctGreen, in: RoundedRectangle(cornerRadius: 24))

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
                    .background(.black, in: RoundedRectangle(cornerRadius: 14))
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

            Text(item.question.question)
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
        for question in Question.all where byID[question.id] == nil {
            let progress = QuestionProgress(questionID: question.id)
            modelContext.insert(progress)
            byID[question.id] = progress
        }

        quiz = SessionBuilder().build(size: sessionSize, progressByID: byID)
        currentIndex = 0
        userAnswer = ""
        submittedAnswers = [:]
        results = [:]
    }

    /// 학습 기록(진척)을 모두 지우고 처음부터 다시 시작한다.
    private func resetProgress() {
        try? modelContext.delete(model: QuestionProgress.self)
        try? modelContext.save()

        // @Query가 즉시 갱신되지 않을 수 있으므로, 새 진척을 직접 만들어 세션을 구성한다.
        var byID: [Int: QuestionProgress] = [:]
        for question in Question.all {
            let progress = QuestionProgress(questionID: question.id)
            modelContext.insert(progress)
            byID[question.id] = progress
        }
        try? modelContext.save()

        quiz = SessionBuilder().build(size: sessionSize, progressByID: byID)
        currentIndex = 0
        userAnswer = ""
        submittedAnswers = [:]
        results = [:]
    }

    /// 현재 답을 기록하고 다음 문제로 넘어간다. 마지막 문제면 채점을 시작한다.
    private func submit() {
        let item = quiz[currentIndex]
        let trimmed = userAnswer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        submittedAnswers[item.id] = trimmed
        userAnswer = ""
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
        .modelContainer(for: QuestionProgress.self, inMemory: true)
}
