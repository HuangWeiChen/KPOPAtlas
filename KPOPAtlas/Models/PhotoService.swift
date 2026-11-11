import Foundation
import CryptoKit

// Wikimedia metadata keeps the actual author and license with each photograph.
actor PhotoService {
    static let shared = PhotoService()
    private var memory: [String: [ArtistPhotoRecord]] = [:]
    private var requests: [String: Task<[ArtistPhotoRecord], Never>] = [:]

    func cover(title: String, groupID: String) async -> ArtistPhotoRecord? {
        let key = "cover:" + title
        if let cached = read(key), let first = cached.first { return first }
        if let request = requests[key] { return await request.value.first }
        let request = Task { () -> [ArtistPhotoRecord] in
            var parts = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
            parts.queryItems = [.init(name: "action", value: "query"), .init(name: "format", value: "json"),
                .init(name: "titles", value: title), .init(name: "redirects", value: "1"),
                .init(name: "prop", value: "pageimages"), .init(name: "piprop", value: "name")]
            struct Response: Decodable {
                struct Query: Decodable {
                    struct Page: Decodable { let pageimage: String? }
                    let pages: [String: Page]
                }
                let query: Query?
            }
            guard let data = await Self.fetch(parts.url!),
                  let response = try? JSONDecoder().decode(Response.self, from: data),
                  let filename = response.query?.pages.values.compactMap(\.pageimage).first else { return [] }
            return await Self.commonsPhotos(title: "File:" + filename, groupID: groupID, category: false)
        }
        requests[key] = request
        let result = await request.value
        requests[key] = nil
        if !result.isEmpty { write(result, key: key) }
        return result.first
    }

    func gallery(group: IdolGroup, seeds: [ArtistPhotoRecord], refresh: Bool = false) async -> [ArtistPhotoRecord] {
        // Exact, curated category names prevent ambiguous names from matching another artist.
        let categories = ["BTS": "BTS", "TWICE": "Twice", "BLACKPINK": "Blackpink", "aespa": "Aespa",
            "SEVENTEEN": "Seventeen (musical group)", "Stray Kids": "Stray Kids", "ITZY": "Itzy",
            "TOMORROW X TOGETHER": "Tomorrow X Together", "Red Velvet": "Red Velvet (musical group)", "SHINee": "Shinee"]
        if refresh { invalidate("cover:" + group.wikipediaTitle) }
        var result = seeds
        if let cover = await cover(title: group.wikipediaTitle, groupID: group.id), !result.contains(where: { $0.id == cover.id }) { result.append(cover) }
        if let category = categories[group.name] {
            let key = "category:" + category
            if refresh { invalidate(key) }
            var extra = read(key)
            if extra == nil {
                extra = await Self.commonsPhotos(title: "Category:" + category, groupID: group.id, category: true)
                if let extra, !extra.isEmpty { write(extra, key: key) }
            }
            for photo in extra ?? [] where !result.contains(where: { $0.id == photo.id }) { result.append(photo) }
        }
        return Array(result.prefix(10))
    }

    func filePhoto(filename: String, groupID: String, branding: Bool = false) async -> ArtistPhotoRecord? {
        let key = "file:" + filename
        if let record = read(key)?.first { return record }
        let records = await Self.commonsPhotos(title: "File:" + filename, groupID: groupID, category: false, branding: branding)
        if !records.isEmpty { write(records, key: key) }
        return records.first
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("KPOPAtlas/1.1 (educational artist directory)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return data
        } catch { return nil }
    }
    private static func commonsPhotos(title: String, groupID: String, category: Bool, branding: Bool = false) async -> [ArtistPhotoRecord] {
        var parts = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        var items: [URLQueryItem] = [.init(name: "action", value: "query"), .init(name: "format", value: "json"),
            .init(name: "prop", value: "imageinfo"), .init(name: "iiprop", value: "url|extmetadata|size"),
            .init(name: "iiurlwidth", value: branding ? "256" : "960")]
        if category {
            items += [.init(name: "generator", value: "categorymembers"), .init(name: "gcmtitle", value: title),
                .init(name: "gcmtype", value: "file"), .init(name: "gcmlimit", value: "20")]
        } else { items.append(.init(name: "titles", value: title)) }
        parts.queryItems = items
        struct Response: Decodable {
            struct Query: Decodable {
                struct Page: Decodable {
                    struct Info: Decodable {
                        struct Metadata: Decodable { let value: String }
                        let url: String
                        let thumburl: String?
                        let descriptionurl: String
                        let width: Int
                        let height: Int
                        let extmetadata: [String: Metadata]?
                    }
                    let title: String
                    let imageinfo: [Info]?
                }
                let pages: [String: Page]
            }
            let query: Query?
        }
        guard let data = await fetch(parts.url!), let response = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return (response.query?.pages.values.sorted { $0.title < $1.title } ?? []).compactMap { page in
            let lower = page.title.lowercased()
            let supported = [".jpg", ".jpeg", ".png"].contains(where: lower.hasSuffix) || (branding && lower.hasSuffix(".svg"))
            guard supported,
                  branding || !["logo", "signature", "map.", "cropped", "album", "cover art"].contains(where: lower.contains),
                  let info = page.imageinfo?.first else { return nil }
            let metadata = info.extmetadata ?? [:]
            let license = plain(metadata["LicenseShortName"]?.value ?? "")
            let author = plain(metadata["Artist"]?.value ?? "")
            let licenseURL = metadata["LicenseUrl"]?.value ?? (license.contains("Public domain") ? "https://creativecommons.org/publicdomain/mark/1.0/" : "")
            let permitted = (license.hasPrefix("CC BY") && !license.contains("-NC") && !license.contains("-ND")) || license == "CC0" || license.contains("Public domain")
            guard !author.isEmpty, !licenseURL.isEmpty, permitted else { return nil }
            return ArtistPhotoRecord(id: page.title.replacingOccurrences(of: "File:", with: ""), groupID: groupID,
                imageURL: info.thumburl ?? info.url, sourceURL: info.descriptionurl, author: author,
                license: license, licenseURL: licenseURL,
                caption: plain(page.title.replacingOccurrences(of: "File:", with: "")), width: info.width, height: info.height)
        }
    }
    private static func plain(_ value: String) -> String {
        String(value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&nbsp;", with: " ").prefix(600))
    }
    private func cacheURL(_ key: String) -> URL? {
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = directory.appendingPathComponent("AtlasPhotoMetadata", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(digest + ".json")
    }
    private func read(_ key: String) -> [ArtistPhotoRecord]? {
        if let cached = memory[key] { return cached }
        guard let url = cacheURL(key), let data = try? Data(contentsOf: url), let records = try? JSONDecoder().decode([ArtistPhotoRecord].self, from: data) else { return nil }
        memory[key] = records
        return records
    }
    private func invalidate(_ key: String) {
        memory[key] = nil
        if let url = cacheURL(key) { try? FileManager.default.removeItem(at: url) }
    }
    private func write(_ photos: [ArtistPhotoRecord], key: String) {
        memory[key] = photos
        if let url = cacheURL(key), let data = try? JSONEncoder().encode(photos) { try? data.write(to: url, options: .atomic) }
    }
}
