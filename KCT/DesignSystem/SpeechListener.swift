//
//  SpeechListener.swift
//  KCT
//
//  역할 : 마이크로 어머니의 말을 듣고, 글자로 바꾸고, 목소리 크기를 대역별로 잰다
//  요점 : SpeechReader(읽어 주기)의 짝이다. 화면은 phase·transcript·bands 만 보고 그린다.
//        말이 끝났는지(잠깐 조용해졌는지)도 여기서 판단해 onFinish 로 알린다
//
//  ── 구성 ──────────────────────────────────────────────
//  SpeechListener                    듣기 한 번의 주인 (@Observable — 화면이 값을 지켜본다)
//  ├─ Phase                          idle · preparing · listening · denied · unavailable
//  ├─ phase / transcript / bands     화면이 읽는 셋 — 상태 · 지금까지 알아들은 글자 · 대역별 크기(0~1)
//  ├─ start(hints:onFinish:)         권한 확인 → 녹음용 오디오 세션 → 인식 시작
//  ├─ finish()                       지금까지 알아들은 글자로 끝낸다 → onFinish(글자)
//  ├─ cancel()                       아무것도 알리지 않고 멈춘다 (화면이 사라질 때)
//  ├─ receive(_:isFinal:)            인식기가 보낸 글자를 받는다 — 바뀌면 침묵 타이머를 다시 잰다
//  ├─ restartSilenceTimer()          글자가 1.5초 동안 안 바뀌면 말이 끝났다고 본다
//  ├─ teardown()                     엔진·탭·인식 작업·타이머를 모두 거둔다
//  ├─ makeTap / makeResultHandler    오디오 스레드에서 불리는 클로저를 **메인 액터 밖에서** 만든다
//  └─ activateRecordingSession / restorePlaybackSession   오디오 세션 전환 (백그라운드에서)
//
//  BandAnalyzer                      소리 조각 하나 → 대역별 크기 24칸 (DFT, Accelerate C 함수)
//
//  ── 흐름 ──────────────────────────────────────────────
//  VoiceAnswerPanel 의 마이크 탭 → start(hints:onFinish:)
//    → 음성 인식·마이크 권한 확인 (처음 한 번 시스템 창이 뜬다) — 거절이면 phase = .denied
//    → 오디오 세션을 녹음용(.playAndRecord)으로 바꾼다
//    → 마이크 소리를 탭(tap)으로 받아 ① 인식 요청에 흘려보내고 ② BandAnalyzer 로 대역별 크기를 잰다
//    → 인식기가 글자를 보낼 때마다 transcript 갱신 → 화면의 답 칸에 키보드처럼 찍힌다
//    → 글자가 1.5초 동안 그대로면(말이 끝남) 또는 마이크를 다시 누르면 → finish()
//    → 오디오 세션을 읽어 주기용(.playback)으로 되돌린다 — SpeechReader 가 그 상태를 전제한다
//    → onFinish(알아들은 글자) — 빈 글자면 "못 들었다"는 뜻
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : VoiceAnswerPanel
//  기대는 것    : Speech(SFSpeechRecognizer), AVFAudio(AVAudioEngine·AVAudioSession), Accelerate(vDSP)
//  건드리지 않는 것 : 정답 판정 — 글자만 넘긴다. 맞는지는 QuizSession.judge() 가 본다
//
//  ── 참고 문서 ──────────────────────────────────────────
//  https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio
//  https://developer.apple.com/documentation/speech/sfspeechaudiobufferrecognitionrequest
//  https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:)
//  https://developer.apple.com/documentation/accelerate/vdsp_dft_zop_createsetup(_:_:_:)
//

import Accelerate
import AVFoundation
import Observation
import Speech

