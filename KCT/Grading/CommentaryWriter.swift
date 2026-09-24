//
//  CommentaryWriter.swift
//  KCT
//
//  역할 : "왜 그것이 답인지"를 50~60자로 만든다 (오답·정답 해설이 같은 글을 쓴다)
//  요점 : 사실은 우리가 주고, 문장은 모델이 만든다. 재료에 없는 것은 못 쓴다
//
//  ── 구성 ──────────────────────────────────────────────
//  Commentary (@Generable)   모델이 만들어 주는 해설 한 덩어리
//  └─ text                   50~60자의 한국어 (창에서 서너 줄)
//
//  ChoiceNote (@Generable)   고른 답이 무엇인지 한 문장
//
//  CommentaryWriter
//  ├─ Length                 .full(50~60자, 정답 해설) · .oneLine(한 문장, 고른 오답이 무엇인지)
//  ├─ explain(_:length:)     문항 하나의 facts 로 그 답을 설명한다. 유일한 바깥 입구
//  ├─ full(_:facts:)         .full 의 지시문·프롬프트 (예전 write(for:))
//  ├─ oneLine(_:facts:)      .oneLine 의 지시문·프롬프트 (예전 describe(_:))
//  ├─ shortened(_:)          받아 온 글이 너무 길면 문장 단위로 잘라 낸다
//  ├─ materials(for:)        facts 를 무게 순으로 골라 프롬프트에 넣을 목록으로
//  └─ tone(for:)             주제마다 다른 말투 한 줄 (문장 틀이 아니다)
//
//  ⚠️ 모델을 실제로 부르고·실패를 남기는 일은 이 파일에 없다 — ModelCall.generate 가
//     한다. 이 파일이 아는 것은 「무엇을 시킬지」(지시문·프롬프트·재료)와
//     「받은 글을 어떻게 다듬을지」(shortened)뿐이다. 결과 타입 Writing 은
//     Grading/Writing.swift 에 있다(세 writer 가 함께 쓴다).
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.gradeCurrent() 가 오답을 만나면
//    → 창(feedback)을 먼저 띄우고
//    → explain(정답 문항, length: .full) · explain(고른 답의 문항, length: .oneLine) 호출
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
/// **이어지는 짧은 글**입니다. 쪼개 받아 다시 붙이면 이음매가 어색해집니다.
@Generable
struct Commentary {
    @Guide(description: "알려진 사실만 써서 만든 한국어 설명. 띄어쓰기를 포함해 50자 이상 60자 이내")
    let text: String
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
/// | 50~60자 | 어머니는 창을 몇 초 봅니다. 창에서 서너 줄로 끝나는 길이입니다 |
/// | 고른 답을 부정하지 않는다 | 어머니는 **이미 자기가 틀린 걸 압니다** |
/// | 문제 지문을 넣지 않는다 | 「일제의 지배」 같은 낱말이 안전 필터에 걸립니다 (2026-09-06) |
///
/// - Important: 실패해도 **던지지 않습니다.** 해설은 없어도 창이 뜹니다. 실패를 `nil` 로
///   돌려주면 ``ObsRecord/explanation`` 이 `null` 로 남고, **몇 번 실패했는지 셀 수 있습니다.**
struct CommentaryWriter {

    /// 해설 길이의 상한(글자 수, 띄어쓰기 포함). 창에서 **서너 줄**로 끝나는 길이다.
    /// (해설 본문 21pt 기준으로 한 줄에 약 17자가 들어간다.)
    ///
    /// 프롬프트로만 막으면 기기 모델이 종종 넘긴다 — 작은 모델은 글자를 세지 못한다.
    /// 그래서 ``shortened(_:)`` 가 받아 온 글도 한 번 더 자른다.
    private static let maxCharacters = 60

    /// 해설 길이의 **하한.** 이보다 짧으면 창이 허전하고, 알려 주는 것도 적다.
    /// 창에서 세 줄에 해당한다.
    ///
    /// 상한과 달리 이 값은 **코드가 채워 줄 수 없다** — 짧게 온 글에 말을 보탤 수는
    /// 없으니 프롬프트로 부탁하는 수밖에 없다. 코드가 하는 일은 ``shortened(_:)`` 가
    /// **자르다가 이 선 밑으로 떨어뜨리지 않게** 막는 것까지다.
    private static let minCharacters = 50

    /// 자르다가 ``minCharacters`` 밑으로 떨어질 때만 봐주는 길이.
    ///
    /// 「60자에 맞추려고 한 문장을 버렸더니 30자가 됐다」가 제일 나쁘다. 그럴 때는
    /// 차라리 60자를 조금 넘기고 문장을 살린다 — 이 값이 그 "조금"의 한계다.
    private static let overflowLimit = 70

