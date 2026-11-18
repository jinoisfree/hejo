import Foundation

/// Discovery metadata only selects a signed, full archive in the configured public repository.
struct UpdateRelease: Equatable {
    static var repository: String { Bundle.main.object(forInfoDictionaryKey: "HejoUpdateRepository") as? String ?? "" }
    static func validRepository(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$"#, options: .regularExpression) != nil
    }
    static func latestURL(repository: String) -> URL? {
        guard validRepository(repository) else { return nil }
        return URL(string: "https://api.github.com/repos/" + repository + "/releases/latest")
    }
    let repository: String
    let version: String
    let feedID: Int64
    let archiveID: Int64
    let archiveSize: UInt64
    var feedURL: URL { URL(string: "https://github.com/\(repository)/releases/latest/download/appcast.xml")! }
    var archiveURL: URL { URL(string: "https://github.com/\(repository)/releases/download/v\(version)/hejo-\(version)-arm64.zip")! }

    static func decode(_ data: Data, repository: String = Self.repository) throws -> Self {
        struct Asset: Decodable {
            let id: Int64, name: String, state: String, size: UInt64, browser_download_url: String
        }
        struct Release: Decodable { let tag_name: String, draft: Bool, prerelease: Bool, assets: [Asset] }
        guard validRepository(repository), data.count <= 1_048_576 else { throw UpdateFailure.invalidRelease }
        let value = try JSONDecoder().decode(Release.self, from: data)
        guard value.tag_name.hasPrefix("v"), !value.draft, !value.prerelease else { throw UpdateFailure.invalidRelease }
        let version = String(value.tag_name.dropFirst())
        guard version.range(of: #"^[0-9]+(\.[0-9]+){1,3}$"#, options: .regularExpression) != nil else { throw UpdateFailure.invalidRelease }
        let feeds = value.assets.filter { $0.name == "appcast.xml" }
        let archives = value.assets.filter { $0.name == "hejo-\(version)-arm64.zip" }
        guard feeds.count == 1, archives.count == 1, let feed = feeds.first, let archive = archives.first,
              feed.id > 0, archive.id > 0, feed.id != archive.id,
              feed.state == "uploaded", archive.state == "uploaded",
              feed.size > 0, feed.size <= 1_048_576, archive.size > 0, archive.size <= 1_073_741_824 else { throw UpdateFailure.invalidRelease }
        let result = Self(repository: repository, version: version, feedID: feed.id, archiveID: archive.id, archiveSize: archive.size)
        guard archive.browser_download_url == result.archiveURL.absoluteString,
              feed.browser_download_url == "https://github.com/\(repository)/releases/download/v\(version)/appcast.xml" else { throw UpdateFailure.invalidRelease }
        return result
    }
    func allows(file: URL?, version: String, size: UInt64, installation: String,
                notes: URL?, information: URL?, hasDeltas: Bool) -> Bool {
        file?.absoluteString == archiveURL.absoluteString && version == self.version && size == archiveSize &&
            installation == "application" && notes == nil && information == nil && !hasDeltas
    }
}

enum UpdateFailure: LocalizedError {
    case unavailable, invalidRelease, network, closing
    var errorDescription: String? {
        switch self {
        case .unavailable: return "아직 업데이트 릴리스가 없어요."
        case .invalidRelease: return "설치 가능한 hejo 배포 파일을 확인하지 못했어요. 현재 앱은 그대로 유지됩니다."
        case .network: return "업데이트 서버에 연결하지 못했어요. 잠시 후 다시 확인해 주세요."
        case .closing: return "앱이 종료 중이에요."
        }
    }
}

/// Metadata redirects are refused. Sparkle separately validates the signed feed and archive.
final class UpdateReleaseClient: NSObject, URLSessionTaskDelegate {
    private var session: URLSession!
    private let repository: String
    init(configuration: URLSessionConfiguration = .ephemeral, repository: String = UpdateRelease.repository) {
        self.repository = repository
        super.init()
        configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil; configuration.httpCookieStorage = nil
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    func close() { session.invalidateAndCancel() }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    @discardableResult func latest(completion: @escaping (Result<UpdateRelease, Error>) -> Void) -> URLSessionDataTask? {
        guard let url = UpdateRelease.latestURL(repository: repository) else { completion(.failure(UpdateFailure.invalidRelease)); return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("hejo-updater", forHTTPHeaderField: "User-Agent")
        let task = session.dataTask(with: request) { [repository] data, response, error in
            guard error == nil, let response = response as? HTTPURLResponse else { completion(.failure(UpdateFailure.network)); return }
            switch response.statusCode {
            case 200:
                guard let data, data.count <= 1_048_576 else { completion(.failure(UpdateFailure.invalidRelease)); return }
                completion(Result { try UpdateRelease.decode(data, repository: repository) })
            case 404: completion(.failure(UpdateFailure.unavailable))
            default: completion(.failure(UpdateFailure.network))
            }
        }
        task.resume(); return task
    }
}
