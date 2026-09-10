//
//  AnswerKind.swift
//  KCT
//
//  역할 : 정답이 어떤 종류인가. 해설을 어떤 방식으로 쓸지 정한다
//  요점 : 사람 이름은 글자를 풀 수 없고, 제도는 글자를 푸는 게 가장 좋다
//
//  ── 구성 ──────────────────────────────────────────────
//  AnswerKind   아홉 가지. 답의 「주제」 - 모양은 AnswerShape 가 맡는다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : Question(문항이 들고 다닌다) · CommentaryWriter(지침을 고른다)
//  기대는 것    : 없음
//  건드리지 않는 것 : 해설 문장 - 어떻게 쓸지는 CommentaryWriter 가 정한다
//

import FoundationModels

/// 답의 **모양**. ``AnswerKind`` 가 「무엇이냐」라면 이것은 「어떻게 생겼나」다.
///
/// 축을 나누는 이유 — 「고구려, 백제, 신라」는 목록이면서 동시에 ``AnswerKind/place`` 입니다.
/// 하나의 열거형에 넣으면 둘 중 하나를 잃습니다.
///
/// - Note: 채점은 이것을 보고, 해설은 ``AnswerKind`` 를 봅니다. 쓰는 쪽이 다릅니다.
enum AnswerShape: String, Codable {
    /// 한 낱말 — 고조선, 세종대왕, 태극기
    case word
    /// 여러 항목을 **다** 대야 한다 — "고구려, 백제, 신라"
    case closedList
    /// 보기 중 **몇 개만** 대면 된다 — "팔만대장경, 직지심체요절, 고려청자 등"
    case openList
    /// 설명 문장 — "널리 인간을 이롭게 한다"
    case sentence
}

/// 정답이 어떤 종류인가. 이 값에 따라 ``CommentaryWriter`` 가 다른 지침을 씁니다.
///
/// 사람 이름에 글자 풀이를 붙이면 거짓이 나오고, 제도 이름은 반대로 글자 풀이가
/// 가장 잘 통하기 때문입니다.
///
/// - Important: 앞의 둘은 답의 모양으로, 나머지는 주제로 정합니다 — 「고구려, 백제,
///   신라」가 ``list`` 인 것은 외울 때 필요한 것이 「셋을 다 대는 것」이라서입니다.
enum AnswerKind: String, Codable, CaseIterable {
    case number
    /// 사람 — 안익태, 주몽, 세종대왕
    case person
    /// 나라와 땅 — 고조선, 백두산, 서울
    case place
    /// 기념일과 명절 — 개천절, 추석
    case day
    /// 사건과 전쟁 — 3.1운동, 6.25전쟁
    case event
    /// 물건·음식·옷·놀이·상징 — 태극기, 김치, 온돌
    case thing
    /// 문화유산·책·옛이야기 — 석굴암, 팔만대장경, 단군신화
    case heritage
    /// 제도·기관·권리 — 민주주의, 대법원, 기본권
    case system
    /// 생활 절차·서류·호칭 — 혼인신고, 등기부등본, 아주버님
    case procedure
}

/// 답이 어디서 왔는가.
///
/// 같은 글자라도 **손으로 친 것과 말로 한 것은 다르게 봐야** 합니다.
/// 「고죠선」은 손으로 쳤으면 오타지만, 말로 했으면 **인식기가 잘못 적은 것**입니다.
/// 앞은 오답으로 둬도 곧 다시 만나 회복되고, 뒤는 **맞혔는데 틀렸다고 하는 것**입니다.

enum AnswerSource: String, Codable {
    case typed
    case voice
}

/// **모델이** 고르는 판정 근거.
///
/// 코드가 정하는 것(``MatchBasis``)은 여기 없습니다. `@Generable` 이라 모델은 이 목록에서만
/// 고를 수 있는데, 코드가 이미 거른 뒤 넘어온 건에 「글자가 그대로 같다」를 고를 수 있으면
/// **로그가 거짓말을 합니다.** 3단계의 목적이 근거를 숫자로 보는 것이므로 그 숫자부터 참이어야 합니다.
@Generable
enum CheckBasis {
    /// 여러 항목을 다 댔다 — 순서는 달라도 된다
    case listMatch
    /// 군더더기를 걷어내니 같다
    case afterTrimming
    /// 글자는 다르지만 뜻이 같다 — 설명 문장에서만
    case sameMeaning
    /// 한 글자 이상 다르다
    case differentLetters
    /// 아예 다른 이름이다
    case differentName
    /// 답을 둘 이상 대고 정하지 않았다
    case undecided
    /// 여러 항목 중 일부만 말했다
    case partialList
}

/// **코드가** 정하는 판정 근거. ``AnswerMatcher`` 만 만듭니다.
enum MatchBasis: String {
    /// 글자가 그대로 같다
    case exactMatch
    /// 발음이 같다 — 음성 입력에서만
    case phoneticMatch
    /// 한 글자만 다르다 — 오타
    case typo
    /// 목록의 항목이 맞지 않는다
    case listMismatch
}
