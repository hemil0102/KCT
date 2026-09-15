//
//  GlossaryComposer.swift
//  KCT
//
//  역할 : 낱말 사전 시트에 보여줄 짧은 예문 하나를 온디바이스 모델로 만든다
//  요점 : 실패(기기 미지원 · 세이프티 가드레일 등)해도 무엇을 시켰는지를
//        ModelFailureDraft 로 남긴다 — CommentaryWriter 와 같은 방식이다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (낱말 탭 → onTapWord)
//  기대는 것    : FoundationModels, Writing·ModelFailureDraft(CommentaryWriter.swift ·
//                ModelFailure.swift 에 정의된 것을 그대로 재사용)
//  건드리지 않는 것 : 실패를 서버로 올리는 것 — QuestionScreen 이 돌려받은 실패를
//                    session.saveFailures(...) 로 넘기면, 실제 업로드는 다른 모델
//                    실패(commentary·note)와 같은 경로(ObsUploader.uploadPendingFailures())를
//                    그대로 탄다. Supabase 대시보드에서 model_failure 표를
//                    job = 'glossary_example' 로 걸러 보면 어떤 프롬프트가
//                    안전 필터에 걸렸는지 그대로 볼 수 있다.
//
//  ⚠️ DEBUG 빌드에서만, 세이프티 가드레일 위반(guardrailViolation)이면 애플
//     Feedback Assistant 에 첨부할 .json 파일도 문서 폴더에 남긴다
//     (session.logFeedbackAttachment). 그 파일을 꺼내려면 Xcode로 기기에
//     연결해야 하므로, 어머니가 쓰는 실기기(RELEASE)에는 안 쌓아 둔다.
//
//  Created by harryho on 9/15/26.
//

import FoundationModels
import SwiftUI
import Foundation

@Generable
struct GlossaryExample {
    @Guide(description: "낱말이 반드시 그대로 포함된 구체적인 예문. 50~80자로 쓴다. 뜻은 넣지 않는다")
    let wordSentence: String

    @Guide(description: "뜻을 자연스럽게 넣은 구체적인 예문. 50~80자로 쓴다. 낱말은 넣지 않는다")
    let glossSentence: String
}

