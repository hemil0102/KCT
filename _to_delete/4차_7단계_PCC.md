# 4차 7단계 — 해설을 Private Cloud Compute 로

> 해설을 만드는 모델만 기기 밖의 큰 모델로 옮긴다. **모든 이용자에게 똑같이.**
> 구름을 쓸 수 없으면(비행기 모드·하루 한도 초과·iOS 26) **기기 모델로 내려간다.**
>
> **채점(`MeaningGrader`)은 온디바이스 그대로 둔다** — 답을 낸 직후 판정돼야 하고,
> 지하철에서도 돌아야 한다.

## 고칠 곳 한눈에

| | 무엇 | 어디 |
|---|---|---|
| ① | entitlement 신청 | developer.apple.com (코드 아님) |
| ② | Xcode 에 Capability 추가 | 승인된 뒤 |
| ③ | Supabase 에 `explanation_source` 칸 | SQL |
| ④ | 구름 먼저, 안 되면 기기 | `KCT/Grading/CommentaryWriter.swift` |
| ⑤ | 어느 쪽이 썼는지 로그에 남기기 | `ObsRecord` · `ObsUploader` · `QuizSession` |
| ⑥ | 지침 들여쓰기 정리 | `CommentaryWriter` |

**③을 앱보다 먼저 한다.** 8/31 처럼 컬럼이 없으면 회차 다섯 줄이 통째로 거부된다.
**④⑤는 ①이 승인된 뒤에** 넣는다. 지금 넣으면 서명이 안 된다.

---

## 왜 해설만인가

| | 채점 (`MeaningGrader`) | 해설 (`CommentaryWriter`) |
|---|---|---|
| 언제 | 답을 낸 **직후**. 늦으면 화면이 멈춘 것처럼 보인다 | 창이 **이미 떠 있는** 동안. 1~2초 더 걸려도 어머니는 정답을 읽고 있다 |
| 없으면 | 회차가 못 넘어간다 | 정답만 보여주면 된다 |
| 어려움 | 「같은 것을 가리키는가」 — 작은 모델도 한다 | 9/5 사고가 **전부 여기서 났다** |
| 네트워크 | 없어도 돌아야 한다 | 없으면 기기 모델로 물러나면 된다 |

## `explanation_source` 를 왜 남기나

유료·무료를 가르려는 것이 **아니다.** **구름이 얼마나 자주 기기로 물러나는지**를 보기 위해서다.

`quotaUsage` 는 **이용자 한 사람의 하루 한도**다. 어머니가 여러 회차를 연달아 돌면 걸릴 수 있고, 걸리면 코드는 조용히 기기 모델로 내려간다. **그때 우리가 알 방법이 이 칸뿐이다.** 해설이 갑자기 나빠졌는데 이유를 모르는 일이 없게 한다.

덤으로 같은 문항의 두 해설을 나란히 볼 수 있어, **큰 모델이 정말 나은지**가 짐작이 아니라 숫자가 된다.

## 알고 있어야 할 위험 — 200만 다운로드

PCC 무료 이용은 **앱 최초 다운로드 200만 회 미만**일 때만이다(해설 호출 횟수가 아니다). 넘으면 **유료로 전환되는 것이 아니라 접근이 끊긴다.** 애플은 유료 티어를 두지 않았다.

지금은 한참 먼 이야기지만, 대비는 구조로 해 둔다 — **모델을 고르는 곳이 `cloudSession(instructions:)` 한 군데**라, 그때는 그 함수 안만 다른 서버 모델로 바꾸면 된다. `explanation_source` 에 값이 하나 느는 정도다.

---

## ① entitlement 신청

App Store Small Business Program 가입이 먼저다 (App Store Connect → 계약·세금·금융거래).

```
developer.apple.com/account/resources
  → Identifiers → com.harry.KCT
  → Capability Requests 탭 → Private Cloud Compute 의 [Request]
```

Account Holder 만 신청할 수 있고, 같은 탭의 `Status` 로 진행을 본다.

## ② 승인된 뒤 Xcode

```
KCT 타깃 → Signing & Capabilities → + Capability → Private Cloud Compute
```

