//
//  CommentaryWriter.swift
//  KCT
//
//  역할 : 틀린 문항에 대해 "왜 그것이 답인지" 세 문장 이내로 만든다
//  요점 : 사실은 우리가 주고, 문장은 모델이 만든다. 재료에 없는 것은 못 쓴다
//
//  ── 구성 ──────────────────────────────────────────────
//  Commentary (@Generable)   모델이 만들어 주는 해설 한 덩어리
//  └─ text                   세 문장 이내의 한국어
//
//  Writing                   만든 결과 - 글, 또는 실패했을 때 무엇을 시켰는지
//  ChoiceNote (@Generable)   고른 답이 무엇인지 한 문장
//
//  CommentaryWriter
//  ├─ write(for:)            정답 해설. 실패하면 무엇을 시켰는지가 담겨 나온다
//  ├─ describe(_:)           고른 답이 무엇인지 한 문장. 재료가 없으면 빈 Writing
//  ├─ materials(for:)        facts 를 무게 순으로 골라 프롬프트에 넣을 목록으로
//  └─ tone(for:)             주제마다 다른 말투 한 줄 (문장 틀이 아니다)
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.gradeCurrent() 가 오답을 만나면
//    → 창(feedback)을 먼저 띄우고
//    → write(for:) 호출
//    → Question.facts 에서 무게 높은 순으로 서너 개를 골라 프롬프트에 넣는다
//    → 모델은 그 재료만으로 문장을 만든다
//    → 실패하면 nil — 창은 이미 떠 있으므로 아무 일도 일어나지 않는다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.gradeCurrent()
//  기대는 것    : FoundationModels, QuizItem, QuestionFact
//  건드리지 않는 것 : 재료 자체 - 무엇이 사실인지는 questions.json 이 정한다
//                    (채우는 규칙은 저장소 루트의 해설_재료_규칙.md)
//

import Foundation
import FoundationModels

/// 오답 해설 한 덩어리. 모델이 이 구조체 모양으로 직접 만들어 준다.
///
/// 문장을 나눠 받지 않고 `text` 하나로 받는 이유 — 어머니가 창에서 읽는 것은
/// **이어지는 세 문장**입니다. 쪼개 받아 다시 붙이면 이음매가 어색해집니다.
@Generable
struct Commentary {
    @Guide(description: "알려진 사실만 써서 만든 한국어 설명. 세 문장 이내")
    let text: String
}

/// 글 한 덩어리를 만든 결과. **성공하면 글이, 실패하면 무엇을 시켰는지가 담긴다.**
///
/// 실패를 `nil` 로만 돌려주면 「왜 실패했는지」가 사라집니다. 안전 필터에 걸린 이유는
/// **우리가 보낸 글 안에** 있으므로, 그 글을 함께 들고 나옵니다.
struct Writing {
    let text: String?
    let failure: ModelFailureDraft?

    static let empty = Writing(text: nil, failure: nil)
}

/// 고른 답이 무엇인지 알려 주는 한 문장.
@Generable
struct ChoiceNote {
    @Guide(description: "알려진 사실만 써서 그것이 무엇인지 알려 주는 한국어 한 문장")
    let text: String
}

