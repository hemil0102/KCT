//
//  ObsRecord.swift
//  KCT
//
//  역할 : 어머니가 문항 하나를 푼 사건을 그대로 한 줄로 남긴다
//  요점 : 계산된 값은 저장하지 않는다. 일어난 일만 적고, 평균·합계는 나중에 센다
//
//  ── 구성 ──────────────────────────────────────────────
//  ObsRecord                   문항 하나의 관찰 기록 (@Model)
//  ├─ sessionID                한 회차를 묶는 번호. 회차마다 새로 만든다
//  ├─ askedAt                  문제가 화면에 뜬 절대 시각
//  ├─ questionID               어느 문항이었나 (Question.id)
//  ├─ secToFirstTouch          뜬 순간 → 처음 답에 손댄 순간 (못 잡으면 nil)
//  ├─ secToSubmit              뜬 순간 → 「다음」을 누른 순간
//  ├─ isCorrect                맞혔나
//  ├─ modeRaw / mode           어떤 방식으로 물었나 (AskingMode)
//  ├─ wasFirstEver             이번이 어머니가 이 문항을 처음 본 때인가
//  ├─ affectsProgress          격려용 슬롯이었나 (false 면 일부러 쉽게 낸 것)
//  ├─ uploadedAt               서버로 올라간 시각. nil 이면 아직 안 올라간 것
//  └─ hesitationSec            고르고 나서 망설인 초 (secToSubmit - secToFirstTouch)
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession 이 회차를 시작할 때 sessionID 를 하나 만들고
//    → 문제가 뜰 때 askedAt 을 기억해 둔다
//    → 답에 처음 손댈 때 firstTouch 시각을 기억해 둔다
//    → 「다음」을 누를 때 두 간격을 재서 임시로 들고 있는다
//    → 채점이 끝나 정오답이 정해지면 그때 ObsRecord 를 만들어 저장한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession (쓰기), 나중에 내보내기·업로드 (읽기)
//  기대는 것    : AskingMode(묻는 방식 이름), SwiftData
//  건드리지 않는 것 : 학습 진척 — QuestionProgress 는 "어디까지 왔나" 이고
//                    이 타입은 "무슨 일이 있었나" 다. 섞지 않는다
//
//

import Foundation
import SwiftData

/// 어머니가 문항 하나를 푼 **사건 하나**의 기록.
///
/// ``QuestionProgress`` 와 성격이 다릅니다. 진척은 **덮어쓰이는 현재 상태**(지금
/// 사다리 몇 칸인가)이고, 이것은 **쌓이기만 하는 과거**입니다. 같은 문항을 열 번
/// 풀면 진척은 한 줄이지만 이 기록은 열 줄이 됩니다.
///
/// ## 계산되는 것은 저장하지 않는다
///
/// 「전체 평균 대기」·「회차에 걸린 총 시간」·「이 문항을 몇 번 봤나」는 전부
/// 여기 없습니다. `sessionID` 로 묶어 세면 나오기 때문입니다. 미리 계산해 넣으면
/// **원본과 요약이 어긋나는 날**이 오고, 그때 어느 쪽이 맞는지 알 수 없게 됩니다.
///
/// - Note: `@Attribute(.unique)` 가 하나도 없습니다. 일부러입니다 — 같은 문항의
///   같은 회차 기록이 여러 줄일 수 있어야 사건을 있는 그대로 남길 수 있습니다.
@Model
final class ObsRecord {
    /// 한 회차를 묶는 번호. 회차가 시작될 때 하나 만들어 그 회차의 다섯 줄이 공유한다.
    ///
    /// 이것 하나로 「이번 회차 평균 대기」와 「회차에 걸린 총 시간」이 나옵니다.
    var sessionID: UUID

    /// 문제가 화면에 뜬 **절대 시각**.
    ///
    /// 간격(초)만 있으면 "언제 공부했나" 를 알 수 없습니다. 저녁 8시의 30초와
    /// 새벽 2시의 30초는 다른 사건입니다.
    var askedAt: Date

