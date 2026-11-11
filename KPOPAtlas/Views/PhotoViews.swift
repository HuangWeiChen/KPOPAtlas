import SwiftUI

// iOS 27's AsyncImage session API supports server-directed disk and memory caching.
private enum ImageNetworking {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 160 * 1024 * 1024, diskPath: "AtlasImages")
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()
}
struct RemoteArtwork: View {
    let photo: ArtistPhotoRecord
    var reloadToken = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if #available(iOS 27, *) {
            image.asyncImageURLSession(ImageNetworking.session)
        } else { image }
    }
    private var image: some View {
        AsyncImage(url: photo.url, transaction: Transaction(animation: reduceMotion ? nil : .easeOut(duration: 0.22))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit().transition(.opacity)
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark").font(.title2)
                    Text("照片暫時無法載入").font(.caption).multilineTextAlignment(.center)
                }.foregroundStyle(.secondary).padding(12)
            case .empty:
                ProgressView().accessibilityLabel("正在載入照片")
            @unknown default:
                Image(systemName: "photo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(reloadToken)
        .accessibilityLabel(photo.caption)
    }
}
struct ArtistPhoto: View {
    let group: IdolGroup
    var ratio: Double = 16.0 / 10.0
    @Environment(Catalog.self) private var catalog
    @State private var resolved: ArtistPhotoRecord?
    private var photo: ArtistPhotoRecord? { catalog.photos(for: group).first ?? resolved }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(group.colors[0].opacity(0.08))
            if let photo {
                // Fit preserves every person, including those at the edges of wide group photos.
                RemoteArtwork(photo: photo, reloadToken: catalog.imageReloadToken).padding(8)
            } else {
                Poster(group: group, showName: false).clipShape(.rect(cornerRadius: 16))
            }
        }
        .aspectRatio(ratio, contentMode: .fit)
        .task(id: "\(group.id)-\(catalog.imageReloadToken)") {
            resolved = nil
            if catalog.photos(for: group).isEmpty {
                let result = await ArtistIdentityService.shared.groupPhoto(group)
                if !Task.isCancelled { resolved = result }
            }
        }
    }
}
struct MemberPortrait: View {
    let member: Member
    let group: IdolGroup
    var showCredit = false
    @Environment(Catalog.self) private var catalog
    @State private var resolvedPhoto: ArtistPhotoRecord?
    private var photo: ArtistPhotoRecord? { resolvedPhoto ?? catalog.media.members[member.id] }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
          ZStack {
            RoundedRectangle(cornerRadius: 18).fill(group.colors[0].opacity(0.09))
            if let photo { RemoteArtwork(photo: photo, reloadToken: catalog.imageReloadToken).padding(8) }
            else {
                Text(initials(member.name)).font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(group.colors[0]).accessibilityHidden(true)
            }
        }
          .aspectRatio(4.0 / 5.0, contentMode: .fit)
          if showCredit, let photo { PhotoCredit(photo: photo) }
        }
        .task(id: "\(member.id)-\(catalog.imageReloadToken)") {
            guard catalog.media.members[member.id] == nil else { return }
            let result = await ArtistIdentityService.shared.portrait(member: member, group: group, hint: catalog.profile(for: member)?.wikipediaTitle)
            if !Task.isCancelled { resolvedPhoto = result }
        }

    }
}
struct PhotoCredit: View {
    let photo: ArtistPhotoRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(photo.caption).font(.subheadline.weight(.semibold))
            Text("攝影／來源：\(photo.author)").font(.caption).foregroundStyle(.secondary)
            HStack {
                if let url = URL(string: photo.sourceURL) { Link("原始圖片", destination: url) }
                if let url = URL(string: photo.licenseURL) { Link(photo.license, destination: url) }
            }.font(.caption)
            Text("完整比例顯示，僅縮放尺寸。").font(.caption2).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true)
    }
}
struct PhotoGalleryView: View {
    let group: IdolGroup
    @Environment(Catalog.self) private var catalog
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var photos: [ArtistPhotoRecord] = []
    @State private var loading = false
    @State private var retry = 0
    @State private var selection: ArtistPhotoRecord?
    @Namespace private var namespace
    private var visible: [ArtistPhotoRecord] { photos.isEmpty ? catalog.photos(for: group) : photos }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "照片與舞台紀錄", subtitle: "保留完整構圖，點選照片可全螢幕觀看。")
            if !visible.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 280 : 240), spacing: 18)], alignment: .leading, spacing: 22) {
                    ForEach(visible) { photo in
                        VStack(alignment: .leading, spacing: 12) {
                            Button { selection = photo } label: {
                                RemoteArtwork(photo: photo, reloadToken: retry).padding(10)
                                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                                    .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 18))
                                    .matchedTransitionSource(id: photo.id, in: namespace)
                            }.buttonStyle(.plain).accessibilityLabel("全螢幕觀看：\(photo.caption)")
                            PhotoCredit(photo: photo)
                        }
                    }
                }
            } else if loading {
                ProgressView("正在尋找圖片與授權資料…").padding(.vertical, 24).frame(maxWidth: .infinity)
            } else {
                Label("目前沒有可顯示的照片，請確認網路後重試。", systemImage: "wifi.exclamationmark")
                    .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text("歷史照片不代表目前成員陣容。").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("重新載入", systemImage: "arrow.clockwise") { retry += 1 }.font(.caption)
                    .disabled(loading)
            }
        }
        .task(id: "\(group.id)-\(retry)") {
            loading = true
            let result = await PhotoService.shared.gallery(group: group, seeds: catalog.photos(for: group), refresh: retry > 0)
            guard !Task.isCancelled else { return }
            photos = result; loading = false
        }
        .fullScreenCover(item: $selection) { photo in
            NavigationStack { FullPhotoView(photo: photo) }
                .modifier(ArtistTransition(id: photo.id, namespace: namespace, reduceMotion: reduceMotion))
        }
    }
}
struct FullPhotoView: View {
    let photo: ArtistPhotoRecord
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RemoteArtwork(photo: photo)
                        .frame(height: max(160, min(geometry.size.width / photo.aspectRatio, geometry.size.height * 0.72)))
                    PhotoCredit(photo: photo)
                }.padding(20).frame(maxWidth: 1200).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("完整照片").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "xmark") { dismiss() } } }
    }
}
