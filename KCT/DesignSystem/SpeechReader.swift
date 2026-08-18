//
//  SpeechReader.swift
//  KCT
//
//  역할 : 문제 지문을 한국어 음성으로 읽어준다 (어르신 접근성 — 낭독 지원)
//  요점 : 느린 오디오 세션 설정을 미리 백그라운드로 빼둬서 첫 낭독이 화면을 멈추지 않게 한다
//
//  기기에 설치된 한국어 음성 중 남성 음성을 우선해 자연스럽게 읽는다.
//
//  ── 구성 ──────────────────────────────────────────────
//  SpeechReader                낭독 도우미. 화면(메인 스레드)에서만 부른다
//  ├─ synthesizer              실제로 소리를 내는 객체 (메인 액터에 묶어 둔다)
//  ├─ voice                    쓸 한국어 음성. 한 번 골라 두고 재사용
//  ├─ audioSessionSetup        오디오 세션 준비 작업. 백그라운드에서 딱 한 번
//  ├─ isAudioSessionReady      준비가 끝났나. 끝났으면 곧바로 읽는다
//  ├─ speak(_:)               ← QuizView.readAloud(_:) 가 부르는 유일한 입구
//  ├─ makeUtterance(for:)      읽을 문장 하나를 만든다 (속도·음높이 조절)
//  ├─ configureAudioSession()  무음 스위치와 무관하게 소리가 나도록 세션 설정
//  └─ bestKoreanVoice() / score(for:) / isMale(_:)   음성 고르기
//
//  ── 흐름 ──────────────────────────────────────────────
//  init            → audioSessionSetup 시작 (백그라운드)
//  speak(_:)       → 읽던 것 멈춤 → 문장 만들기
//                    ├─ 세션이 준비됐으면        → 바로 낭독
//                    └─ 아직 준비 중이면          → 준비를 기다린 뒤 낭독
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView (@State private var speaker)
//  기대는 것    : AVFoundation 뿐
//  건드리지 않는 것 : 문제·채점·진척 — 이 파일은 도메인을 전혀 모른다.
//                    "언제 읽을지" 도 정하지 않는다. 그것은 QuizView 가 정한다
//
//  ⚠️ 오디오 세션 설정은 반드시 메인 스레드 밖에서 해야 한다.
//     `setCategory` / `setActive` 는 시간이 걸리는 호출이라 메인 스레드에서 부르면
//     화면이 순간 멈추고 AVAudioSession 이 경고를 남긴다.
//     (iOS 에는 비동기 activate API 가 없다 — watchOS 전용이므로 직접 옮겨야 한다)
//

import AVFoundation

/// 문장을 소리 내어 읽어주는 도우미.
///
/// 화면에서 쓰는 물건이라 전체를 메인 액터에 둡니다. `AVSpeechSynthesizer` 는
/// 여러 스레드에서 함께 쓰기 안전하지 않으므로, 이렇게 한 곳에 묶어 두는 편이 안전합니다.
/// 대신 **느린 오디오 세션 설정만** 백그라운드로 내보냅니다.
@MainActor
final class SpeechReader {
    private let synthesizer = AVSpeechSynthesizer()

    /// 사용할 한국어 음성. (한 번 계산해서 재사용)
    private lazy var voice: AVSpeechSynthesisVoice? = Self.bestKoreanVoice()

    /// 오디오 세션 준비 작업.
    ///
    /// `Task.detached` 는 "메인 액터와 상관없는 곳에서 실행해 달라"는 뜻입니다.
    /// 객체가 만들어지는 순간 시작해 두므로, 보통 첫 낭독 전에 이미 끝나 있습니다.
    ///
    /// - Note: 여기서는 `Self` 대신 타입 이름 `SpeechReader` 를 그대로 씁니다.
    ///   저장 프로퍼티의 초기값은 `self`(객체)가 아직 만들어지기 전에 계산되는데,
    ///   `Self` 는 "실제로 만들어진 그 타입"을 뜻하므로 이 시점에는 쓸 수 없습니다.
    ///   (컴파일 오류: *Covariant 'Self' type cannot be referenced from a stored property initializer*)
    private let audioSessionSetup = Task.detached(priority: .userInitiated) {
        SpeechReader.configureAudioSession()
    }

    /// 세션 준비가 끝났는지. 끝난 뒤에는 기다리지 않고 곧바로 읽는다.
    private var isAudioSessionReady = false

    /// 주어진 문장을 한국어 음성으로 읽는다. 읽는 중이면 멈추고 새로 읽는다.
    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = makeUtterance(for: text)

        guard !isAudioSessionReady else {
            synthesizer.speak(utterance)
            return
        }

        // 첫 낭독 한 번만 세션 준비를 기다린다. (`await` 동안 화면은 멈추지 않는다)
        Task {
            await audioSessionSetup.value
            isAudioSessionReady = true
            synthesizer.speak(utterance)
        }
    }

    /// 읽을 문장 하나를 만든다. 속도와 음높이를 어르신이 듣기 편하게 맞춘다.
    private func makeUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92   // 살짝 천천히
        // 남성 음성이 아니면 음높이를 조금 낮춰 더 차분하고 부드럽게 들리도록.
        utterance.pitchMultiplier = Self.isMale(voice) ? 1.0 : 0.9
        return utterance
    }

    /// 무음 스위치와 무관하게 소리가 나도록 재생 세션을 설정한다.
    ///
    /// - Important: 메인 스레드에서 부르지 않습니다. 위 `audioSessionSetup` 을 통해서만 실행됩니다.
    ///   `nonisolated` 는 "이 함수는 메인 액터에 속하지 않는다"는 표시입니다.
    private nonisolated static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
    }

    /// 기기에 설치된 한국어 음성 중 가장 자연스러운 것을 고른다.
    /// 남성 음성을 최우선으로 하고, 그다음 음질(premium > enhanced > default)을 본다.
    private static func bestKoreanVoice() -> AVSpeechSynthesisVoice? {
        let koreanVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ko") }

        guard !koreanVoices.isEmpty else {
            return AVSpeechSynthesisVoice(language: "ko-KR")
        }

        return koreanVoices.max { score(for: $0) < score(for: $1) }
    }

    /// 음성 선호 점수. 높을수록 우선. (남성 > 음질 순)
    private static func score(for voice: AVSpeechSynthesisVoice) -> Int {
        var value = 0
        if isMale(voice) { value += 1000 }   // 남성 음성을 최우선 (예: 민수)
        switch voice.quality {
        case .premium:  value += 100   // 가장 자연스러움 (다운로드 필요)
        case .enhanced: value += 50    // 향상됨 (다운로드 필요)
        default:        value += 0     // 기본 (로봇 같은 음질)
        }
        return value
    }

    /// 남성 음성인지 판단. 성별 메타데이터가 없을 때를 대비해 이름으로도 확인한다.
    private static func isMale(_ voice: AVSpeechSynthesisVoice?) -> Bool {
        guard let voice else { return false }
        if #available(iOS 17.0, *), voice.gender == .male {
            return true
        }
        // 한국어 남성 음성 이름 힌트 (민수 / Minsu)
        let name = voice.name.lowercased()
        return name.contains("민수") || name.contains("minsu")
    }
}
