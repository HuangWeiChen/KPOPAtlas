import SwiftUI

struct FavoritesView: View {
    @Environment(Catalog.self) private var catalog
    @State private var query = ""
    private var groups: [IdolGroup] {
        catalog.groups.filter { catalog.favorites.contains($0.id) && catalog.matches($0, query: query) }
    }
    private var members: [(Member, IdolGroup)] {
        catalog.groups.flatMap { group in
            group.members.filter {
                catalog.favorites.contains($0.id) && (query.isEmpty || ($0.name + group.name).localizedStandardContains(query))
            }.map { ($0, group) }
        }
    }
    var body: some View {
        List {
            if !groups.isEmpty {
                Section("收藏團體") {
                    ForEach(groups) { group in
                        ArtistLink(group: group) { GroupRow(group: group) }
                            .swipeActions { Button("取消收藏", role: .destructive) { catalog.toggle(group.id) } }
                    }
                }
            }
            if !members.isEmpty {
                Section("收藏成員") {
                    ForEach(members, id: \.0.id) { member, group in
                        NavigationLink { MemberDetailView(member: member, group: group) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(member.name).font(.headline)
                                Text(group.name).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 7)
                        }
                        .swipeActions { Button("取消收藏", role: .destructive) { catalog.toggle(member.id) } }
                    }
                }
            }
        }
        .overlay {
            if groups.isEmpty && members.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("把心動留在這裡", systemImage: "heart", description: Text("在團體或成員頁點一下愛心，\n建立屬於你的 K-pop 星圖。收藏會儲存在此裝置。"))
                } else { ContentUnavailableView.search(text: query) }
            }
        }
        .navigationTitle("我的收藏")
        .searchable(text: $query, prompt: "搜尋已收藏的團體或成員")
    }
}
