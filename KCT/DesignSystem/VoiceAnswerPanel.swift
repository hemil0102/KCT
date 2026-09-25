//
//  VoiceAnswerPanel.swift
//  KCT
//
//  역할 : 음성 입력 문제의 입력 영역 — 답 칸 · 마이크 버튼 · 파형 · 안내 한 줄
//  요점 : 키보드는 없다. 답 칸은 눌러도 아무 일이 없고, 말한 글자만 키보드로 친 것처럼 찍힌다.
//        말이 끝나면 곧바로 제출된다 — 「다음」을 누를 필요가 없다(O/X·2지선다와 같은 흐름)
//
//  ── 구성 ──────────────────────────────────────────────
//  VoiceAnswerPanel
//  ├─ answer / hints / isLocked    위(QuestionScreen)에서 받는 것 — 지금 답 · 인식 도움말 · 잠금
//  ├─ onTranscript / onFinished    위로 알리는 것 — 글자가 바뀔 때 · 말이 끝났을 때
//  ├─ listener                     SpeechListener — 실제로 듣는 부품
//  ├─ didHearNothing               방금 눌렀는데 아무 말도 못 알아들었나
//  ├─ answerBox                    말한 글자가 찍히는 칸 (안내 문구 없음, 눌러도 반응 없음)
//  ├─ micButton                    microphone.circle.fill — 누르면 듣기, 듣는 중 다시 누르면 끝
//  ├─ BandBars                     마이크 아래 파형 — 대역별 막대가 제자리에서 솟았다 사라진다
//  └─ statusText                   안내 한 줄 (눌러서 말씀해 주세요 / 듣고 있어요… / 못 들었어요 …)
//
//  ── 흐름 ──────────────────────────────────────────────
//  마이크 탭 → toggle()
//    → 답 칸을 비우고 listener.start(hints:onFinish:)
//    → 듣는 동안 listener.transcript 가 바뀔 때마다 onTranscript → session.userAnswer (답 칸에 찍힘)
//    → listener.bands 가 바뀔 때마다 BandBars 가 막대 높이를 바꾼다
//    → 말이 끝나면(1.5초 조용) onFinish(글자)
//        ├─ 글자가 있으면 → onFinished → QuestionScreen.submitAnswer() → 채점 → 정답/오답 해설 창
//        └─ 빈 글자면    → didHearNothing = true → "잘 못 들었어요. 다시 눌러 말씀해 주세요"
//    → 화면이 사라지면(다음 문제) listener.cancel()
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen.inputArea(for:) — item.isVoice 인 직접입력 칸
//  기대는 것    : SpeechListener, AppColor
//  건드리지 않는 것 : 채점 — 글자만 위로 넘긴다
//

import SwiftUI

/// 음성 입력 칸. 답 칸 + 가운데 마이크 + 그 아래 파형 + 안내 한 줄.
struct VoiceAnswerPanel: View {
    /// 지금 답 칸에 보일 글자 (session.userAnswer).
    let answer: String

    /// 인식기에 미리 알려 줄 정답 표기들. ``SpeechListener/start(hints:onFinish:)`` 참고.
    let hints: [String]

    /// 채점 중이거나 해설 창이 떠 있으면 마이크를 막는다.
    let isLocked: Bool

    /// 알아들은 글자가 바뀔 때마다 부른다 — 답 칸에 키보드처럼 찍히게.
    let onTranscript: (String) -> Void

    /// 말이 끝났고 글자가 있을 때 한 번 부른다 — 제출.
    let onFinished: (String) -> Void

    @State private var listener = SpeechListener()

    /// 방금 들었는데 아무것도 못 알아들었나.
    @State private var didHearNothing = false

    /// 마이크 아이콘 지름.
    private static let micSize: CGFloat = 96

