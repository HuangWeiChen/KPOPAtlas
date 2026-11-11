import SwiftUI

extension Color {
    static let atlasAccent = Color(red: 0.55, green: 0.29, blue: 0.72)
}
struct AtlasBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        (scheme == .dark ? Color(red: 0.08, green: 0.07, blue: 0.11) : Color(red: 0.98, green: 0.97, blue: 0.95)).ignoresSafeArea()
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
struct SectionTitle: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Only decorative artwork is clipped; names and controls live outside the artwork.
struct Poster: View {
    let group: IdolGroup
    var showName = true
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: group.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().stroke(.white.opacity(0.2), lineWidth: 1)
                    .frame(width: geometry.size.width * 0.9).offset(x: geometry.size.width * 0.25)
                Circle().stroke(.white.opacity(0.1), lineWidth: 24)
                    .frame(width: geometry.size.width * 0.65).offset(x: -geometry.size.width * 0.35, y: geometry.size.height * 0.3)
                Text(initials(group.name)).font(.system(size: min(geometry.size.width, geometry.size.height) * 0.35, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }.clipped().accessibilityHidden(true)
    }
}

struct GroupCard: View {
    let group: IdolGroup
    @Environment(Catalog.self) private var catalog
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtistPhoto(group: group).padding(8)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Text(group.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if catalog.favorites.contains(group.id) {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(Color.atlasAccent).accessibilityLabel("已收藏")
                    }
                }
                Text(group.koreanName).font(.caption).foregroundStyle(.secondary)
                Text("\(group.debutYear.formatted(.number.grouping(.never))) · \(group.kind)")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }.padding(.horizontal, 14).padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.8), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.07)))
        .contentShape(.rect(cornerRadius: 22))
    }
}
struct GroupRow: View {
    let group: IdolGroup
    var body: some View {
        HStack(spacing: 14) {
            ArtistPhoto(group: group, ratio: 1).frame(width: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(group.name).font(.headline)
                Text("\(group.koreanName) · \(group.debutYear.formatted(.number.grouping(.never)))")
                    .font(.caption).foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 6)
    }
}
struct FavoriteButton: View {
    let id: String
    @Environment(Catalog.self) private var catalog
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { catalog.toggle(id) }
        } label: {
            Image(systemName: catalog.favorites.contains(id) ? "heart.fill" : "heart")
                .symbolEffect(.bounce, value: catalog.favorites.contains(id))
                .symbolEffectsRemoved(reduceMotion)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .sensoryFeedback(.selection, trigger: catalog.favorites.contains(id))
        .accessibilityLabel(catalog.favorites.contains(id) ? "取消收藏" : "加入收藏")
    }
}

struct ArtistLink<Label: View>: View {
    let group: IdolGroup
    @ViewBuilder let label: () -> Label
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationLink {
            GroupDetailView(group: group)
                .modifier(ArtistTransition(id: group.id, namespace: namespace, reduceMotion: reduceMotion))
        } label: {
            label().matchedTransitionSource(id: group.id, in: namespace)
        }.buttonStyle(.plain)
    }
}
struct ArtistTransition: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let reduceMotion: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion {
            if #available(iOS 27, *) { content.navigationTransition(.crossFade) }
            else { content }
        } else { content.navigationTransition(.zoom(sourceID: id, in: namespace)) }
    }
}

struct AtlasFavoriteToolbar: ToolbarContent {
    let id: String
    var body: some ToolbarContent {
        if #available(iOS 27, *) {
            ToolbarItem(placement: .topBarPinnedTrailing) { FavoriteButton(id: id) }.visibilityPriority(.high)
        } else {
            ToolbarItem(placement: .primaryAction) { FavoriteButton(id: id) }
        }
    }
}