    /// 프롬프트에 넣을 재료의 최대 개수.
    ///
    /// 4개 → 2개로 줄였다가, 길이를 50~60자로 늘리면서 **3개**로 다시 올렸다.
    /// 재료가 2개뿐이면 50자를 채우려고 같은 말을 늘여 쓰게 된다. 반대로 너무 많이
    /// 주면 다 욱여넣으려다 길어지거나 사실을 뭉뚱그려 틀린 말을 만든다.
    /// 어느 3개가 뽑힐지는 ``materials(for:)`` 가 매번 섞으므로 같은 문항이라도 글은 달라진다.
    private static let materialLimit = 3

    /// 해설 길이. 같은 재료로 **몇 줄을 쓸지**만 다르다.
    enum Length {
        /// 50~60자, 짧은 문장 세 개쯤. **정답**을 설명할 때 — 오답 창의 ✅ 줄,
        /// 정답 해설 창, O/X 창.
        case full

        /// 한 문장. **고른 오답**이 무엇인지 알려 줄 때 — 오답 창의 ❌ 줄.
        /// 맞다 틀리다는 말하지 않는다.
        case oneLine
    }

    /// 문항 하나의 ``Question/facts`` 로 **그 문항의 답이 무엇인지** 설명한다.
    ///
    /// 예전에는 `write(for:)`(정답, 50~60자)와 `describe(_:)`(고른 답, 한 문장) 두 함수였다.
    /// 둘 다 「문항 하나의 재료로 그 낱말을 설명한다」는 같은 일이고 길이·지시문만 달라서
    /// 하나로 합쳤다(11차 4-33). 재료 고르기(``materials(for:)``)와 모델 부르기
    /// (`ModelCall.generate`)도 원래부터 같았다. **지시문·프롬프트 문장은 합치면서 한 글자도 안 바꿨다.**
    ///
    /// 추석 문제에 「개천절」을 고르셨다면 —
    /// `explain(개천절 문항, length: .oneLine)` 이 ❌ 줄을, `explain(추석 문항, length: .full)` 이 ✅ 줄을 만든다.
    ///
    /// - Parameters:
    ///   - question: 설명할 답을 가진 문항. `nil` 이면(고른 답이 어느 문항의 정답도 아닐 때,
    ///     예: 「고죠선」 같은 오타) 아무것도 하지 않는다
    ///   - length: 몇 줄로 쓸지
    /// - Returns: 해설. 재료가 없으면 ``Writing/empty``, 실패하면 무엇을 시켰는지가 담긴 ``Writing``
    func explain(_ question: Question?, length: Length) async -> Writing {
        guard let question else { return .empty }

        let facts = materials(for: question)

        // 재료가 없으면 지어내라는 뜻이 된다. 차라리 해설을 안 만든다.
        guard !facts.isEmpty else { return .empty }

        switch length {
        case .full:    return await full(question, facts: facts)
        case .oneLine: return await oneLine(question, facts: facts)
        }
    }

    /// ``Length/full`` — 50~60자의 정답 해설.
    private func full(_ question: Question, facts: [String]) async -> Writing {
        let instructions = """
            당신은 어르신에게 한국의 역사와 제도를 친절하고 다정하고 긍정적으로 즐겁게 알려주는 사람입니다.
            읽는 분은 70대이고 한국어에 서투릅니다.

            [반드시 지킨다]
            1. '알려진 사실'에 있는 것만 씁니다. 거기 없는 연도, 날짜, 숫자, 글자 뜻은 절대 넣지 않습니다.
            2. 글 전체를 띄어쓰기 포함 50자 이상 60자 이내로 씁니다. 50자보다 짧으면 안 됩니다.
            3. 짧은 문장 세 개쯤으로 끝냅니다. 한 문장이 25자를 넘지 않게 합니다.
            4. 재료를 다 쓰려고 하지 않습니다. 가장 중요한 것 하나만 고릅니다.
            5. 답을 문장 안에 그대로 넣습니다.
            6. 답이 아닌 다른 답은 말하지 않습니다.
            7. '문제에 나온 설명처럼' 같은 말을 쓰지 않습니다. 읽는 분에게 문제는 보이지 않습니다.
            8. 쉬운 말로 씁니다. 새로운 어려운 말을 꺼내지 않습니다.
            """

        // 문제 지문은 넣지 않는다. 글자를 설명하는 데 필요 없고,
        // 「일제의 지배」 같은 낱말이 안전 필터에 걸린다 (2026-09-06).
        let prompt = """
            답: \(question.displayAnswer)
            알려진 사실:
            \(facts.map { "· \($0)" }.joined(separator: "\n"))

            위 사실을 자연스럽게 문장을 추가하여 50자 이상 60자 이내(띄어쓰기 포함)로 쓰세요.
            답을 풀어서 부연 설명합니다. 답이 중요하다는 강조는 하지 않고, 쉬운 단어로 아름답게 풀어씁니다.
            """

        // 부르고·받고·실패를 남기는 일은 ModelCall.generate 가 한다 — 이 함수가 아는
        // 것은 「무엇을 시킬지」와 「받은 글을 어떻게 다듬을지」 둘뿐이다.
        //
        // 프롬프트로 길이를 부탁만 하고 끝내지 않는다 — 넘겨 오면 shortened(_:)가 자른다.
        return await ModelCall.generate(
            job: "commentary",
            questionID: question.id,
            instructions: instructions,
            prompt: prompt,
            generating: Commentary.self,
            extract: { Self.shortened($0.text.trimmingCharacters(in: .whitespacesAndNewlines)) })
    }

