import SwiftUI

struct DiscoverView: View {
    @Environment(Catalog.self) private var catalog
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showAbout = false
    @State private var featuredID: String?
    private var featured: [IdolGroup] {
        ["BTS", "BLACKPINK", "TWICE", "SEVENTEEN", "aespa"].compactMap { name in catalog.groups.first { $0.name == name } }
    }
    var body: some View {
        ZStack {
            AtlasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    intro
                    featuredPager
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 160 : 90))], spacing: 20) {
                        stat("\(catalog.companies.count)", "公司與廠牌")
                        stat("\(catalog.groups.count)", "團體故事")
                        stat("\(catalog.memberCount)", "歷年成員紀錄")
                    }.padding(20).background(.background.opacity(0.8), in: .rect(cornerRadius: 22))
                    VStack(spacing: 18) {
                        SectionTitle(title: "找到你的音樂宇宙", subtitle: "從熟悉的公司出發，遇見不同的聲音。")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 220 : 140), spacing: 12)], spacing: 12) {
                            ForEach(["HYBE", "SM", "JYP", "YG"], id: \.self) { family in
                                NavigationLink { FamilyView(family: family) } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(family).font(.title3.weight(.black))
                                            Text("探索旗下廠牌").font(.caption).foregroundStyle(.secondary)
                                        }.fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.right").font(.caption.bold())
                                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.atlasAccent.opacity(0.08), in: .rect(cornerRadius: 18))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    VStack(spacing: 18) {
                        SectionTitle(title: "從一首歌，開始認識", subtitle: "新增官方出道資料、作品介紹與成員小檔案。")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 160), spacing: 16)], alignment: .leading, spacing: 20) {
                            ForEach(catalog.groups.filter { catalog.story(for: $0) != nil }) { group in
                                ArtistLink(group: group) { GroupCard(group: group) }
                            }
                        }
                    }
                    VStack(spacing: 16) {
                        SectionTitle(title: "不同世代，一樣心動", subtitle: "左右滑動，尋找你的下一個收藏。")
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(catalog.groups.filter { [2007, 2015, 2021, 2023].contains($0.debutYear) }.prefix(12)) { group in
                                    ArtistLink(group: group) { GroupCard(group: group) }.containerRelativeFrame(.horizontal, count: 1, spacing: 16)
                                }
                            }.scrollTargetLayout()
                        }.scrollTargetBehavior(.viewAligned)
                    }
                    NavigationLink { AboutView() } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "book.closed").font(.title2)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("持續探索的 K-pop 圖鑑").font(.headline)
                                Text("資料範圍、圖片署名與使用設定").font(.caption).foregroundStyle(.secondary)
                            }.fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(20).background(.background.opacity(0.8), in: .rect(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }.padding(20).frame(maxWidth: 1050).frame(maxWidth: .infinity)
            }.refreshable { catalog.imageReloadToken += 1 }.scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle("K‑POP 星圖")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("關於與設定", systemImage: "slider.horizontal.3") { showAbout = true }
            }
        }
        .sheet(isPresented: $showAbout) {
            NavigationStack { AboutView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showAbout = false } } } }
                .presentationDragIndicator(.visible)
        }
    }
    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "YOUR K-POP UNIVERSE")
            Text("每一次心動，\n都有一個名字。")
                .font(.system(.largeTitle, design: .serif, weight: .bold)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("認識舞台上的光，也探索名字背後的故事。")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.top, 6)
    }
    private var featuredPager: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "ARTIST SPOTLIGHT / 精選團體")
                Spacer(minLength: 8)
                Text("\((featured.firstIndex { $0.id == featuredID } ?? 0) + 1) / \(featured.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            // Natural card height keeps long names and Dynamic Type outside the photo.
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(featured) { group in
                        ArtistLink(group: group) {
                            VStack(alignment: .leading, spacing: 16) {
                                ArtistPhoto(group: group)
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.name).font(.system(.title, design: .rounded, weight: .heavy))
                                    Text(group.koreanName).font(.subheadline).foregroundStyle(.secondary)
                                    Text(group.summary).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                                    Label("認識團體", systemImage: "arrow.up.right").font(.subheadline.bold()).foregroundStyle(Color.atlasAccent)
                                }.fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8).padding(.bottom, 10)
                            }.padding(12).background(.background.opacity(0.9), in: .rect(cornerRadius: 26))
                                .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.06)))
                        }.containerRelativeFrame(.horizontal).id(group.id)
                    }
                }.scrollTargetLayout()
            }.scrollTargetBehavior(.paging).scrollPosition(id: $featuredID)
            Text("左右滑動探索精選團體").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Color.atlasAccent)
            Text(caption).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
    }
}