    /// 어느 문항이었나. ``Question`` 의 `id`.
    var questionID: Int

    /// 문제가 뜬 순간부터 **처음 답에 손댄** 순간까지 걸린 초.
    ///
    /// 「생각한 시간」에 가깝습니다. 답을 바꿔도 **처음 손댄 때만** 셉니다.
    ///
    /// - Note: `Double?` 인 이유 — 못 잡은 경우를 `0` 으로 적으면 "0초 만에 골랐다"
    ///   라는 **거짓말**이 됩니다. 모르는 것은 `nil` 로 남깁니다.
    var secToFirstTouch: Double?

    /// 문제가 뜬 순간부터 **「다음」을 누른** 순간까지 걸린 초.
    ///
    /// 종이 기록지의 「멈춤」 칸에 대응합니다.
    /// ``secToFirstTouch`` 를 빼면 **고르고 나서 망설인 시간**이 나옵니다.
    var secToSubmit: Double

    /// 맞혔나. 채점이 끝난 뒤에 정해지므로 이 기록은 **채점 후에** 만들어진다.
    var isCorrect: Bool

    /// 어떤 방식으로 물었는지 (``AskingMode`` 의 rawValue, 0..3).
    ///
    /// 방식을 안 남기면 시간을 해석할 수 없습니다. 2지선다 30초와 직접입력 30초는
    /// 전혀 다른 일입니다.
    var modeRaw: Int

    /// 이번이 어머니가 이 문항을 **처음 본** 때인가.
    ///
    /// 스토리 모드가 없어 모르는 문항이 예고 없이 나옵니다. 그때 어떻게 하시는지가
    /// 4차의 힌트를 언제 낼지 정합니다.
    var wasFirstEver: Bool

    /// 격려용(첫·마지막) 슬롯이었나. `false` 면 일부러 쉽게 낸 문항이다.
    ///
    /// 이걸 안 남기면 격려용의 쉬운 정답이 통계에 섞여 **실력이 좋아 보입니다.**
    var affectsProgress: Bool

    /// 서버로 올라간 시각. `nil` 이면 **아직 안 올라간 것**이다.
    ///
    /// 이 한 줄이 재시도 큐 전부입니다. 회차를 시작할 때 `nil` 인 줄을 모아
    /// 다시 보내므로, 와이파이가 끊겼든 Supabase 무료 플랜이 잠들었든
    /// **다음번에 따라잡습니다.** 업로드 실패를 화면에 알릴 필요가 없어지는 것도
    /// 이 필드 덕입니다 — 알려 봐야 어머니는 할 수 있는 일이 없습니다.
    ///
    /// - Note: `init` 에 인자를 더하지 않습니다. 옵셔널 저장 프로퍼티는 **자동으로
    ///   `nil` 로 시작**하므로, 새로 만든 줄은 전부 "아직 안 올라감" 으로 태어납니다.
    var uploadedAt: Date?
    
    init(
        sessionID: UUID,
        askedAt: Date,
        questionID: Int,
        secToFirstTouch: Double?,
        secToSubmit: Double,
        isCorrect: Bool,
        modeRaw: Int,
        wasFirstEver: Bool,
        affectsProgress: Bool
    ) {
        self.sessionID = sessionID
        self.askedAt = askedAt
        self.questionID = questionID
        self.secToFirstTouch = secToFirstTouch
        self.secToSubmit = secToSubmit
        self.isCorrect = isCorrect
        self.modeRaw = modeRaw
        self.wasFirstEver = wasFirstEver
        self.affectsProgress = affectsProgress
    }
    
    /// 저장된 숫자를 묻는 방식으로 읽는다. 알 수 없는 값이면 가장 쉬운 칸으로 본다.
    var mode: AskingMode { AskingMode(rawValue: modeRaw) ?? .binaryChoice }
    
    /// 고르고 나서 「다음」을 누르기까지 망설인 초. 첫 손댐을 못 잡았으면 `nil`.
    var hesitationSec: Double? {
        guard let touch = secToFirstTouch else { return nil }
        return secToSubmit - touch
    }
    
}