/// 마이크로 듣고 글자로 바꾸는 부품. 한 번 누를 때마다 한 번 듣는다.
///
/// 이 프로젝트는 타입을 기본으로 **메인 액터**에 둔다(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
/// 그런데 마이크 탭과 인식 결과는 **오디오·백그라운드 스레드**에서 불린다. 메인 액터에서 만든
/// 클로저가 다른 스레드에서 불리면 앱이 멈출 수 있어서, 그 클로저들은 `nonisolated static`
/// 함수(``makeTap(request:bandCount:onBands:)``·``makeResultHandler(_:)``) 안에서 만들고,
/// 결과는 `Task { @MainActor in … }` 로 메인 액터에 넘긴다.
@Observable
final class SpeechListener {

    /// 지금 무엇을 하고 있나. 화면은 이 값을 보고 안내 문구와 파형을 고른다.
    enum Phase: Equatable {
        /// 쉬는 중 — 마이크를 누를 수 있다
        case idle
        /// 권한·오디오 세션을 준비하는 중 (보통 한순간)
        case preparing
        /// 듣는 중
        case listening
        /// 마이크나 음성 인식 권한을 거절했다 — 설정에서 켜야 한다
        case denied
        /// 이 기기·지금 상태에서 인식기를 쓸 수 없다
        case unavailable
    }

    /// 파형 막대 수. 낮은 소리 → 높은 소리 순서로 한 칸씩.
    static let bandCount = 24

    private(set) var phase: Phase = .idle

    /// 지금까지 알아들은 글자. 말하는 동안 계속 바뀐다(부분 결과).
    private(set) var transcript = ""

    /// 대역별 소리 크기(0~1). 조용하면 전부 0 — 화면의 막대가 사라진다.
    private(set) var bands = [Float](repeating: 0, count: SpeechListener.bandCount)

