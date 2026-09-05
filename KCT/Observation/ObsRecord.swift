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
//  ├─ chosen                   어머니가 실제로 낸 답 (틀렸을 때 무엇을 골랐나)
//  ├─ reason                   모델이 그렇게 판정한 이유 (직접입력에서만 생긴다)
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
/// ``QuestionProgress`` 는 덮어쓰이는 현재 상태이고, 이것은 쌓이기만 하는 과거입니다.
/// 평균·합계처럼 계산되는 값은 저장하지 않습니다 — 원본과 요약이 어긋나면 어느 쪽이 맞는지 알 수 없게 되기 때문입니다.
///
/// - Note: `@Attribute(.unique)` 가 하나도 없는 것은 일부러입니다. 같은 문항의 기록이 여러 줄일 수 있어야 합니다.
@Model
final class ObsRecord {
    /// 한 회차를 묶는 번호. 회차가 시작될 때 하나 만들어 그 회차의 기록들이 공유합니다.
    ///
    /// 이것 하나로 회차별 평균 대기와 걸린 총 시간을 셀 수 있습니다.
    var sessionID: UUID

    /// 문제가 화면에 뜬 **절대 시각**.
    ///
    /// 간격(초)만 있으면 언제 공부했는지 알 수 없습니다 — 저녁 8시의 30초와 새벽 2시의 30초는 다른 사건입니다.
    var askedAt: Date

    /// 어느 문항이었나. ``Question`` 의 `id`.
    var questionID: Int

    /// 문제가 뜬 순간부터 **처음 답에 손댄** 순간까지 걸린 초. 답을 바꿔도 처음 손댄 때만 셉니다.
    ///
    /// - Note: 못 잡은 경우를 `0` 으로 적으면 0초 만에 골랐다는 거짓말이 되므로 `nil` 로 남깁니다.
    var secToFirstTouch: Double?

    /// 문제가 뜬 순간부터 **「다음」을 누른** 순간까지 걸린 초.
    ///
    /// ``secToFirstTouch`` 를 빼면 고르고 나서 망설인 시간이 나옵니다.
    var secToSubmit: Double

    /// 맞혔나. 채점이 끝난 뒤에 정해지므로 이 기록은 **채점 후에** 만들어진다.
    var isCorrect: Bool

    /// 어떤 방식으로 물었는지 (``AskingMode`` 의 rawValue, 0..3).
    ///
    /// 방식을 안 남기면 시간을 해석할 수 없습니다 — 2지선다 30초와 직접입력 30초는 전혀 다른 일입니다.
    var modeRaw: Int

    /// 이번이 어머니가 이 문항을 **처음 본** 때인가.
    ///
    /// 모르는 문항을 예고 없이 만났을 때 어떻게 하시는지가 4차의 힌트를 언제 낼지 정합니다.
    var wasFirstEver: Bool

    /// 격려용(첫·마지막) 슬롯이었나. `false` 면 일부러 쉽게 낸 문항입니다.
    ///
    /// 이걸 안 남기면 격려용의 쉬운 정답이 통계에 섞여 실력이 좋아 보입니다.
    var affectsProgress: Bool

    /// 어머니가 실제로 낸 답.
    ///
    /// `isCorrect` 만으로는 헷갈리신 것인지 모르시는 것인지 못 가려, 무엇을 고르셨는지 남깁니다.
    /// 한때 복잡하지 않게 하려고 뺐다가 2026-08-28 관찰에서 넣을 이유가 생겨 되살린 필드입니다.
    var chosen: String?

    /// 모델이 그렇게 판정한 이유. 직접입력이 아니면 `nil` 입니다 — 규칙 채점은 설명할 것이 없습니다.
    ///
    /// 2026-08-31 에 「단군신화」가 「단군왕검」의 정답으로 통과했을 때 판단 근거가 남지 않아, 지침을 고쳐도 고쳐졌는지 확인할 수 없었습니다.
    ///
    /// - Important: 모델의 말이지 사실이 아니므로 진단에만 쓰고 근거로 삼지 않습니다.
    var reason: String?

    /// 오답일 때 ``CommentaryWriter`` 가 만든 해설. 정답이거나 만들지 못했으면 `nil` 입니다.
    var explanation: String?
    /// 서버로 올라간 시각. `nil` 이면 **아직 안 올라간 것**입니다.
    ///
    /// 이 한 줄이 재시도 큐 전부입니다 — 회차를 시작할 때 `nil` 인 줄을 모아 다시 보내므로 다음번에 따라잡습니다.
    ///
    /// - Note: 옵셔널 저장 프로퍼티는 자동으로 `nil` 로 시작하므로 `init` 인자에 없습니다.
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
        affectsProgress: Bool,
        chosen: String?,
        reason: String?,
        explanation: String?
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
        self.chosen = chosen
        self.reason = reason
        self.explanation = explanation
    }
    
    /// 저장된 숫자를 묻는 방식으로 읽습니다. 알 수 없는 값이면 가장 쉬운 칸으로 봅니다.
    var mode: AskingMode { AskingMode(rawValue: modeRaw) ?? .binaryChoice }
    
    /// 고르고 나서 「다음」을 누르기까지 망설인 초. 첫 손댐을 못 잡았으면 `nil` 입니다.
    var hesitationSec: Double? {
        guard let touch = secToFirstTouch else { return nil }
        return secToSubmit - touch
    }
    
}