/// 틀린 문항의 해설을 쓰는 쪽. 온디바이스 모델을 쓴다.
///
/// ## 사실은 우리가 주고, 문장은 모델이 만든다
///
/// 2026-09-05 관찰에서 오답 다섯 중 **셋의 해설이 사실과 달랐습니다.**
/// 「고조선은 크고 높은 나라」·「태극기는 날씨를 알려주는 붉은 태극」·
/// 「신라는 불교를 중심으로 발전한 나라라고 해서 신라」. 모델이 **모르는 것을 지어낸** 것입니다.
///
/// 그래서 ``Question/facts`` 에 사실을 미리 넣어 두고, 모델에게는 **그 재료만** 줍니다.
/// 모델의 일이 「기억해 내기」에서 **「고쳐 쓰기」로** 바뀝니다 — 고쳐 쓰기는 작은 모델도 합니다.
///
/// ## 무엇을 지키게 하는가
///
/// | 지킬 것 | 왜 |
/// |---|---|
/// | 재료에 없는 것을 쓰지 않는다 | 환각이 나는 자리는 늘 **빈칸을 채우라고 시킨 곳**이었습니다 |
/// | 세 문장 이내 | 어머니는 창을 몇 초 봅니다 |
/// | 고른 답을 부정하지 않는다 | 어머니는 **이미 자기가 틀린 걸 압니다** |
/// | 문제 지문을 넣지 않는다 | 「일제의 지배」 같은 낱말이 안전 필터에 걸립니다 (2026-09-06) |
///
/// - Important: 실패해도 **던지지 않습니다.** 해설은 없어도 창이 뜹니다. 실패를 `nil` 로
///   돌려주면 ``ObsRecord/explanation`` 이 `null` 로 남고, **몇 번 실패했는지 셀 수 있습니다.**
struct CommentaryWriter {

    /// 프롬프트에 넣을 재료의 최대 개수. 세 문장에 담을 수 있는 만큼만.
    private static let materialLimit = 4

    /// 틀린 문항의 해설을 만든다. 못 만들면 `nil`.
    ///
    /// - Parameter item: 방금 틀린 문항
    /// - Returns: 세 문장 이내의 해설. 실패하면 무엇을 시켰는지가 담긴 ``Writing``
    func write(for item: QuizItem) async -> Writing {
        let facts = materials(for: item.question)

        // 재료가 없으면 지어내라는 뜻이 된다. 차라리 해설을 안 만든다.
        guard !facts.isEmpty else { return .empty }

        let instructions = """
            당신은 어르신에게 한국의 역사와 제도를 알려주는 사람입니다.
            방금 문제를 놓친 분에게 정답을 기억에 남게 알려주는 짧은 글을 씁니다.
            읽는 분은 70대이고 한국어에 서투릅니다.

            \(tone(for: item.question.kind))

            [반드시 지킨다]
            1. '알려진 사실'에 있는 것만 씁니다. 거기 없는 연도, 날짜, 숫자, 글자 뜻은 절대 넣지 않습니다.
            2. 세 문장을 넘기지 않습니다.
            3. 답을 문장 안에 그대로 넣습니다.
            4. 답이 아닌 다른 답은 말하지 않습니다.
            5. '문제에 나온 설명처럼' 같은 말을 쓰지 않습니다. 읽는 분에게 문제는 보이지 않습니다.
            6. 쉬운 말로 씁니다. 새로운 어려운 말을 꺼내지 않습니다.
            """

        // 문제 지문은 넣지 않는다. 글자를 설명하는 데 필요 없고,
        // 「일제의 지배」 같은 낱말이 안전 필터에 걸린다 (2026-09-06).
        let prompt = """
            답: \(item.question.displayAnswer)

            알려진 사실:
            \(facts.map { "· \($0)" }.joined(separator: "\n"))

            위 사실만 써서 세 문장 이내의 글을 쓰세요.
            """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: Commentary.self)

