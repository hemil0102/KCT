//
//  SupabaseConfig.example.swift  —  본보기입니다. 이 파일은 컴파일되지 않습니다.
//
//  쓰는 법
//    1. 이 파일을 KCT/Observation/SupabaseConfig.swift 로 복사한다
//    2. 아래 두 값을 자기 프로젝트 것으로 채운다
//       (Supabase 대시보드 → Project Settings → API)
//    3. 그 파일은 .gitignore 에 있어 저장소에 올라가지 않는다
//
//  ⚠️ 이 파일을 KCT/KCT/ 안으로 옮기지 마세요. 같은 이름의 타입이 둘이 되어
//     "Invalid redeclaration of 'SupabaseConfig'" 로 빌드가 깨집니다.
//

import Foundation

enum SupabaseConfig {

    /// 프로젝트 주소. 끝에 슬래시를 붙이지 않는다.
    static let projectURL = "https://YOUR-PROJECT-REF.supabase.co"

    /// anon(공개) 키. **service_role 키를 절대 넣지 않는다** — 그것은 모든 것을 할 수 있다.
    static let anonKey = "YOUR-ANON-KEY"
}
