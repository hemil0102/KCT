//
//  Question.swift
//  KCT
//
//  역할 : 문제 한 개의 내용. 그리고 그 문제를 여러 방식으로 물을 재료를 만든다
//  요점 : 문제는 자기 자신만 안다. 문제집 전체를 모르므로 문제집을 갈아끼울 수 있다
//
//  ── 구성 ──────────────────────────────────────────────
//  Question                    문제 한 개 (고정 데이터)
//  ├─ id                       영구 고정. 진척이 이 값으로 연결된다
//  ├─ category / unit          분류 / 단원 (단원은 균등 출제 단위)
//  ├─ question / answer        지문 / 정답(「/」로 여러 표기를 담는다)
//  ├─ displayAnswer            화면·해설에 쓸 대표 표기 — 「/」의 맨 앞엣것
//  ├─ statementFormat          O/X 진술문 틀. "{답}" 자리에 답이 들어간다
//  ├─ kind                     [답의 축 1] 답의 **주제** (AnswerKind) — 해설이 본다
//  ├─ shape                    [답의 축 2] 답의 **모양** (AnswerShape) — 채점이 본다
//  ├─ difficulty               [축 A] 문제 고유 난이도. 고정
//  ├─ facts                    해설에 쓸 사실 조각들. 모델은 여기 있는 것만 쓴다
//  ├─ glossary                 지문 속 어려운 낱말의 뜻 (GlossaryEntry)
//  ├─ init(from:)              손으로 적은 해독기 — 뒤에 더한 칸만 decodeIfPresent
//  ├─ statement(with:)         진술문 만들기
//  ├─ makeChoices(count:answerPool:)   선다형 보기 만들기
//  ├─ makeTrueFalse(answerPool:)       O/X 문항 만들기
//  └─ correctedStatementParts()        O/X 해설의 「바르게 고친 문장」 앞뒤
//
//  이 파일 안의 형제 타입 (같이 쓰이고 같이 바뀐다 — 규칙 24)
//  ├─ QuestionPayload          문제집 파일 한 벌 (version + questions)
//  ├─ QuestionFact             해설에 쓸 사실 한 조각 (kind · weight · text)
//  └─ GlossaryEntry            어려운 낱말 하나 (word · gloss · relatedWords · referenceSentence)
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizItem.make() 가 묻는 방식을 정한 뒤
//    → makeChoices() / makeTrueFalse() 를 불러 재료를 받는다
//    → 오답 보기는 answerPool(다른 문제들의 정답)에서 뽑는다
//    → 만들어진 재료는 ModePayload 에 담겨 화면으로 간다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizItem.make(), QuestionCatalog, CommentaryWriter(facts 를 읽는다)
//  기대는 것    : AnswerKind·AnswerShape 두 열거형과 Foundation 뿐 —
//                이 파일은 화면도 진척도 모델도 모른다
//  건드리지 않는 것 : 맞은/틀린 기록 — 그것은 QuestionProgress 의 몫이다
//

import Foundation

/// 퀴즈 문제 한 개. 변하지 않는 고정 데이터입니다.
///
/// 맞은/틀린 기록은 ``QuestionProgress`` 로 분리해 두어, 문제집을 갈아끼워도
/// 학습 기록이 살아남습니다. 오답 보기용 "다른 문제들의 정답" 을 인자로 받는 것도
/// 문제 하나가 문제집 전체를 알면 교체가 불가능해지기 때문입니다.
///
/// - Important: ``id`` 를 재사용하면 학습 기록이 엉뚱한 문제에 붙습니다.
struct Question: Identifiable, Codable, Hashable {
    /// 문제 고유 번호. 절대 재사용하지 않는다.
    let id: Int

    /// 상위 분류 (예: "역사")
    let category: String

    /// 단원 (예: "역사1") — 신규 문제를 고르게 도입하는 단위
    let unit: String

    /// 문제 지문
    let question: String

    /// 정답
    let answer: String

    /// 화면과 해설에 쓸 **대표 표기**. `/` 로 여러 표기를 적었으면 맨 앞엣것.
    ///
    /// ``answer`` 는 채점이 인정할 표기를 **전부** 담습니다 — 「삼일절/3.1절/31절」.
    /// 사람에게 보일 때는 하나여야 하므로 맨 앞을 씁니다. JSON 에는 정식 명칭을 맨 앞에 둡니다.
    ///
    /// - Note: `/` 를 아는 곳은 여기와 ``AnswerMatcher`` 뿐입니다.
    var displayAnswer: String {
        String(answer.split(separator: "/").first ?? "")
    }

    /// O/X 용 진술문 틀. `{답}` 자리에 답이 들어갑니다.
    ///
    /// 의문문을 코드로 진술문으로 바꾸면 어색해져서 문제마다 사람이 직접 적어 둡니다.
    let statementFormat: String

    /// 정답의 종류. 해설을 어떤 방식으로 쓸지 정한다.
    let kind: AnswerKind
    
