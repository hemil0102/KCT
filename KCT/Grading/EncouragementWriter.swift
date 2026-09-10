//
//  EncouragementWriter.swift
//  KCT
//
//  역할 : 오답 해설을 기다리는 동안 보여줄 응원 문구를 회차마다 새로 만든다
//  요점 : 여기는 사실을 말하지 않는다. 그래서 모델이 마음껏 지어내도 안전한 유일한 자리다
//
//  ── 구성 ──────────────────────────────────────────────
//  Encouragements (@Generable)   문구 다섯 개
//  └─ lines
//
//  EncouragementWriter
//  ├─ write() async -> [String]   회차 시작 때 뒤에서 만든다
//  └─ fallback                    못 만들었을 때 쓸 열 가지 (앱에 박혀 있다)
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.start()
//    → Task 로 write() 를 뒤에서 돌린다. 어머니는 첫 문제를 읽는 중이다
//    → 다 되면 QuizSession 이 들고 있다가 오답이 나올 때 하나씩 꺼내 쓴다
//    → 그 전에 틀리면 fallback 에서 뽑는다. 어느 쪽이든 화면은 기다리지 않는다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.start()
//  기대는 것    : FoundationModels 뿐. 문제도 정답도 모른다
//  건드리지 않는 것 : 언제 보여줄지 - QuizSession 이 정한다
//

import Foundation
import FoundationModels

/// 응원 문구 묶음. 한 회차에 다섯 개.
@Generable
struct Encouragements {
    @Guide(description: "서로 다른 응원 문구 다섯 개", .count(5))
    let lines: [String]
}

/// 회차마다 새 응원 문구를 만든다.
///
/// ## 여기만 지어내도 된다
///
/// 채점과 해설은 **틀리면 사실이 거짓이 되므로** 재료를 미리 주고 그것만 쓰게 합니다.
/// 응원은 다릅니다 — 참·거짓이 없어 **모델이 매번 새로 지어도 아무것도 안 깨집니다.**
/// 같은 말이 매번 나오면 그때부터 안 읽히므로, 오히려 새로 만드는 편이 낫습니다.
///
/// ## 담는 뜻은 하나다
///
/// **「실수해도 괜찮아요. 다음에 잘하면 돼요.」** 이 한 가지를 매번 다른 말로 바꿔 씁니다.
/// 여러 가지를 담으려 하면 어떤 문구는 위로가 되고 어떤 문구는 재촉이 됩니다.
///
/// - Important: 실패해도 **던지지 않습니다.** ``fallback`` 이 앱 안에 있어
///   모델이 없는 기기에서도 문구는 늘 나옵니다.
struct EncouragementWriter {

    /// 한 회차에 만들 개수. 한 회차가 다섯 문제라 다섯이면 넉넉합니다.
    private static let count = 5

    /// 문구 하나의 길이 상한. 넘으면 버립니다 — **한 줄에 안 들어갑니다.**
    private static let maxLength = 20

    /// 모델이 못 만들었을 때 쓰는 열 가지. **앱에 박혀 있어 절대 실패하지 않는다.**
    static let fallback = [
        "실수해도 괜찮아요. 🙂",
        "다음에 맞히면 돼요. 🌤️",
        "누구나 그럴 수 있어요. 😸",
        "천천히 가도 돼요. 🐢",
        "한 번쯤은 괜찮아요. 🍀",
        "지금도 잘하고 계세요. ☕️",
        "다시 보면 알게 돼요. 🌱",
        "이런 날도 있는 거죠. 🌈",
        "괜찮아요, 또 만나요. 🎈",
        "조금씩 늘고 있어요. 📖",
    ]

    /// 이번 회차에 쓸 문구를 만든다. 못 만들면 **빈 배열** — 부르는 쪽이 ``fallback`` 을 쓴다.
    func write() async -> [String] {
        let instructions = """
            당신은 한국어를 배우는 70대 어르신을 곁에서 응원하는 사람입니다.
            문제를 틀린 분이 잠깐 기다리는 동안 볼 짧은 말을 씁니다.

            [담을 뜻 — 이것 하나입니다]
            "실수해도 괜찮아요. 다음에 잘하면 돼요."
            이 말을 매번 다른 표현으로 바꿔 씁니다.

            [반드시 지킨다]
            1. 한 문구는 한 문장, 열다섯 글자 안팎입니다. 화면에서 한 줄에 들어가야 합니다.
            2. 문구 끝에 어울리는 이모지를 하나 붙입니다.
            3. 존댓말로 씁니다.
            4. 다섯 개가 서로 달라야 합니다.

            [쓰지 않는다]
            · 나무라거나 다그치는 말. "외우세요", "집중하세요"
            · 틀렸다는 말을 다시 꺼내는 것. "틀리셨네요"
            · 무엇을 하라고 시키는 말

            [이런 느낌으로]
            실수해도 괜찮아요. 🙂
            다음에 맞히면 돼요. 🌤️
            누구나 그럴 수 있어요. 😸
            천천히 가도 돼요. 🐢
            """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "응원 문구 \(Self.count)개를 쓰세요.",
                generating: Encouragements.self,
                // 매번 달라야 하는 자리라 온도를 낮추지 않는다.
                options: GenerationOptions(temperature: 1.0))

            return response.content.lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count <= Self.maxLength }
        } catch {
            print("❌ 응원 문구 실패:", error)
            return []
        }
    }
}
