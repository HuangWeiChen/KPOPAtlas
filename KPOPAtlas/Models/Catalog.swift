import SwiftUI

struct Company: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let family: String
    let summary: String
    let website: String
    var url: URL { URL(string: website)! }
}

struct IdolGroup: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let koreanName: String
    let companyID: String
    let debutYear: Int
    let kind: String
    let fandom: String
    let wikipediaTitle: String
    let memberNames: [String]
    let summary: String
    let palette: Int
    var members: [Member] {
        memberNames.map { Member(id: id + ":" + $0, name: $0, groupID: id) }
    }
    var referenceURL: URL {
        URL(string: "https://en.wikipedia.org/wiki/" + wikipediaTitle.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)!
    }
    var videoURL: URL {
        var parts = URLComponents(string: "https://www.youtube.com/results")!
        parts.queryItems = [.init(name: "search_query", value: name + " official music video")]
        return parts.url!
    }
    var colors: [Color] {
        switch palette {
        case 0: [Color(red: 0.34, green: 0.19, blue: 0.63), Color(red: 0.75, green: 0.49, blue: 0.93)]
        case 1: [Color(red: 0.07, green: 0.35, blue: 0.40), Color(red: 0.35, green: 0.72, blue: 0.68)]
        case 2: [Color(red: 0.57, green: 0.17, blue: 0.29), Color(red: 0.95, green: 0.58, blue: 0.57)]
        case 3: [Color(red: 0.18, green: 0.26, blue: 0.55), Color(red: 0.48, green: 0.66, blue: 0.95)]
        case 4: [Color(red: 0.54, green: 0.33, blue: 0.12), Color(red: 0.91, green: 0.72, blue: 0.39)]
        default: [Color(red: 0.30, green: 0.24, blue: 0.37), Color(red: 0.74, green: 0.57, blue: 0.70)]
        }
    }
}

struct Member: Identifiable, Hashable {
    let id: String
    let name: String
    let groupID: String
    func searchURL(group: String) -> URL {
        var parts = URLComponents(string: "https://en.wikipedia.org/w/index.php")!
        parts.queryItems = [.init(name: "search", value: group + " " + name)]
        return parts.url!
    }
}

struct MediaManifest: Decodable {
    let groups: [String: ArtistPhotoRecord]
    let members: [String: ArtistPhotoRecord]
    let companies: [String: ArtistPhotoRecord]
    static let empty = MediaManifest(groups: [:], members: [:], companies: [:])
}

@Observable final class Catalog {
    let media: MediaManifest
    let companies: [Company]
    let groups: [IdolGroup]
    let loadError: String?
    let stories: [GroupStory]
    let profiles: [MemberProfile]
    let photos: [ArtistPhotoRecord]
    var imageReloadToken = 0
    var favorites: Set<String> {
        didSet { UserDefaults.standard.set(Array(favorites), forKey: "atlas.favorites") }
    }
    init() {
        if let url = Bundle.main.url(forResource: "media-manifest", withExtension: "json"),
           let data = try? Data(contentsOf: url), let manifest = try? JSONDecoder().decode(MediaManifest.self, from: data) {
            media = manifest
        } else { media = .empty }
        struct File: Decodable { let companies: [Company]; let groups: [IdolGroup] }
        do {
            guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
            guard let enrichmentURL = Bundle.main.url(forResource: "enrichment", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let enrichment = try JSONDecoder().decode(Enrichment.self, from: Data(contentsOf: enrichmentURL))
            companies = file.companies; groups = file.groups
            stories = enrichment.stories; profiles = enrichment.profiles; photos = enrichment.photos
            loadError = nil
        } catch {
            companies = []; groups = []; stories = []; profiles = []; photos = []
            loadError = "無法讀取圖鑑資料，請重新安裝 App。"
        }
        favorites = Set(UserDefaults.standard.stringArray(forKey: "atlas.favorites") ?? [])
    }
    func company(for group: IdolGroup) -> Company? { companies.first { $0.id == group.companyID } }
    func groups(for company: Company) -> [IdolGroup] { groups.filter { $0.companyID == company.id } }
    func toggle(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
    }
    func matches(_ group: IdolGroup, query: String) -> Bool {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return search.isEmpty || ([group.name, group.koreanName, group.fandom, company(for: group)?.name ?? ""] + group.memberNames)
            .contains { $0.localizedStandardContains(search) }
    }
    func story(for group: IdolGroup) -> GroupStory? { stories.first { $0.groupID == group.id } }
    func profile(for member: Member) -> MemberProfile? { profiles.first { $0.memberID == member.id } }
    func photos(for group: IdolGroup) -> [ArtistPhotoRecord] {
        let curated = photos.filter { $0.groupID == group.id }
        guard let cover = media.groups[group.id], !curated.contains(where: { $0.id == cover.id }) else { return curated }
        return curated + [cover]
    }
    var memberCount: Int { groups.reduce(0) { $0 + $1.memberNames.count } }
}

