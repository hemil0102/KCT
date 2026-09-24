//
//  MatchingSetCatalog.swift
//  KCT
//
//  역할 : 앱이 쓰는 연결 문제 세트를 들고 있는 창구. QuestionCatalog 의 짝
//  요점 : questions.json 을 건드리지 않고, 같은 「받아 둔 것 먼저, 없으면 번들」
//         규칙을 matchingSets.json 에도 그대로 적용한다
//
//  ── 구성 ──────────────────────────────────────────────
//  MatchingSetCatalog (@Observable)
//  ├─ version         묶음 버전. 서버 것이 더 높을 때만 교체
//  ├─ sets            연결 문제 세트 목록
//  ├─ loaded()        받아 둔 것 먼저, 없으면 번들
//  ├─ replace(with:)  통째 교체 — 안전한 시점에만
//  └─ randomSet()     세트 중 하나를 무작위로 고른다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KCTApp(생성 → 환경에 실음), QuizSession.start()(randomSet() 으로 뽑음)
//  기대는 것    : ContentFile, MatchingSet
//  건드리지 않는 것 : QuestionCatalog — 두 문제 체계는 서로 모른다.
//                    어느 칸에 넣을지 — QuizSession 이 3·4·5번째 중 하나로 정한다
//
//  ── 지금 상태 ──────────────────────────────────────────
//  회차에 **이미 붙어 있다.** QuizSession.start() 가 randomSet() 으로 한 세트를 뽑고,
//  3·4·5번째 칸(0부터 세면 2·3·4) 중 하나를 그 자리로 예약한다 — 일반 문제는 그만큼
//  덜 뽑아 회차 길이(7칸)가 그대로 유지된다. 6번째 칸을 음성 입력 문제로 비워 두려던
//  계획은 그 유형이 아직 없어 지금은 일반 문제가 온다.
//

import Foundation
import Observation

@Observable
final class MatchingSetCatalog {

    /// 묶음 버전. 서버 것이 더 높을 때만 내려받는다.
    private(set) var version: Int

    /// 연결 문제 세트 목록.
    private(set) var sets: [MatchingSet]

    init(payload: MatchingSetPayload) {
        self.version = payload.version
        self.sets = payload.sets
    }

    /// 앱이 쓸 연결 문제 세트를 읽어 온다. **받아 둔 것 먼저, 없으면 번들.**
    ///
    /// 둘 다 실패하면 빈 목록을 돌려준다 — 아직 이 문제 유형을 회차에 강제로
    /// 끼워 넣지 않으므로, 비어 있어도 앱의 다른 부분은 영향받지 않는다.
    static func loaded() -> MatchingSetCatalog {
        MatchingSetCatalog(
            payload: ContentFile<MatchingSetPayload>(fileName: "matchingSets")
                .loadPreferringDownloaded(
                    isEmpty: { $0.sets.isEmpty },
                    fallback: MatchingSetPayload(version: 0, sets: []),
                    failureMessage: "연결 문제 묶음을 읽지 못했습니다"))
    }

    /// 묶음을 통째로 교체한다. 버전이 더 높고 내용이 비어 있지 않을 때만 바꾼다.
    func replace(with payload: MatchingSetPayload) {
        guard payload.version > version, !payload.sets.isEmpty else { return }

        version = payload.version
        sets = payload.sets
    }

    /// 세트 중 하나를 무작위로 고른다. 목록이 비어 있으면 `nil`.
    func randomSet() -> MatchingSet? {
        sets.randomElement()
    }
}