**배포 타깃은 26.2 그대로 둔다.** 아래 코드가 `#available` 로 갈라 주므로 iOS 26 폰에서는 기기 모델로 돈다.

## ③ Supabase — 앱보다 먼저

```sql
begin;

alter table public.obs_record add column explanation_source text;

drop policy "app can insert only" on public.obs_record;

create policy "app can insert only" on public.obs_record
for insert to anon
with check (
    question_id >= 1 and question_id <= 100000
    and mode_raw >= 0 and mode_raw <= 3
    and sec_to_submit >= 0 and sec_to_submit < 3600
    and (sec_to_first_touch is null
         or (sec_to_first_touch >= 0 and sec_to_first_touch <= sec_to_submit))
    and asked_at > now() - interval '30 days'
    and asked_at < now() + interval '1 day'
    and length(device_id) >= 8 and length(device_id) <= 64
    and (chosen is null or length(chosen) <= 100)
    and (reason is null or length(reason) <= 300)
    and (explanation is null or length(explanation) <= 500)
    and (explanation_source is null or explanation_source in ('cloud', 'device'))
);

commit;
```

기존 조건을 그대로 옮기고 마지막 한 줄만 더한 것이다. **`in ('cloud','device')` 로 값을 묶어** 오타가 들어오면 서버가 막는다.

## ④ `KCT/Grading/CommentaryWriter.swift`

**ⓐ 해설이 어디서 왔는지 함께 돌려준다** — 파일 위쪽, `Commentary` 아래에

```swift
/// 해설과 그것을 만든 곳.
struct WrittenCommentary {
    let text: String
    /// `"cloud"` 또는 `"device"`. 로그에 그대로 들어간다.
    let source: String
}
```

**ⓑ `write(for:)` 의 선언과 끝부분을 교체**

```swift
    func write(for item: QuizItem) async -> WrittenCommentary? {
```

`let prompt = ...` 다음의 `do { ... } catch { ... }` 를 통째로 지우고

```swift
        if let cloud = cloudSession(instructions: instructions),
           let text = await ask(cloud, prompt: prompt, from: "cloud") {
            return WrittenCommentary(text: text, source: "cloud")
        }

        guard let text = await ask(
            LanguageModelSession(instructions: instructions),
            prompt: prompt,
            from: "device")
        else { return nil }

        return WrittenCommentary(text: text, source: "device")
```

**구름이 안 되면 기기로 내려온다.** 비행기 모드, 하루 한도 초과, iOS 26 — 어느 경우에도 해설이 아예 없어지면 안 된다.

**ⓒ 구름 세션을 만드는 함수** — `write(for:)` 아래에 새로

```swift
    /// 구름 모델 세션. 쓸 수 없으면 `nil` 이고 부르는 쪽이 기기 모델로 간다.
    ///
    /// `isAvailable` 과 `quotaUsage` 를 미리 보는 이유 — 오류를 받고 물러나면
    /// 그만큼 어머니가 기다립니다. 물러날 것은 부르기 전에 알 수 있습니다.
    private func cloudSession(instructions: String) -> LanguageModelSession? {
        guard #available(iOS 27, *) else { return nil }

        let cloud = PrivateCloudComputeLanguageModel()
        guard cloud.isAvailable, !cloud.quotaUsage.isLimitReached else { return nil }

        return LanguageModelSession(model: cloud, instructions: instructions)
    }
```

**ⓓ 물어보고 받아 오는 함수** — 그 아래에 새로

```swift
    /// 세션 하나에 물어보고 문장을 받아 온다. 실패하면 이유를 찍고 `nil`.
    ///
    /// `from` 을 받는 이유 — 콘솔에서 **구름이 실패한 것인지 기기가 실패한 것인지**
    /// 갈라야 합니다. 오류를 통째로 버려서 「잠시만 같이 살펴봐요.」가 남는 이유를
    /// 못 찾았던 것이 2026-09-05 입니다.
    private func ask(
        _ session: LanguageModelSession,
        prompt: String,
        from place: String
    ) async -> String? {
        do {
            let response = try await session.respond(to: prompt, generating: Commentary.self)
            let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            print("❌ 해설 실패(\(place)):", error)
            return nil
        }
    }
```

