//
//  ModelCall.swift
//  KCT
//
//  역할 : 온디바이스 모델을 부를 때 공통으로 하는 것 — 시한, 그리고 실패를 남기는 일
//  요점 : 안 돌아오는 것과 실패하는 것을 같게 다룬다. 화면이 멈추지 않게
//
//  ── 구성 ──────────────────────────────────────────────
//  ModelTimeout                모델이 시한 안에 답하지 않았다
//
//  ModelCall (enum — 상태가 없다)
//  ├─ isAvailable              이 기기가 Apple Intelligence 를 쓸 수 있나
//  ├─ withTimeout(seconds:_:)  시한 안에 안 끝나면 던진다
//  └─ generate(job:...)        지시문·프롬프트를 보내 글 하나를 받아 온다.
//                              실패하면 **무엇을 시켰는지 담은 Writing** 을 돌려준다
//
//  ── generate 가 하는 일 (네 곳이 똑같이 하던 것) ───────
//  ① 지시문으로 LanguageModelSession 을 만든다
//  ② 프롬프트를 보내 @Generable 타입 하나를 받는다
//  ③ 실패하면 print 로 남기고
//  ④ job·questionID·보낸 지시문·보낸 프롬프트를 ModelFailureDraft 에 담는다
//
//  세 자리(해설 · 고른 답 설명 · 낱말 예문)가 이 넷을 각자 적고 있었다. 프롬프트
//  문장만 다르고 나머지가 같아서, 한 곳이라도 빼먹으면 그 자리의 실패는 조용히 사라진다.
//
//  ⚠️ generate 를 **안 쓰는 두 곳**이 있고, 둘 다 이유가 있다.
//     · AnswerChecker(채점) — 실패를 **던져 올려야** 한다. QuizSession.judge() 가
//       그것을 받아 조용히 오답으로 두기 때문이다. 그래서 withTimeout 만 쓴다.
//     · EncouragementWriter(응원 문구) — 글 하나가 아니라 **다섯 개 목록**을 받고,
//       실패해도 앱에 박힌 fallback 이 있어 실패 기록을 남기지 않는다. 남기게 바꾸려면
//       서버 RLS 정책에 job = 'encouragement' 를 먼저 넣어야 해서(아래 job 설명 참고)
//       2026-09-23 리팩토링에서는 손대지 않았다 — Brainstorm.md 에 후보로 남겼다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : CommentaryWriter · GlossaryExampleWriter ·
//                AnswerChecker(withTimeout 만)
//  기대는 것    : FoundationModels · Writing · ModelFailureDraft
//  건드리지 않는 것 : 무엇을 시킬지 — 지시문과 프롬프트는 부르는 쪽이 쓴다
//

import Foundation
import FoundationModels

/// 모델이 시한 안에 답하지 않았다.
struct ModelTimeout: Error {}

/// 온디바이스 모델을 부르는 공통 절차.
///
/// **상태가 없어** 열거형입니다 — 인스턴스를 만들 이유가 없습니다.
enum ModelCall {

    /// 이 기기가 Apple Intelligence 를 쓸 수 있는가.
    ///
    /// 못 쓰는 기기에서는 **아예 시키지 않습니다.** 보낸 것이 없으니 남길 실패도 없어,
    /// 부르는 쪽은 ``Writing/empty`` 를 받습니다.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// 시한 안에 끝나지 않으면 ``ModelTimeout`` 을 던진다.
    ///
    /// **안 돌아오는 것을 실패와 같게** 만듭니다. 부르는 쪽은 `catch` 하나만 쓰면 되고,
    /// 화면은 어느 쪽이든 같은 문구를 냅니다 — 어르신에게 「모델이 느립니다」는 아무 뜻이 없습니다.
    ///
    /// - Note: 먼저 끝난 쪽을 받고 나머지는 취소합니다. 모델 쪽이 이기면 잠자기가 취소되고,
    ///   잠자기가 이기면 모델 쪽이 취소됩니다.
    static func withTimeout<T: Sendable>(
        seconds: Double,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ModelTimeout()
            }

            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    /// 글 하나를 만들어 온다. **던지지 않는다** — 실패는 ``Writing/failure`` 로 돌아온다.
    ///
    /// - Parameters:
    ///   - job: 어떤 일이었나. 실패 기록을 Supabase `model_failure` 표에서 걸러 보는 키다.
    ///     지금 쓰는 값: `"commentary"` · `"note"` · `"glossary_example"`.
    ///     ⚠️ **서버 쪽 RLS 정책이 이 값 목록을 못 박아 두고 있다** — 새 값을 쓰려면
    ///     Supabase 대시보드에서 정책의 `WITH CHECK` 배열에 먼저 넣어야 한다.
    ///     안 넣으면 업로드가 `42501` 로 조용히 거부된다(11차에 실제로 겪은 일).
    ///   - questionID: 어느 문항에서 났는지. 문항과 무관한 일(응원 문구)은 `0`.
    ///   - instructions: 모델에게 주는 지침. 실패하면 이 글이 그대로 기록에 남는다.
    ///   - prompt: 이번에 시킬 것. 같은 이유로 그대로 기록에 남는다.
    ///   - type: 받을 `@Generable` 타입.
    ///   - options: 온도 등. 매번 달라야 하는 자리(응원 문구)는 온도를 낮추지 않는다.
    ///   - timeout: 초. `nil` 이면 시한을 걸지 않는다.
    ///   - extract: 받은 타입에서 글자를 꺼내는 방법.
    ///   - onFailure: 실패했을 때 **그 세션과 에러를 그대로** 넘겨 준다.
    ///     세션 객체가 있어야만 할 수 있는 일을 위한 자리다 — 지금은
    ///     ``GlossaryExampleWriter`` 가 세이프티 가드레일에 걸렸을 때
    ///     `session.logFeedbackAttachment(...)` 로 애플 신고용 첨부자료를 받아 가는 데 쓴다.
    ///     이 훅이 없으면 모델 호출을 공통 함수로 모으는 순간 그 기능이 사라진다.
    static func generate<Content: Generable>(
        job: String,
        questionID: Int,
        instructions: String,
        prompt: String,
        generating type: Content.Type,
        options: GenerationOptions = GenerationOptions(),
        timeout: Double? = nil,
        extract: (Content) -> String?,
        onFailure: ((LanguageModelSession, Error) -> Void)? = nil
    ) async -> Writing {
        // 세션을 do 블록 밖에 둔다 — catch 에서도 onFailure 에 넘겨야 한다.
        // (이 초기화 자체는 던지지 않는다)
        let session = LanguageModelSession(instructions: instructions)

        do {
            let content: Content
            if let timeout {
                content = try await withTimeout(seconds: timeout) {
                    try await session.respond(to: prompt, generating: type, options: options).content
                }
            } else {
                content = try await session.respond(to: prompt, generating: type, options: options).content
            }

            let text = extract(content)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return Writing(text: (text?.isEmpty ?? true) ? nil : text, failure: nil)
        } catch {
            // 이유를 버리면 화면에 남는 대체 문구가 왜 남는지 알 수 없고,
            // 무엇을 시켰는지 없으면 다시 만들어 볼 수가 없다.
            print("❌ \(job) 실패 q\(questionID):", error)

            onFailure?(session, error)

            return Writing(text: nil, failure: ModelFailureDraft(
                job: job,
                questionID: questionID,
                reason: String(describing: error),
                instructions: instructions,
                prompt: prompt))
        }
    }
}
