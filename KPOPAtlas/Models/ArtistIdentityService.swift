import Foundation
import CryptoKit

extension Company {
    var wikipediaTitle: String {
        let names = ["bighit": "Big Hit Music", "pledis": "Pledis Entertainment", "belift": "Belift Lab",
            "source": "Source Music", "ador": "ADOR (company)", "koz": "KOZ Entertainment", "sm": "SM Entertainment",
            "jyp": "JYP Entertainment", "yg": "YG Entertainment", "starship": "Starship Entertainment",
            "cube": "Cube Entertainment", "kq": "KQ Entertainment", "rbw": "RBW (company)", "fnc": "FNC Entertainment",
            "woollim": "Woollim Entertainment", "dsp": "DSP Media", "ist": "IST Entertainment", "wakeone": "WakeOne",
            "highup": "High Up Entertainment", "dreamcatcher": "Dreamcatcher Company", "wm": "WM Entertainment",
            "fantagio": "Fantagio", "modhaus": "Modhaus", "blockberry": "Blockberry Creative", "ts": "TS Entertainment",
            "mbk": "MBK Entertainment", "s2": "S2 Entertainment", "bpm": "BPM Entertainment", "mystic": "Mystic Story",
            "yuehua": "Yuehua Entertainment", "mld": "MLD Entertainment", "attrakt": "Attrakt", "top": "TOP Media",
            "jellyfish": "Jellyfish Entertainment", "stone": "Stone Music Entertainment", "ymc": "YMC Entertainment",
            "pnation": "P Nation", "banana": "Banana Culture", "brave": "Brave Entertainment"]
        return names[id] ?? name
    }
}

