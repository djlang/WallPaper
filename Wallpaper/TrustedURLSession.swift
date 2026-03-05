import Foundation

final class TrustedSessionDelegate: NSObject, URLSessionDelegate {
    private let trustedHosts: Set<String> = [
        "wallpaper.apc.360.cn",
        "cdn.apc.360.cn",
        "p1.qhimg.com",
        "qhimg.com",
        "p0.qhimg.com",
        "p2.qhimg.com",
        "p3.qhimg.com"
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host.lowercased() as String? else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if trustedHosts.contains(host) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

enum TrustedURLSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: TrustedSessionDelegate(), delegateQueue: nil)
    }()
}