/// 낱말 사전 시트의 생성 예문 하나를 만든다.
///
/// 기기가 Apple Intelligence 를 지원하지 않으면 아무 것도 시키지 않고 곧바로
/// ``Writing/empty``를 돌려준다 — 보낸 게 없으니 남길 실패도 없다. 모델을 실제로
/// 불렀는데 실패하면(세이프티 가드레일 위반도 여기 포함된다) 그 자리에서 보낸
/// 지시문 · 프롬프트를 ``ModelFailureDraft`` 에 그대로 담아 돌려준다.
///
/// - Parameter questionID: 이 낱말이 나온 문항의 id. 실패 기록에 붙여 어느
///   문항에서 어떤 낱말을 탭했을 때 걸렸는지 나중에 되짚을 수 있게 한다.
func composeExample(
    word: String, gloss: String, relatedWords: [String] = [], referenceSentence: String? = nil,
    questionText: String, questionID: Int
) async -> Writing {
    guard case .available = SystemLanguageModel.default.availability else {
        // 기기가 지원 안 하면 시도조차 안 한다 — 남길 프롬프트가 없으므로 실패
        // 기록도 없다. 패널은 JSON 의 examples(있으면)로 대신 보여준다.
        return .empty
    }

    let instructions = """
        당신은 70대 어르신에게 낱말을 설명하는 선생님입니다.
        낱말을 넣은 문장(1번)과 그 자리에 뜻만 넣은 문장(2번)을 만듭니다.
        낱말·뜻의 조사나 어미는 문장에 자연스럽게 맞춰 바꿔도 됩니다.
        각 문장은 실생활에서 있을 법한 구체적인 예시로, 50자 이상 80자 이내로 씁니다.
        1번에는 낱말이 반드시 그대로 들어가야 하고, 2번에는 뜻만 들어가야 하며, 맞춤법과 문법에 맞게 씁니다.
        참고 예문이 주어지면 그 문장을 최대한 활용해 1번을 만듭니다.
        """

    var prompt = """
        낱말: \(word)
        뜻: \(gloss)
        위 낱말과 뜻으로 두 문장을 만드세요.
        """
    if let referenceSentence {
        prompt += "\n참고 예문: \(referenceSentence)"
    }
    if !relatedWords.isEmpty {
        prompt += "\n비슷한 낱말: \(relatedWords.joined(separator: ", "))"
    }

    // catch 블록에서도 session.logFeedbackAttachment(...)를 부를 수 있어야 해서
    // do 블록 밖으로 뺐다 — 이 초기화 자체는 던지지 않는다.
    let session = LanguageModelSession(instructions: instructions)

    do {
        let response = try await session.respond(to: prompt, generating: GlossaryExample.self)
        // 두 문장을 나란히 보여준다 — 낱말을 그대로 넣은 문장과 확정된 뜻을 넣은
        // 문장이 어디만 다른지 비교하며 읽을 수 있게, 번호를 붙여 한 문자열로 합친다.
        let combined = "1. \(response.content.wordSentence)\n\n2. \(response.content.glossSentence)"
        return Writing(text: combined, failure: nil)
    } catch {
        // 이유를 버리면 세이프티 필터에 왜 걸렸는지 알 수 없고, 무엇을 보냈는지
        // 없으면 다시 만들어 볼 수도 없다 — CommentaryWriter 와 같은 이유로 남긴다.
        print("❌ 사전 예문 실패 q\(questionID) \(word):", error)

        #if DEBUG
        // 세이프티 가드레일에 걸렸을 때만 애플에 신고할 첨부자료를 남긴다 — 그 외
        // 실패(문맥 초과·응답 형식 오류 등)는 애플의 세이프티 팀이 볼 대상이 아니다.
        if let generationError = error as? LanguageModelSession.GenerationError,
           case .guardrailViolation(let context) = generationError {
            // sentiment 는 "이 결과가 마음에 안 들었다"는 뜻으로 .negative — 원치 않게
            // 막힌 것이므로 정확히 이 값이 맞다. issues 는 상황에 꼭 맞는 분류
            // (LanguageModelFeedback.Issue.Category)를 애플 문서에서 못 찾아 비워
            // 둔다 — 잘못된 분류를 붙이는 것보다 안전하다. desiredResponseText 도
            // "이랬으면 좋았을 정답"이 따로 없어 nil. 그래도 애플 문서에 "실패로
            // 롤백된 항목은 첨부자료에 자동으로 포함된다"고 나와 있어, 막힌 프롬프트
            // 자체는 sentiment/issues 를 안 채워도 담겨 나온다.
            let attachment = session.logFeedbackAttachment(
                sentiment: .negative, issues: [], desiredResponseText: nil)
            saveFeedbackAttachment(
                attachment, questionID: questionID, word: word,
                debugDescription: context.debugDescription)
        }
        #endif

        return Writing(text: nil, failure: ModelFailureDraft(
            job: "glossary_example",
            questionID: questionID,
            reason: String(describing: error),
            instructions: instructions,
            prompt: prompt))
    }
}

#if DEBUG
/// Feedback Assistant 에 첨부할 파일로 남긴다. 애플 문서가 "JSON 으로 인코딩된
/// 자료이니 .json 파일로 저장해 첨부하라"고 명시해서 그 확장자를 그대로 썼다.
///
/// 문서 폴더에 저장해 두면 Xcode 의 기기 컨테이너 다운로드(Window → Devices and
/// Simulators → 기기 선택 → 이 앱 → Download Container)로 꺼낼 수 있다 — 꺼낸
/// 파일을 feedbackassistant.apple.com 신고에 첨부하면 된다.
///
/// - Note: DEBUG 빌드에서만 남긴다. 어차피 이 파일을 꺼내려면 Xcode 로 기기에
///   연결해야 하니, 실기기(RELEASE)에 쌓아 둘 이유가 없다.
private func saveFeedbackAttachment(
    _ data: Data, questionID: Int, word: String, debugDescription: String
) {
    guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

    let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
    let url = docs.appendingPathComponent("feedback_glossary_q\(questionID)_\(stamp).json")

    do {
        try data.write(to: url)
        print("📎 Feedback Assistant 첨부 저장:", url.path)
        print("   가드레일 상세:", debugDescription)
    } catch {
        print("❌ Feedback 첨부 저장 실패:", error)
    }
}
#endif