// Resolve identity from group membership before requesting a person's photograph.
// Stage names are never sent to a broad image search that could return a namesake.
actor ArtistIdentityService {
    static let shared = ArtistIdentityService()
    private struct Identity: Codable, Sendable {
        let aliases: [String]
        let wikipediaTitle: String?
        let imageFile: String?
    }
    private struct TextValue: Decodable, Sendable { let value: String }
    private struct WikiValue: Decodable, Sendable {
        let text: String?
        let entityID: String?
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) { self.text = text; entityID = nil }
            else {
                struct EntityID: Decodable { let id: String? }
                entityID = (try? container.decode(EntityID.self))?.id
                text = nil
            }
        }
    }
    private struct Claim: Decodable, Sendable {
        struct Snak: Decodable, Sendable {
            struct Value: Decodable, Sendable { let value: WikiValue }
            let datavalue: Value?
        }
        let mainsnak: Snak
    }
    private struct Entity: Decodable, Sendable {
        struct Site: Decodable, Sendable { let title: String }
        let labels: [String: TextValue]?
        let aliases: [String: [TextValue]]?
        let claims: [String: [Claim]]?
        let sitelinks: [String: Site]?
        func values(_ property: String) -> [WikiValue] { (claims?[property] ?? []).compactMap { $0.mainsnak.datavalue?.value } }
    }
    private var rosters: [String: [Identity]] = [:]
    private var rosterRequests: [String: Task<[Identity], Never>] = [:]
    private var entityRequests: [String: Task<Entity?, Never>] = [:]
    private var entities: [String: Entity] = [:]
    private var logos: [String: ArtistPhotoRecord] = [:]
    private var logoRequests: [String: Task<ArtistPhotoRecord?, Never>] = [:]

    func portrait(member: Member, group: IdolGroup, hint: String?) async -> ArtistPhotoRecord? {
        if let hint, let photo = await PhotoService.shared.cover(title: hint, groupID: group.id) { return photo }
        let identities = await roster(group: group)
        let name = Self.normalized(member.name)
        let matches = identities.filter { $0.aliases.contains { Self.normalized($0) == name } }
        // A single identity may appear in both Wikidata and the article's infobox.
        for match in matches {
            if let file = match.imageFile,
               let photo = await PhotoService.shared.filePhoto(filename: file, groupID: group.id) { return photo }
            if let title = match.wikipediaTitle,
               let photo = await PhotoService.shared.cover(title: title, groupID: group.id) { return photo }
        }
        return nil
    }
    func groupPhoto(_ group: IdolGroup) async -> ArtistPhotoRecord? {
        if let photo = await PhotoService.shared.cover(title: group.wikipediaTitle, groupID: group.id) { return photo }
        if let entity = await entity(title: group.wikipediaTitle), let file = entity.values("P18").compactMap(\.text).first {
            return await PhotoService.shared.filePhoto(filename: file, groupID: group.id)
        }
        return nil
    }
    func logo(company: Company) async -> ArtistPhotoRecord? {
        if let photo = logos[company.id] { return photo }
        if let data = readCache("logo:" + company.id), let photo = try? JSONDecoder().decode(ArtistPhotoRecord.self, from: data) {
            logos[company.id] = photo; return photo
        }
        if let request = logoRequests[company.id] { return await request.value }
        let request = Task { () -> ArtistPhotoRecord? in
            guard let entity = await self.entity(title: company.wikipediaTitle),
                  let file = entity.values("P154").compactMap(\.text).first else { return nil }
            return await PhotoService.shared.filePhoto(filename: file, groupID: company.id, branding: true)
        }
        logoRequests[company.id] = request
        let result = await request.value
        logoRequests[company.id] = nil
        if let result {
            logos[company.id] = result
            if let data = try? JSONEncoder().encode(result) { writeCache(data, key: "logo:" + company.id) }
        }
        return result
    }

    private func roster(group: IdolGroup) async -> [Identity] {
        let key = group.wikipediaTitle
        if let roster = rosters[key] { return roster }
        if let data = readCache("roster:" + key), let roster = try? JSONDecoder().decode([Identity].self, from: data), !roster.isEmpty {
            rosters[key] = roster; return roster
        }
        if let request = rosterRequests[key] { return await request.value }
        let request = Task { () -> [Identity] in
            var roster: [Identity] = []
            if let entity = await self.entity(title: key) {
                let ids = entity.values("P527").compactMap(\.entityID)
                for start in stride(from: 0, to: ids.count, by: 40) {
                    let people = await Self.fetchEntities(Array(ids[start..<min(start + 40, ids.count)]))
                    for person in people.values where person.values("P31").contains(where: { $0.entityID == "Q5" }) {
                        let languages = ["en", "ko", "zh", "zh-hant", "ja"]
                        let names = languages.compactMap { person.labels?[$0]?.value }
                            + languages.flatMap { person.aliases?[$0]?.map(\.value) ?? [] }
                        roster.append(Identity(aliases: names, wikipediaTitle: person.sitelinks?["enwiki"]?.title,
                            imageFile: person.values("P18").compactMap(\.text).first))
                    }
                }
            }
            roster += await Self.infoboxMembers(title: key)
            return roster
        }
        rosterRequests[key] = request
        let result = await request.value
        rosterRequests[key] = nil
        if !result.isEmpty {
            rosters[key] = result
            if let data = try? JSONEncoder().encode(result) { writeCache(data, key: "roster:" + key) }
        }
        return result
    }
    private func entity(title: String) async -> Entity? {
        if let entity = entities[title] { return entity }
        if let request = entityRequests[title] { return await request.value }
        let request = Task { () -> Entity? in
            let url = Self.url(host: "en.wikipedia.org", items: ["action": "query", "titles": title, "redirects": "1", "prop": "pageprops", "ppprop": "wikibase_item"])
            struct Response: Decodable {
                struct Query: Decodable {
                    struct Page: Decodable {
                        struct Properties: Decodable { let wikibase_item: String? }
                        let pageprops: Properties?
                    }
                    let pages: [String: Page]
                }
                let query: Query?
            }
            guard let data = await Self.fetch(url), let response = try? JSONDecoder().decode(Response.self, from: data),
                  let id = response.query?.pages.values.compactMap({ $0.pageprops?.wikibase_item }).first else { return nil }
            return await Self.fetchEntities([id])[id]
        }
        entityRequests[title] = request
        let result = await request.value
        entityRequests[title] = nil
        if let result { entities[title] = result }
        return result
    }
    private static func fetchEntities(_ ids: [String]) async -> [String: Entity] {
        guard !ids.isEmpty else { return [:] }
        let url = url(host: "www.wikidata.org", items: ["action": "wbgetentities", "ids": ids.joined(separator: "|"),
            "props": "labels|aliases|claims|sitelinks", "languages": "en|ko|zh|zh-hant|ja"])
        struct Response: Decodable { let entities: [String: Entity] }
        guard let data = await fetch(url), let response = try? JSONDecoder().decode(Response.self, from: data) else { return [:] }
        return response.entities
    }
    private static func infoboxMembers(title: String) async -> [Identity] {
        let url = url(host: "en.wikipedia.org", items: ["action": "parse", "page": title, "prop": "wikitext", "section": "0", "redirects": "1"])
        struct Response: Decodable {
            struct Parse: Decodable {
                struct Wikitext: Decodable {
                    let text: String
                    enum CodingKeys: String, CodingKey { case text = "*" }
                }
                let wikitext: Wikitext
            }
            let parse: Parse?
        }
        guard let data = await fetch(url), let response = try? JSONDecoder().decode(Response.self, from: data), let text = response.parse?.wikitext.text else { return [] }
        return IdentityParser.memberLinks(in: text).map { Identity(aliases: [$0.title, $0.label], wikipediaTitle: $0.title, imageFile: nil) }
    }
    private static func normalized(_ text: String) -> String { IdentityParser.normalized(text) }
    private static func url(host: String, items: [String: String]) -> URL {
        var parts = URLComponents(string: "https://" + host + "/w/api.php")!
        parts.queryItems = (["format": "json"].merging(items) { _, new in new }).map { .init(name: $0.key, value: $0.value) }
        return parts.url!
    }
    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url); request.timeoutInterval = 15
        request.setValue("KPOPAtlas/1.1 (artist identity and image attribution)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200 ? data : nil
        } catch { return nil }
    }
    private func cacheURL(_ key: String) -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = base.appendingPathComponent("AtlasIdentities", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(digest + ".json")
    }
    private func readCache(_ key: String) -> Data? {
        guard let url = cacheURL(key) else { return nil }
        return try? Data(contentsOf: url)
    }
    private func writeCache(_ data: Data, key: String) {
        if let url = cacheURL(key) { try? data.write(to: url, options: .atomic) }
    }
}