> **이름이 바뀌었을 수 있다.** `PrivateCloudComputeLanguageModel`·`isAvailable`·`quotaUsage` 는 발표 시점의 이름이다. Xcode 자동완성으로 확인하고 넣는다.

## ⑤ 어느 쪽이 썼는지 로그에 남기기

`explanation` 과 **똑같은 모양**으로 한 칸을 더 만든다. 이미 해 본 일이라 자리만 찾으면 된다.

**ⓐ `KCT/Observation/ObsRecord.swift`** — `explanation` 이 있는 세 곳 바로 아래에 각각

```swift
    var explanationSource: String?
```
```swift
        explanationSource: String?
```
```swift
        self.explanationSource = explanationSource
```

**ⓑ `KCT/Observation/ObsUploader.swift`** — `Payload` 의 네 곳

```swift
        let explanationSource: String?
```
```swift
            case wasFirstEver, affectsProgress, chosen, reason, explanation, explanationSource
```
```swift
            try container.encode(explanationSource, forKey: .explanationSource)
```
```swift
                explanationSource: record.explanationSource,
```

**`encodeIfPresent` 가 아니라 `encode`.** 맞힌 문항은 `nil` 이라 키가 사라지고, 그러면 회차 다섯 줄이 통째로 거부된다 (8/31).

**ⓒ `KCT/Screens/QuizSession.swift`**

`saveObsRecord` 의 선언

```swift
    private func saveObsRecord(
        for item: QuizItem,
        isCorrect: Bool,
        explanation: String?,
        explanationSource: String?
    ) {
```

`ObsRecord(` 안, `explanation: explanation` 아래 (윗줄 끝에 쉼표)

```swift
                explanationSource: explanationSource
```

그리고 `gradeCurrent` 의 `else` 안을 이렇게

```swift
            let written = await commentaryWriter.write(for: item)

            if let written, feedback != nil {
                feedback = IncorrectCommentary(
                    selectedAnswer: answer,
                    correctAnswer: item.question.answer,
                    commentary: written.text)
            }

            saveObsRecord(
                for: item,
                isCorrect: isCorrect,
                explanation: written?.text,
                explanationSource: written?.source)
```

맞힌 쪽의 부름도 인자가 하나 늘어난다.

```swift
            saveObsRecord(for: item, isCorrect: isCorrect, explanation: nil, explanationSource: nil)
```

## ⑥ `instructions` 들여쓰기

본문이 19~20칸인데 닫는 `"""` 이 8칸이다. Swift 는 **닫는 따옴표만큼만** 지우므로 모든 줄 앞에 공백 11칸이 붙어 나간다. 본문을 닫는 `"""` 에 맞춘다.

---

## 다 넣고 확인할 것

1. **일부러 틀린다** → 해설이 나오고 콘솔에 `❌` 가 없다. 로그의 `explanation_source` 가 `cloud`
2. **비행기 모드로 틀린다** → 해설이 여전히 나오고 `device` 로 남는가. 콘솔에 `❌ 해설 실패(cloud)` 가 찍히면 맞다
3. **얼마나 걸리는가** — 창이 뜨고 글자가 바뀔 때까지. 3초를 넘으면 어머니에게는 길다
4. **하루 한도** — `cloud.quotaUsage` 를 한 번 `print` 해서 실제 숫자를 본다. 회차를 열 번 돌면 얼마나 차는가

## 그리고 이것을 본다 — 이번 단계의 진짜 목적

```sql
select question_id, explanation_source, explanation
from obs_record
where explanation is not null
order by id desc limit 30;
```

- **`person`(안익태·주몽)에서 글자 풀이가 사라지는가** — 9/5 까지 기기 모델의 가장 큰 결함이다
- **`device` 로 물러난 줄이 몇 개인가** — 많으면 하루 한도에 걸리고 있는 것이다
- **`cloud` 와 `device` 의 차이가 눈에 띄는가**

차이가 크면 그다음에 **유형별 지침 열한 갈래를 줄일 수 있는지** 본다. 그건 작은 모델을 붙들려고 만든 것이다.
