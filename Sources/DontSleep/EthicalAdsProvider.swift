import Foundation

/// EthicalAds REST provider.
///
/// POSTs to `https://server.ethicalads.io/api/v1/decision/` with the
/// publisher's id and a placement name, then maps the returned JSON
/// into an `AdCreative`.
///
/// This provider is DORMANT until the publisher account is approved
/// by EthicalAds. Until then, keep `publisherId` empty in Preferences
/// and use `HouseAdProvider` instead.
///
/// Expected response shape (subset we care about):
/// ```json
/// {
///   "id": "decision-nonce-123",
///   "headline": "Headline text",
///   "body": "Body text",
///   "cta": "Learn more",
///   "image": "https://.../icon.png",
///   "link": "https://server.ethicalads.io/proxy/click/... (tracked)",
///   "view_url": "https://server.ethicalads.io/proxy/view/... (tracked)"
/// }
/// ```
/// The endpoint may also return `{"nothing": "No ad to show"}` when
/// there is no inventory — we map that to `nil`.
final class EthicalAdsProvider: AdProvider {

    let name = "ethicalads"

    private let endpoint = URL(string: "https://server.ethicalads.io/api/v1/decision/")!
    private let publisherId: String
    private let placement: String
    private let keywords: [String]
    private let session: URLSession

    init(publisherId: String,
         placement: String = "dontsleep-banner",
         keywords: [String] = ["developer-tools", "macos", "productivity"]) {
        self.publisherId = publisherId
        self.placement = placement
        self.keywords = keywords

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 20
        cfg.waitsForConnectivity = false
        self.session = URLSession(configuration: cfg)
    }

    func nextCreative(completion: @escaping (AdCreative?) -> Void) {
        guard !publisherId.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // EthicalAds likes to see a UA that identifies the app.
        req.setValue("DontSleep/0.1 (+https://github.com/)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "publisher": publisherId,
            "placements": [
                ["div_id": placement, "ad_type": "image"]
            ],
            "keywords": keywords
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: req) { data, _, error in
            guard error == nil, let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // "nothing" field == house-empty response
            if obj["nothing"] != nil {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let creative = EthicalAdsProvider.map(decision: obj)
            DispatchQueue.main.async { completion(creative) }
        }.resume()
    }

    private static func map(decision obj: [String: Any]) -> AdCreative? {
        guard let id = obj["id"] as? String,
              let headline = (obj["headline"] as? String) ?? (obj["copy"] as? String),
              let linkStr = obj["link"] as? String,
              let link = URL(string: linkStr) else { return nil }
        return AdCreative(
            id: id,
            attribution: "Sponsored · EthicalAds",
            headline: headline,
            body: obj["body"] as? String ?? obj["cta"] as? String,
            imageURL: (obj["image"] as? String).flatMap(URL.init(string:)),
            fallbackSymbol: "megaphone.fill",
            clickURL: link,
            impressionURL: (obj["view_url"] as? String).flatMap(URL.init(string:)),
            sourceName: "ethicalads"
        )
    }
}