    /// 한국어 인식기. 기기가 한국어를 지원하지 않으면 nil.
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))

    /// 마이크 소리를 받아 오는 오디오 엔진.
    private let engine = AVAudioEngine()

    /// 마이크 소리를 조각(buffer)으로 받아 인식기에 넘기는 요청.
    private var request: SFSpeechAudioBufferRecognitionRequest?

    /// 인식 작업. 멈출 때 취소한다.
    private var task: SFSpeechRecognitionTask?

    /// 말이 끝났는지 재는 타이머. 글자가 바뀔 때마다 새로 건다.
    private var silenceTimer: Task<Void, Never>?

    /// 너무 오래 듣지 않도록 거는 상한 타이머.
    private var deadlineTimer: Task<Void, Never>?

    /// 녹음용으로 세션을 바꿨는가 — 바꿨을 때만 되돌린다.
    private var didActivateSession = false

    /// 듣기가 끝나면 알아들은 글자를 넘길 곳.
    private var onFinish: ((String) -> Void)?

    /// 글자가 이만큼 그대로면 말이 끝났다고 본다.
    ///
    /// - Note: 어르신은 단어 사이를 길게 쉬실 수 있다. 실기기에서 중간에 끊기면 늘린다.
    private static let silenceLimit: Duration = .seconds(1.5)

    /// 아무 말이 없어도 이만큼 지나면 멈춘다. 말을 시작했으면 침묵 타이머가 먼저 끝낸다.
    private static let maxDuration: Duration = .seconds(10)

    // MARK: - 화면이 부르는 것

    /// 듣기를 시작한다.
    ///
    /// - Parameters:
    ///   - hints: 인식기가 잘 알아듣도록 미리 알려 줄 낱말들(정답 표기). 「이순신」 같은
    ///     고유명사는 인식기가 다른 글자로 적기 쉬워서 넘긴다(``SFSpeechRecognitionRequest/contextualStrings``).
    ///   - onFinish: 끝나면 알아들은 글자를 받는다. 빈 글자면 아무것도 못 들은 것이다.
    func start(hints: [String], onFinish: @escaping (String) -> Void) async {
        // 이미 준비·듣는 중이면 무시한다. 거절·불가 상태에서는 다시 시도할 수 있다.
        guard phase != .preparing, phase != .listening else { return }
        phase = .preparing
        transcript = ""
        self.onFinish = onFinish

        guard await Self.requestPermissions() else {
            phase = .denied
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            phase = .unavailable
            return
        }

        do {
            try await Self.activateRecordingSession()
            didActivateSession = true
            try beginRecognition(with: recognizer, hints: hints)
            phase = .listening
            startDeadlineTimer()
        } catch {
            print("❌ 음성 인식 시작 실패:", error)
            teardown()
            await restoreSessionIfNeeded()
            phase = .unavailable
        }
    }

    /// 지금까지 알아들은 글자로 끝내고 ``onFinish`` 에 넘긴다. 마이크를 다시 눌러도 여기로 온다.
    func finish() {
        guard phase == .listening else { return }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        teardown()
        phase = .idle
        Task { await restoreSessionIfNeeded() }

        let deliver = onFinish
        onFinish = nil
        deliver?(text)
    }

    /// 아무것도 알리지 않고 멈춘다. 화면이 사라질 때(다음 문제·나가기) 부른다.
    func cancel() {
        onFinish = nil
        guard phase == .listening || phase == .preparing else { return }
        teardown()
        phase = .idle
        Task { await restoreSessionIfNeeded() }
    }

    // MARK: - 듣기 준비

    /// 인식 요청을 만들고, 마이크 탭을 달고, 엔진을 켠다.
    private func beginRecognition(with recognizer: SFSpeechRecognizer, hints: [String]) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true      // 말하는 동안에도 글자를 보내 달라
        request.addsPunctuation = false                // 「이순신.」처럼 마침표가 붙지 않게
        request.contextualStrings = hints
        // 기기 안에서 인식할 수 있으면 그렇게 한다 — 인터넷이 없어도 되고, 목소리가 밖으로 나가지 않는다.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format,
                         block: Self.makeTap(request: request, bandCount: Self.bandCount) { [weak self] values in
            // 듣기를 멈춘 뒤 늦게 도착한 값은 버린다 — 안 그러면 막대가 다시 솟는다.
            guard let self, self.phase == .listening else { return }
            self.bands = values
        })

        task = recognizer.recognitionTask(with: request,
                                          resultHandler: Self.makeResultHandler { [weak self] text, isFinal in
            self?.receive(text, isFinal: isFinal)
        })

        engine.prepare()
        try engine.start()
    }

    /// 인식기가 보낸 글자를 받는다.
    private func receive(_ text: String?, isFinal: Bool) {
        guard phase == .listening else { return }
        if let text, text != transcript {
            transcript = text
            restartSilenceTimer()
        }
        if isFinal { finish() }
    }

    /// 글자가 ``silenceLimit`` 동안 안 바뀌면 끝낸다. 글자가 바뀔 때마다 새로 건다.
    private func restartSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: SpeechListener.silenceLimit)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// 아무 말이 없어도 ``maxDuration`` 이 지나면 끝낸다.
    private func startDeadlineTimer() {
        deadlineTimer?.cancel()
        deadlineTimer = Task { [weak self] in
            try? await Task.sleep(for: SpeechListener.maxDuration)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// 엔진·탭·인식 작업·타이머를 모두 거둔다. 막대도 내린다.
    private func teardown() {
        silenceTimer?.cancel()
        silenceTimer = nil
        deadlineTimer?.cancel()
        deadlineTimer = nil

        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)

        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil

        bands = [Float](repeating: 0, count: Self.bandCount)
    }

    /// 녹음용으로 바꿨던 세션을 읽어 주기용으로 되돌린다.
    private func restoreSessionIfNeeded() async {
        guard didActivateSession else { return }
        didActivateSession = false
        await Self.restorePlaybackSession()
    }

    // MARK: - 메인 액터 밖에서 만드는 것들

    /// 마이크 탭 클로저. **오디오 스레드**에서 불린다.
    ///
    /// 소리 조각을 ① 인식 요청에 붙이고 ② 대역별 크기를 재서 메인 액터로 보낸다.
    private nonisolated static func makeTap(
        request: SFSpeechAudioBufferRecognitionRequest,
        bandCount: Int,
        onBands: @escaping @MainActor @Sendable ([Float]) -> Void
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        let analyzer = BandAnalyzer()
        return { buffer, _ in
            request.append(buffer)
            let values = analyzer.bands(from: buffer, count: bandCount)
            Task { @MainActor in onBands(values) }
        }
    }

    /// 인식 결과 클로저. 인식기의 스레드에서 불린다.
    ///
    /// 오류도 "끝"으로 본다 — 인식이 끊겼으면 그때까지 알아들은 글자로 마무리한다.
    private nonisolated static func makeResultHandler(
        _ deliver: @escaping @MainActor @Sendable (String?, Bool) -> Void
    ) -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        return { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in deliver(text, isFinal) }
        }
    }

    /// 음성 인식 권한과 마이크 권한을 차례로 묻는다. 둘 다 허락해야 `true`.
    ///
    /// 처음 한 번만 시스템 창이 뜨고, 그 뒤로는 저장된 답을 곧바로 돌려준다.
    private nonisolated static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// 오디오 세션을 녹음용으로 바꾼다. 시간이 걸리는 호출이라 백그라운드에서 한다(SpeechReader 와 같은 이유).
    ///
    /// `.defaultToSpeaker` — 녹음 세션에서는 소리가 기본으로 통화용 스피커(귀에 대는 쪽)로
    /// 나가서, 그 사이 무엇을 읽어 주면 거의 안 들린다. 아래 큰 스피커로 나가게 한다.
    private nonisolated static func activateRecordingSession() async throws {
        try await Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }.value
    }

    /// 오디오 세션을 읽어 주기용으로 되돌린다. ``SpeechReader`` 의 설정과 **같은 값**이어야 한다 —
    /// SpeechReader 는 처음 한 번만 세션을 맞추고 그 뒤로는 그대로라고 믿는다.
    private nonisolated static func restorePlaybackSession() async {
        await Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try? session.setActive(true)
        }.value
    }
}

