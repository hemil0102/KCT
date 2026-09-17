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
    @Guide(description: "낱말 바로 뒤에 괄호로 뜻을 넣어 \"낱말(뜻)\" 형태로 쓰고, 낱말을 괄호 안에 넣지 않고, **로 단어를 감싸지 말고, 그 표현이 자연스럽게 들어간 구체적인 문장 하나. 50자 이상 100자 이내로 쓴다")
    let sentence: String
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
        당신은 한글을 잘 모르는 사람에게 낱말을 설명하는 유머러스한 행복을 주는 긍정적인 선생님입니다. 존댓말을 합니다.
        낱말 바로 뒤에 괄호로 뜻을 넣어 "낱말(뜻)"처럼 쓰고, 그 표현이 자연스럽게 들어간 한 문장을 만듭니다.
        문장은 실생활에서 있을 법한 구체적인 예시로, 50자 이상 90자 이내로 쓰며, 낱말과 뜻은 반드시 원문 그대로 사용합니다.
        조사나 어미는 문맥에 자연스럽게 맞춰 바꿔도 되며, 맞춤법과 문법에 맞게 씁니다.
        참고 예문이 주어지면 그 문장의 상황과 표현을 최대한 활용합니다.
        """

    var prompt = """
        낱말: \(word)
        뜻: \(gloss)
        위 낱말과 뜻으로 "낱말(뜻)" 형식이 들어간 문장 하나를 만드세요.
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
        // @Guide에 "**로 감싸지 말라"고 적어 뒀지만, 모델이 가끔 낱말을 마크다운
        // 볼드(**낱말**)로 감싸서 내보낸다 — 지시문은 확률을 낮출 뿐 100% 막지는
        // 못한다. 화면에는 별표가 그대로 문자로 찍히고(예: "**서기전**"), 낱말
        // 강조 구간을 찾는 로직(GlossaryPanel.highlightedExample)도 "(" 바로
        // 앞 공백 없는 덩어리를 낱말로 보기 때문에 별표까지 그 덩어리에 끼어
        // 들어가 버린다. 그래서 화면에 보내기 전에 코드에서 한 번 더 확실히
        // 걷어낸다.
        let sentence = response.content.sentence.replacingOccurrences(of: "**", with: "")
        return Writing(text: sentence, failure: nil)
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