            let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return Writing(text: text.isEmpty ? nil : text, failure: nil)
        } catch {
            // 이유를 버리면 「잠시만 같이 살펴봐요.」가 왜 남는지 알 수 없고,
            // 무엇을 시켰는지 없으면 다시 만들어 볼 수가 없다.
            print("❌ 해설 실패 q\(item.question.id) \(item.question.displayAnswer):", error)

            return Writing(text: nil, failure: ModelFailureDraft(
                job: "commentary",
                questionID: item.question.id,
                reason: String(describing: error),
                instructions: instructions,
                prompt: prompt))
        }
    }

    /// **고른 답이 무엇인지** 한 문장으로 알려 준다. 못 만들면 `nil`.
    ///
    /// 어머니가 추석 문제에 「개천절」을 골랐다면, 개천절이 정답인 문항의 재료를 가져와
    /// 「개천절은 …이에요」를 만듭니다. **나무라는 것이 아니라 고른 것도 알려 주는 것**입니다.
    ///
    /// - Parameter question: **고른 답이 정답인** 문항. ``QuestionCatalog/question(answering:)`` 가
    ///   못 찾으면 `nil` 이 들어오고, 그때는 아무것도 하지 않는다
    func describe(_ question: Question?) async -> Writing {
        guard let question else { return .empty }

        let facts = materials(for: question)
        guard !facts.isEmpty else { return .empty }

        let instructions = """
            당신은 어르신에게 한국의 역사와 제도를 알려주는 사람입니다.
            읽는 분은 70대이고 한국어에 서투릅니다.

            [반드시 지킨다]
            1. '알려진 사실'에 있는 것만 씁니다. 거기 없는 것은 절대 넣지 않습니다.
            2. 한 문장만 씁니다.
            3. 그것이 무엇인지만 말합니다. 맞다 틀리다는 말하지 않습니다.
            4. 쉬운 말로 씁니다.
            """

        let prompt = """
            낱말: \(question.displayAnswer)

            알려진 사실:
            \(facts.map { "· \($0)" }.joined(separator: "\n"))

            위 사실만 써서 이 낱말이 무엇인지 한 문장으로 알려 주세요.
            """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: ChoiceNote.self)

            let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return Writing(text: text.isEmpty ? nil : text, failure: nil)
        } catch {
            print("❌ 고른 답 설명 실패 q\(question.id) \(question.displayAnswer):", error)

            return Writing(text: nil, failure: ModelFailureDraft(
                job: "note",
                questionID: question.id,
                reason: String(describing: error),
                instructions: instructions,
                prompt: prompt))
        }
    }

    /// 프롬프트에 넣을 재료를 고른다. **무게 높은 순, 같은 무게끼리는 섞어서.**
    ///
    /// 섞는 이유 — 사실은 늘 같지만 **고르는 조각이 달라지면 해설도 달라집니다.**
    /// 같은 문항을 다시 만났을 때 똑같은 글이 나오면 읽지 않게 됩니다.
    private func materials(for question: Question) -> [String] {
        let byWeight = Dictionary(grouping: question.facts, by: \.weight)

        return byWeight.keys.sorted(by: >)
            .flatMap { byWeight[$0]!.shuffled() }
            .prefix(Self.materialLimit)
            .map(\.text)
    }

    /// 주제마다 다른 **말투** 한 줄.
    ///
    /// 예전에는 여기에 「[구조] "[정답]은 … 고마운 사람입니다"」처럼 **문장 틀**이 있었는데,
    /// 로그에서 그 틀이 **글자 그대로 복사되어** 나왔습니다 — 「단군왕검은 … 고마운 사람입니다」,
    /// 「설날은 문제에 나온 설명처럼 …」. 틀을 주면 모델은 틀을 베낍니다.
    ///
    /// - Note: 이제 **무엇을 말할지는 재료가 정하고, 여기서는 어떻게 말할지만** 정합니다.
    private func tone(for kind: AnswerKind) -> String {
        switch kind {
        case .number:
            "숫자는 또박또박 말합니다."
        case .person:
            "사람은 무엇을 한 분인지로 소개합니다."
        case .place:
            "나라와 땅은 언제 어디였는지로 말합니다."
        case .day:
            "날은 무슨 일을 기리는 날인지부터 말합니다."
        case .event:
            "사건은 무슨 일이 있었는지로 말합니다."
        case .thing:
            "물건은 눈에 보이는 모양으로 말합니다."
        case .heritage:
            "옛것은 조상이 남긴 것이라고 말합니다."
        case .system:
            "제도는 글자의 뜻을 풀어 말합니다."
        case .procedure:
            "절차는 언제 무엇을 하는 일인지로 말합니다."
        }
    }
}