// MARK: - 대역별 크기

/// 소리 조각 하나를 **낮은 소리 → 높은 소리** 대역으로 나눠, 대역마다 크기(0~1)를 낸다.
///
/// 순서: 조각 앞 1024개 샘플 → 창 함수(가장자리를 부드럽게) → DFT(소리를 주파수별로 쪼갬)
/// → 대역마다 평균 세기 → 데시벨 → 0~1 로 줄임. 사람 목소리가 모여 있는 80~4000Hz 만 본다.
///
/// DFT 는 Accelerate 의 **C 함수**(`vDSP_DFT_zop_CreateSetup`·`vDSP_DFT_Execute`)를 쓴다.
/// Swift 용 제네릭 함수(`vDSP.multiply`·`DiscreteFourierTransform.transform`)는 인자 타입을
/// 짐작하지 못해 「Generic parameter 'V' could not be inferred」 에러가 났다 — C 함수는
/// 타입이 `Float` 포인터로 못 박혀 있어 짐작할 것이 없다. 창 곱하기·RMS 는 1024번 도는
/// 평범한 반복문이면 충분하다.
///
/// `final class` 인 이유 — DFT 준비물(setup)은 C 메모리라 다 쓰면 직접 돌려줘야 한다(`deinit`).
/// `nonisolated` — 오디오 스레드에서 쓰므로 메인 액터에 묶지 않는다.
///
/// - Note: ``floorDB``·``rangeDB``·``silenceDB`` 는 실기기에서 맞출 값이다. 막대가 너무 낮으면
///   `floorDB` 를 내리고, 조용할 때도 막대가 남으면 `silenceDB` 를 올린다.
///
/// 참고: https://developer.apple.com/documentation/accelerate/vdsp_dft_zop_createsetup(_:_:_:)
nonisolated final class BandAnalyzer {
    /// 한 번에 보는 샘플 수. DFT 는 2의 거듭제곱 길이에서 빠르다.
    static let size = 1024

    /// 이 데시벨 이하는 막대 0.
    static let floorDB: Float = -10
    /// floorDB 에서 이만큼 위가 막대 끝(1).
    static let rangeDB: Float = 40
    /// 전체 소리(RMS)가 이보다 작으면 조용한 것으로 보고 막대를 모두 내린다.
    static let silenceDB: Float = -50

    /// 사람 목소리 범위.
    static let lowHz: Float = 80
    static let highHz: Float = 4000

    /// DFT 준비물. 길이·방향을 미리 정해 두고 매번 다시 쓴다.
    private let setup: OpaquePointer?

    /// 해닝 창 — 조각의 양 끝을 0 으로 부드럽게 눌러, 잘린 자리에서 생기는 가짜 소리를 줄인다.
    private let window: [Float]

    init() {
        setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.size), vDSP_DFT_Direction.FORWARD)
        let n = Float(Self.size)
        window = (0..<Self.size).map { i in 0.5 - 0.5 * cos(2 * Float.pi * Float(i) / n) }
    }

    deinit {
        if let setup { vDSP_DFT_DestroySetup(setup) }
    }

    func bands(from buffer: AVAudioPCMBuffer, count: Int) -> [Float] {
        let silent = [Float](repeating: 0, count: count)
        guard let channel = buffer.floatChannelData?[0], let setup else { return silent }

        let frames = min(Int(buffer.frameLength), Self.size)
        guard frames > 0 else { return silent }

        // 앞 1024개만 쓴다. 모자라면 0 으로 채운다. 창을 곱하면서 RMS(전체 크기)도 같이 잰다.
        var real = [Float](repeating: 0, count: Self.size)
        var sumOfSquares: Float = 0
        for i in 0..<frames {
            let sample = channel[i]
            sumOfSquares += sample * sample
            real[i] = sample * window[i]
        }

        // 조용하면 막대를 전부 내린다.
        let rms = (sumOfSquares / Float(frames)).squareRoot()
        guard 20 * log10(rms + 1e-9) > Self.silenceDB else { return silent }

        // 주파수별 세기. 입력의 허수부는 0(실제 소리는 실수뿐이다).
        let imaginary = [Float](repeating: 0, count: Self.size)
        var outReal = [Float](repeating: 0, count: Self.size)
        var outImaginary = [Float](repeating: 0, count: Self.size)
        vDSP_DFT_Execute(setup, real, imaginary, &outReal, &outImaginary)

        let half = Self.size / 2
        var magnitudes = [Float](repeating: 0, count: half)
        for i in 0..<half {
            let re = outReal[i], im = outImaginary[i]
            magnitudes[i] = (re * re + im * im).squareRoot()
        }

        // 대역 경계를 로그 간격으로 — 귀는 낮은 소리의 차이를 더 잘 듣는다.
        let binHz = Float(buffer.format.sampleRate) / Float(Self.size)
        func edge(_ k: Int) -> Float {
            Self.lowHz * pow(Self.highHz / Self.lowHz, Float(k) / Float(count))
        }

        var result = silent
        for k in 0..<count {
            let lo = min(half - 1, max(1, Int(edge(k) / binHz)))
            let hi = min(half, max(lo + 1, Int(edge(k + 1) / binHz)))
            var sum: Float = 0
            for i in lo..<hi { sum += magnitudes[i] }
            let average = sum / Float(hi - lo)
            let db = 20 * log10(average + 1e-9)
            result[k] = min(1, max(0, (db - Self.floorDB) / Self.rangeDB))
        }
        return result
    }
}
