//
//  ContenFile.swift
//  KCT
//
//  Created by harryho on 9/9/26.
//

import Foundation


/// 앱이 읽는 내용 파일 하나.
///
/// 문제집과 낱말 사전이 **같은 타입을 씁니다.** 둘 다 「받아 둔 것 먼저, 없으면 번들」이고
/// 담는 내용만 다르기 때문입니다.
///
/// - Note: 서버에서 **받아 오는 일**은 여기 없습니다. 받아서 ``saveDownloaded(_:)`` 로
///   적어 두는 것까지가 6단계의 몫이고, 이 타입은 **읽고 쓰기만** 합니다.


struct ContentFile<Payload: Codable> {
    
    /// 확장자를 뺀 파일 이름.
    let fileName: String
    
    // ❓ 파일매니저의 옵션 의미, 파일이 저장된 경로가 어디인지?
    private var downloadedURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("\(fileName).json")
    }
    
    enum LoadError: Error {
        case notFound(String)
    }
    
    /// 받아 둔 것 먼저, 없으면 번들. 둘 다 없으면 `nil`.
    ///
    /// **이 순서가 6단계(서버 갱신)의 전부입니다.** 받아서 저장하는 코드를 나중에
    /// 붙이면 이 함수는 손대지 않아도 새 내용이 쓰입니다.
    func load() -> Payload? {
        loadDownloaded() ?? (try? loadBundled())
    }

    /// 서버에서 받아 기기에 적어 둔 것. 없거나 깨졌으면 `nil`.
    ///
    /// 깨졌을 때 오류를 던지지 않는 이유 — 앱이 안 켜지는 것보다
    /// **번들 것으로 도는 편이 낫습니다.**
    func loadDownloaded() -> Payload? {
        guard let url = downloadedURL, let data = try? Data(contentsOf: url) else { return nil }
        
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
    
    /// 앱과 함께 나온 것. 이것마저 없으면 오류입니다.
    func loadBundled() throws -> Payload {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw LoadError.notFound(fileName)
        }
        
        return try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url))
    }
    
    /// 서버에서 받은 것을 적어 둔다.
    // ❓ 여기서 encode를 하는 이유가 뭐지? 그냥 받은 것이 json이면 다시 이렇게 할 이유가 있나? 
    func saveDownloaded(_ payload: Payload) throws {
        guard let url = downloadedURL else { return }
        try JSONEncoder().encode(payload).write(to: url, options: .atomic)
    }
}