    /// 답의 모양. 채점이 이것을 본다. 대부분은 ``AnswerShape/word`` 다.
    var shape: AnswerShape = .word
    
    /// [축 A] 문제 고유 난이도. 고정이며 신규 문제의 도입 순서만 정합니다.
    ///
    /// - Important: "얼마나 마스터했나"(축 B, ``QuestionProgress/mode``)와는 다른 축이며,
    ///   두 축을 섞으면 설계가 무너집니다.
    let difficulty: Int
    
    /// 해설에 쓸 사실 조각. 모델은 여기 있는 것만 씁니다.
    var facts: [QuestionFact] = []
    
    /// 지문 속 어려운 낱말들의 뜻. 모든 문항에 있지는 않습니다(11차 기준 50문항 중 39개).
    var glossary: [GlossaryEntry] = []
    
    // MARK: - 해독

    /// 손으로 적은 해독기.
    ///
    /// 자동 생성되는 것은 **기본값을 쓰지 않아** 파일에 칸이 없으면 던집니다.
    /// 뒤에 더한 칸(``shape``·``facts``·``glossary``)은 옛 파일에 없는 것이 정상이므로
    /// 그 셋만 `decodeIfPresent` 로 받습니다.
    ///
    /// - Note: JSON 에 남아 있는 `tags` 키는 **읽지 않습니다.** 넣어 두기만 하고 읽는
    ///   곳이 없어 2026-09-23 리팩토링에서 프로퍼티를 지웠습니다 (`Refactoring.md` 1단계).
    ///   `Codable` 은 모르는 키를 조용히 넘기므로 데이터 파일은 그대로 둡니다.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)

        id              = try box.decode(Int.self,        forKey: .id)
        category        = try box.decode(String.self,     forKey: .category)
        unit            = try box.decode(String.self,     forKey: .unit)
        question        = try box.decode(String.self,     forKey: .question)
        answer          = try box.decode(String.self,     forKey: .answer)
        statementFormat = try box.decode(String.self,     forKey: .statementFormat)
        kind            = try box.decode(AnswerKind.self, forKey: .kind)
        difficulty      = try box.decode(Int.self,        forKey: .difficulty)

        shape = try box.decodeIfPresent(AnswerShape.self, forKey: .shape) ?? .word
        
        facts = try box.decodeIfPresent([QuestionFact].self, forKey: .facts) ?? []
        
        glossary = try box.decodeIfPresent([GlossaryEntry].self, forKey: .glossary) ?? []

    }
}

/// 문제집 파일의 내용.
///
/// 배열이 아니라 객체로 감싸 두어야 나중에 칸을 더해도 기존 디코더가 안 깨집니다.
struct QuestionPayload: Codable {
    let version: Int
    let questions: [Question]
}

/// 해설에 쓸 사실 한 조각.
///
/// 조각으로 쪼개 두는 이유 — 해설은 세 문장이라 다 못 씁니다. **무게 높은 순으로 몇 개만
/// 골라 넣고, 같은 무게끼리는 섞어서** 같은 문항이라도 해설이 달라지게 합니다.
/// 사실은 늘 같고 고르는 조각만 달라집니다.
struct QuestionFact: Codable, Hashable {
    /// 재료의 종류. 다섯 가지를 씁니다.
    ///
    /// - ~~`asks`~~ — **더 쓰지 않는다**(11차 4-34). 질문 안내라 모델이 해설에 섞어 썼다
    /// - `wordplay` — **글자의 뜻.** 「광복은 빛을 되찾았다는 뜻이에요」. 가장 잘 남는 재료다
    /// - `event` — 그날 무슨 일이 있었나. 「만세를 부르며 독립을 외친 날이에요」
    /// - `date` — 양력·음력을 밝힌 날짜. 「양력 8월 15일이에요」
    /// - `nation` — **어느 나라 사람인가.** 왕과 시조에는 반드시 넣는다
    /// - `mark` — 한 줄 특징. 「한가위라고도 불러요」
    ///
    /// - Important: **헷갈리는 다른 답을 끌어오지 않습니다.** 「조선은 훨씬 뒤의 나라예요」처럼
    ///   적으면 외울 것이 둘이 됩니다. 재료는 **그 답 하나만** 설명합니다.
    let kind: String

    /// 먼저 쓸 순서. 높을수록 먼저.
    var weight: Int = 1

    let text: String
    
    init(kind: String, weight: Int = 1, text: String) {
        self.kind = kind
        self.weight = weight
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        kind   = try box.decode(String.self, forKey: .kind)
        text   = try box.decode(String.self, forKey: .text)
        weight = try box.decodeIfPresent(Int.self, forKey: .weight) ?? 1
    }
}

/// 지문 속 어려운 낱말 하나의 뜻. 1단계에서 `questions.json`에 이미 채워 뒀습니다.
struct GlossaryEntry: Codable, Hashable {
    /// 지문에 실제로 나오는 글자 그대로.
    let word: String

    /// 짧고 쉬운 뜻. 10~20자로 이미 다듬어 놓았습니다.
    let gloss: String

