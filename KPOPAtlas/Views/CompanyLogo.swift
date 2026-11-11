import SwiftUI

struct CompanyLogo: View {
    let company: Company
    var showCredit = false
    @Environment(Catalog.self) private var catalog
    @State private var resolvedLogo: ArtistPhotoRecord?
    private var logo: ArtistPhotoRecord? { resolvedLogo ?? catalog.media.companies[company.id] }
    private var monogram: String {
        let first = company.name.split(separator: " ").first.map(String.init) ?? company.name
        return first.count <= 4 ? first : String(first.prefix(2))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                if let logo {
                    RoundedRectangle(cornerRadius: 14).fill(.white)
                    RemoteArtwork(photo: logo, reloadToken: catalog.imageReloadToken).padding(8)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(Color.atlasAccent.opacity(0.1))
                    Text(monogram).font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color.atlasAccent).padding(6).minimumScaleFactor(0.7)
                }
            }.aspectRatio(1, contentMode: .fit)
                .accessibilityLabel(logo == nil ? "\(company.name) 公司字母圖示" : "\(company.name) Logo")
            if showCredit, let logo { PhotoCredit(photo: logo) }
        }
        .task(id: "\(company.id)-\(catalog.imageReloadToken)") {
            guard catalog.media.companies[company.id] == nil else { return }
            let result = await ArtistIdentityService.shared.logo(company: company)
            if !Task.isCancelled { resolvedLogo = result }
        }
    }
}
