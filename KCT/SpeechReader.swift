//
//  SpeechReader.swift
//  KCT
//
//  문제 지문을 한국어 음성으로 읽어준다. (어르신 접근성 — 낭독 지원)
//  기기에 설치된 한국어 음성 중 남성 음성을 우선해 자연스럽게 읽는다.
//

import AVFoundation

/// 문장을 소리 내어 읽어주는 도우미.
final class SpeechReader {
    private let synthesizer = AVSpeechSynthesizer()

    /// 사용할 한국어 음성. (한 번 계산해서 재사용)
    private lazy var voice: AVSpeechSynthesisVoice? = Self.bestKoreanVoice()

    /// 주어진 문장을 한국어 음성으로 읽는다. 읽는 중이면 멈추고 새로 읽는다.
    func speak(_ text: String) {
        // 무음 스위치와 무관하게 소리가 나도록 재생 세션을 설정한다.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92   // 살짝 천천히
        // 남성 음성이 아니면 음높이를 조금 낮춰 더 차분하고 부드럽게 들리도록.
        utterance.pitchMultiplier = Self.isMale(voice) ? 1.0 : 0.9
        synthesizer.speak(utterance)
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
