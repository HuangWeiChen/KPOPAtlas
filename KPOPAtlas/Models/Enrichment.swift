import Foundation

struct ReferenceLink: Codable, Hashable, Identifiable {
    let title: String
    let url: String
    var id: String { url }
}
struct ListeningTrack: Codable, Hashable, Identifiable {
    let title: String
    let note: String
    var id: String { title }
    func searchURL(group: String) -> URL {
        var parts = URLComponents(string: "https://www.youtube.com/results")!
        parts.queryItems = [.init(name: "search_query", value: group + " " + title + " official MV")]
        return parts.url!
    }
}
struct GroupStory: Codable, Hashable {
    let groupID: String
    let debutDate: String
    let debutRelease: String
    let about: String
    let tracks: [ListeningTrack]
    let sources: [ReferenceLink]
}
struct MemberProfile: Codable, Hashable {
    let memberID: String
    let localName: String
    let birthday: String?
    let wikipediaTitle: String
    let sourceURL: String
}
nonisolated struct ArtistPhotoRecord: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let groupID: String
    let imageURL: String
    let sourceURL: String
    let author: String
    let license: String
    let licenseURL: String
    let caption: String
    let width: Int
    let height: Int
    var url: URL? { URL(string: imageURL) }
    var aspectRatio: Double { Double(max(width, 1)) / Double(max(height, 1)) }
}
struct Enrichment: Decodable {
    let stories: [GroupStory]
    let profiles: [MemberProfile]
    let photos: [ArtistPhotoRecord]
}