    /// **비슷한 낱말** 목록. 대부분 비어 있습니다(11차 기준 87개 중 9개만 있음).
    ///
    /// 낱말 사전 시트에서 낱말 배지 오른쪽에 「비슷한 낱말 — …」로 바로 보여줍니다.
    ///
    /// - Note: JSON 키는 여전히 `examples` 입니다(아래 ``CodingKeys``). 담긴 것이
    ///   예문이 아니라 낱말이라 이름이 거짓말을 하고 있어서 2026-09-23 리팩토링에서
    ///   Swift 이름만 고쳤습니다 — `questions.json` 은 한 글자도 안 바꿉니다
    ///   (`Refactoring.md` 9단계).
    var relatedWords: [String] = []

    /// 사람이 미리 써 둔 참고 예문. "기리다"처럼 Foundation Models 가 활용형을
    /// 헷갈리는 낱말에 한해 채워 둔다 — 있으면 ``GlossaryExampleWriter`` 가 이 문장을
    /// 참고해서 만들고, 없으면(대부분) 모델이 알아서 만든다.
    ///
    /// - Note: ``relatedWords``(비슷한 낱말 목록)와 헷갈리지 않도록 이름을 나눠 뒀다 —
    ///   이건 낱말이 아니라 **문장 하나**다.
    var referenceSentence: String? = nil

    /// `relatedWords` 만 JSON 키가 다르다 — 데이터 파일을 안 건드리려고 여기서 맵핑한다.
    enum CodingKeys: String, CodingKey {
        case word
        case gloss
        case relatedWords = "examples"
        case referenceSentence
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        word     = try box.decode(String.self, forKey: .word)
        gloss    = try box.decode(String.self, forKey: .gloss)
        relatedWords = try box.decodeIfPresent([String].self, forKey: .relatedWords) ?? []
        referenceSentence = try box.decodeIfPresent(String.self, forKey: .referenceSentence)
    }
}

// MARK: - 묻는 방식별 재료 만들기

//❓구조 파악하고 학습하기
extension Question {

    /// 주어진 답을 넣은 O/X 진술문.
    func statement(with candidate: String) -> String {
        statementFormat.replacingOccurrences(of: "{답}", with: candidate)
    }

    /// O/X 해설에 쓸 **바르게 고친 문장**의 앞뒤. 가운데에는 정답이 들어간다.
    ///
    /// 틀 끝의 「{답}이다.」를 받침에 맞춰 「이에요 / 예요」로 바꾼다 — 어머니에게
    /// 건네는 해설이라 문제 문장의 딱딱한 끝을 쓰지 않는다(고조선**이에요**, 태극기**예요**).
    /// 틀이 그 모양이 아니면 원래 끝을 그대로 둔다.
    func correctedStatementParts() -> (before: String, after: String) {
        let parts = statementFormat.components(separatedBy: "{답}")
        let before = parts.first ?? ""
        let rawAfter = parts.count > 1 ? parts[1...].joined(separator: "{답}") : ""

        guard rawAfter.hasPrefix("이다") else { return (before, rawAfter) }

        let ending = displayAnswer.endsWithFinalConsonant ? "이에요" : "예요"
        return (before, ending + rawAfter.dropFirst(2))
    }

    /// 선다형 보기를 만듭니다. 정답 1개 + 오답 `count - 1` 개를 섞어 돌려줍니다.
    ///
    /// 오답을 다른 문제의 정답에서 뽑으므로 그럴듯하고, 문제집이 바뀌면 보기도 따라
    /// 바뀌어 문제마다 오답을 손으로 적어 둘 필요가 없습니다.
    func makeChoices(count: Int, answerPool: [String]) -> (options: [String], correct: String) {
        let distractors = Array(
            Set(answerPool).subtracting([displayAnswer]).shuffled().prefix(max(0, count - 1))
        )
        return ((distractors + [displayAnswer]).shuffled(), displayAnswer)
    }

    /// O/X 문항을 만듭니다.
    ///
    /// 절반 확률로 정답을, 절반 확률로 오답을 넣습니다. 늘 정답만 넣으면 "맞아요" 만
    /// 눌러도 다 맞게 되어 O/X 가 의미를 잃습니다.
    func makeTrueFalse(answerPool: [String]) -> (statement: String, candidate: String, isTrue: Bool) {
        let candidate: String
        if Bool.random() {
            candidate = displayAnswer
        } else {
            candidate = Set(answerPool).subtracting([displayAnswer]).randomElement() ?? displayAnswer
        }
        return (statement(with: candidate), candidate, candidate == displayAnswer)
    }
}

private extension String {
    /// 마지막 글자에 받침이 있는가. 한글 음절이 아니면 `false`.
    var endsWithFinalConsonant: Bool {
        guard let scalar = last?.unicodeScalars.first,
              (0xAC00...0xD7A3).contains(scalar.value) else { return false }
        return (scalar.value - 0xAC00) % 28 != 0
    }
}