    /// 파형 영역 높이.
    private static let waveHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 18) {
            answerBox

            micButton
                .padding(.top, 12)

            BandBars(levels: listener.bands, height: Self.waveHeight)
                .opacity(listener.phase == .listening ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: listener.phase)

            Text(statusText)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .onChange(of: listener.transcript) { _, newValue in
            onTranscript(newValue)
        }
        .onDisappear { listener.cancel() }
    }

    // MARK: - 답 칸

    /// 말한 글자가 찍히는 칸. **안내 문구도 커서도 없다** — 키보드를 쓰지 않는다는 뜻이다.
    /// 듣는 동안은 시그니처 테두리 + 옅은 배경으로 "지금 받아 적는 중"을 보여 준다.
    private var answerBox: some View {
        let isListening = listener.phase == .listening

        return Text(answer.isEmpty ? " " : answer)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(isListening ? AppColor.softBackground : Color.white,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isListening ? AppColor.signature : Color.black,
                            lineWidth: isListening ? 3 : 1.5)
            )
            .animation(.easeOut(duration: 0.2), value: isListening)
            .accessibilityLabel(answer.isEmpty ? "말씀하신 답이 여기에 적혀요" : "말씀하신 답, \(answer)")
    }

    // MARK: - 마이크

    private var micButton: some View {
        Button(action: toggle) {
            Image(systemName: "microphone.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: Self.micSize, height: Self.micSize)
                .foregroundStyle(AppColor.signature)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(isLocked || listener.phase == .preparing)
        .opacity(isLocked ? 0.4 : 1)
        .accessibilityLabel(listener.phase == .listening ? "그만 듣기" : "말로 답하기")
    }

    /// 마이크를 눌렀을 때. 듣는 중이면 끝내고, 아니면 듣기 시작한다.
    private func toggle() {
        if listener.phase == .listening {
            listener.finish()
            return
        }

        didHearNothing = false
        onTranscript("")
        Task {
            await listener.start(hints: hints) { text in
                if text.isEmpty {
                    didHearNothing = true
                } else {
                    onFinished(text)
                }
            }
        }
    }

    // MARK: - 안내 한 줄

    private var statusText: String {
        switch listener.phase {
        case .preparing:   return "준비하고 있어요…"
        case .listening:   return "듣고 있어요…"
        case .denied:      return "마이크를 쓸 수 있게 허락해 주세요\n(설정 › KCT)"
        case .unavailable: return "지금은 음성 인식을 쓸 수 없어요"
        case .idle:
            if isLocked { return "" }
            return didHearNothing ? "잘 못 들었어요. 다시 눌러 말씀해 주세요" : "눌러서 말씀해 주세요"
        }
    }

    private var statusColor: Color {
        switch listener.phase {
        case .denied, .unavailable: AppColor.textMuted
        default:                    AppColor.signature
        }
    }
}

// MARK: - 파형

/// 마이크 아래 파형. **옆으로 흐르지 않는다** — 막대 하나가 대역 하나(왼쪽 낮은 소리 →
/// 오른쪽 높은 소리)를 맡아 제자리에서 소리 크기만큼 솟고, 조용하면 사라진다.
private struct BandBars: View {
    /// 대역별 크기 0~1. ``SpeechListener/bands``.
    let levels: [Float]
    let height: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(levels.indices, id: \.self) { index in
                let level = CGFloat(levels[index])
                Capsule()
                    .fill(AppColor.signature)
                    .frame(width: 6, height: max(6, level * height))
                    // 아주 작은 값은 아예 안 보이게 — 조용할 때 점이 남지 않는다.
                    .opacity(level < 0.04 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.12), value: levels)
        .accessibilityHidden(true)
    }
}

#Preview("쉬는 중") {
    VoiceAnswerPanel(answer: "", hints: ["이순신"], isLocked: false,
                     onTranscript: { _ in }, onFinished: { _ in })
        .padding(24)
}

#Preview("글자가 찍힌 뒤") {
    VoiceAnswerPanel(answer: "이순신 장군이요", hints: ["이순신"], isLocked: true,
                     onTranscript: { _ in }, onFinished: { _ in })
        .padding(24)
}