    /// ``Length/oneLine`` — **고른 답이 무엇인지** 한 문장.
    ///
    /// 어머니가 추석 문제에 「개천절」을 골랐다면, 개천절이 정답인 문항의 재료로
    /// 「개천절은 …이에요」를 만듭니다. **나무라는 것이 아니라 고른 것도 알려 주는 것**입니다.
    private func oneLine(_ question: Question, facts: [String]) async -> Writing {
        let instructions = """
            당신은 어르신에게 한국의 역사와 제도를 알려주는 사람입니다.
            읽는 분은 70대이고 한국어에 서투릅니다.

            [반드시 지킨다]
            1. '알려진 사실'에 있는 것만 씁니다. 거기 없는 것은 절대 넣지 않습니다.
            2. 짧은 문장 두 개쯤으로 끝냅니다. 한 문장이 25자를 넘지 않게 합니다.
            3. 그것이 무엇인지만 말합니다. 맞다 틀리다는 말하지 않습니다.
            4. 쉬운 말로 씁니다.
            5. 글 전체를 띄어쓰기 포함 40자 이상 50자 이내로 씁니다. 30자 보다 짧으면 안됩니다.
            """

        let prompt = """
            낱말: \(question.displayAnswer)

            알려진 사실:
            \(facts.map { "· \($0)" }.joined(separator: "\n"))

            위 사실만 써서 이 낱말이 무엇인지 한 두 문장으로 알려 주세요.
            """

        return await ModelCall.generate(
            job: "note",
            questionID: question.id,
            instructions: instructions,
            prompt: prompt,
            generating: ChoiceNote.self,
            extract: \.text)
    }

    /// 받아 온 해설이 ``maxCharacters`` 를 넘으면 **문장 단위로** 잘라 낸다.
    ///
    /// 프롬프트에 "60자 이내"라고 적어도 기기 모델은 종종 넘긴다 — 글자를 세지
    /// 못하기 때문이다. 그렇다고 글자 수로 뚝 자르면 「단군왕검은 고조선을 세운」
    /// 처럼 말이 끊긴 채로 창에 남는다. 그래서 **문장 끝(. ! ?)을 기준으로** 50자를
    /// 넘지 않는 데까지만 남긴다.
    ///
    /// - Note: 첫 문장 하나가 이미 50자를 넘으면 그 문장은 통째로 남긴다. 조금 길더라도
    ///   말이 끊긴 것보다 낫다. 같은 이유로, 한 문장을 버렸을 때 ``minCharacters``(50자)
    ///   밑으로 떨어진다면 ``overflowLimit``(70자)까지는 그 문장을 살려 둔다.
    private static func shortened(_ text: String) -> String {
        guard text.count > Self.maxCharacters else { return text }

        // 문장 단위로 쪼갠다.
        var sentences: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "." || character == "!" || character == "?" {
                let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty { sentences.append(sentence) }
                current = ""
            }
        }
        // 마침표 없이 끝난 꼬리도 한 문장으로 친다.
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }

        // 50자를 넘지 않는 데까지만 이어 붙인다.
        var kept = ""
        for sentence in sentences {
            let candidate = kept.isEmpty ? sentence : kept + " " + sentence

            if candidate.count > Self.maxCharacters {
                // 첫 문장은 아무리 길어도 받는다 — 빈 창을 띄울 수는 없다.
                let isFirst = kept.isEmpty
                // 여기서 멈추면 50자 밑으로 떨어지는 경우엔, 70자까지 봐주고 살린다.
                let stoppingWouldBeTooShort =
                    kept.count < Self.minCharacters && candidate.count <= Self.overflowLimit

                guard isFirst || stoppingWouldBeTooShort else { break }
            }

            kept = candidate
            if kept.count >= Self.maxCharacters { break }
        }

        return kept.isEmpty ? text : kept
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
