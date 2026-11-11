import SwiftUI

struct GroupDetailView: View {
    let group: IdolGroup
    @Environment(Catalog.self) private var catalog
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var memberQuery = ""
    @State private var section = "介紹"
    private var story: GroupStory? { catalog.story(for: group) }
    private var members: [Member] {
        group.members.filter { memberQuery.isEmpty || $0.name.localizedStandardContains(memberQuery) || (catalog.profile(for: $0)?.localName.localizedStandardContains(memberQuery) ?? false) }
    }
    var body: some View {
        ZStack {
            AtlasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ArtistPhoto(group: group)
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "ARTIST ARCHIVE / \(group.kind)")
                        Text(group.name).font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        Text(group.koreanName).font(.title3).foregroundStyle(.secondary)
                        Text(group.summary).font(.body).lineSpacing(5)
                    }.fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 220 : 120), spacing: 16)], alignment: .leading, spacing: 20) {
                        fact("出道年份", "\(group.debutYear.formatted(.number.grouping(.never)))")
                        fact("粉絲名稱", group.fandom)
                        fact("歷年成員紀錄", "\(group.memberNames.count) 位")
                    }.padding(20).background(.background.opacity(0.9), in: .rect(cornerRadius: 20))
                    if let company = catalog.company(for: group) {
                        NavigationLink { CompanyDetailView(company: company) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "building.2")
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(company.name).font(.subheadline.bold())
                                    Text("出道廠牌與歷史沿革").font(.caption).foregroundStyle(.secondary)
                                }.fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption)
                            }.padding(16).background(Color.atlasAccent.opacity(0.07), in: .rect(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                    Picker("團體內容", selection: $section.animation(reduceMotion ? nil : .easeInOut(duration: 0.22))) {
                        Text("介紹").tag("介紹")
                        Text("成員").tag("成員")
                        Text("相簿").tag("相簿")
                    }.pickerStyle(.segmented)
                    Group {
                        switch section {
                        case "成員": memberSection
                        case "相簿": PhotoGalleryView(group: group)
                        default: introduction
                        }
                    }.transition(.opacity)
                }.padding(20).frame(maxWidth: 950).frame(maxWidth: .infinity)
            }.scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle(group.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { AtlasFavoriteToolbar(id: group.id) }
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 26) {
            if let story {
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle(title: "名字背後的故事", subtitle: "從官方介紹與出道作品，找到探索的入口。")
                    Text(story.about).lineSpacing(6).textSelection(.enabled)
                    VStack(alignment: .leading, spacing: 16) {
                        fact("出道日期", story.debutDate)
                        fact("出道作品", story.debutRelease)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.opacity(0.8), in: .rect(cornerRadius: 18))
                }
                if !story.tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle(title: "從這幾首開始", subtitle: "點選歌曲，在 App 中尋找官方音樂影片。")
                        ForEach(Array(story.tracks.enumerated()), id: \.element.id) { index, track in
                            NavigationLink { WebPageView(url: track.searchURL(group: group.name), title: track.title) } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Text(String(format: "%02d", index + 1)).font(.headline.monospacedDigit()).foregroundStyle(Color.atlasAccent)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(track.title).font(.headline)
                                        Text(track.note).font(.subheadline).foregroundStyle(.secondary)
                                    }.fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    Image(systemName: "play.circle").font(.title2).foregroundStyle(Color.atlasAccent)
                                }.padding(18).background(.background.opacity(0.9), in: .rect(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "資料來源 / REFERENCES")
                    ForEach(story.sources) { source in
                        if let url = URL(string: source.url) {
                            NavigationLink { WebPageView(url: url, title: source.title) } label: {
                                Label(source.title, systemImage: "arrow.up.right.square").font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "繼續探索", subtitle: "成員、音樂與舞台，都是認識團體的起點。")
                Button { withAnimation(reduceMotion ? nil : .snappy) { section = "成員" } } label: {
                    Label("認識歷年成員", systemImage: "person.3").frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.glassProminent)
                Button { withAnimation(reduceMotion ? nil : .snappy) { section = "相簿" } } label: {
                    Label("瀏覽照片與圖片署名", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.glass)
                NavigationLink { WebPageView(url: group.videoURL, title: "\(group.name) 音樂影片") } label: {
                    Label("尋找官方音樂影片", systemImage: "play.rectangle")
                }
                NavigationLink { WebPageView(url: group.referenceURL, title: group.name) } label: {
                    Label("Wikipedia · 團體沿革", systemImage: "book")
                }
                ShareLink(item: group.referenceURL) { Label("分享團體參考頁", systemImage: "square.and.arrow.up") }
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(title: "歷年成員", subtitle: "包含現任、前成員與已故成員，不代表目前活動陣容。")
            TextField("搜尋成員名稱或韓文名", text: $memberQuery).textFieldStyle(.roundedBorder)
                .submitLabel(.search).autocorrectionDisabled()
            Text("\(members.count) 筆紀錄 · 點選查看人物資料與收藏")
                .font(.caption).foregroundStyle(.secondary)
            if members.isEmpty {
                ContentUnavailableView.search(text: memberQuery)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : 135), spacing: 14)], alignment: .leading, spacing: 18) {
                    ForEach(members) { member in
                        MemberLink(member: member, group: group) {
                            VStack(alignment: .leading, spacing: 12) {
                                MemberPortrait(member: member, group: group)
                                HStack(alignment: .top, spacing: 5) {
                                    Text(member.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    if catalog.favorites.contains(member.id) { Image(systemName: "heart.fill").font(.caption).foregroundStyle(Color.atlasAccent) }
                                }
                                if let birthday = catalog.profile(for: member)?.birthday {
                                    Text(birthday).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(12).background(.background.opacity(0.9), in: .rect(cornerRadius: 20))
                        }
                    }
                }
            }
            Text("人物照片須連線載入；尚未收錄照片或無法連線時顯示字母頭像。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
}

func initials(_ name: String) -> String {
    let words = name.split(separator: " ")
    return words.count > 1 ? String(words.prefix(2).compactMap(\.first)) : String(name.prefix(2)).uppercased()
}
struct MemberLink<Label: View>: View {
    let member: Member
    let group: IdolGroup
    @ViewBuilder let label: () -> Label
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationLink {
            MemberDetailView(member: member, group: group)
                .modifier(ArtistTransition(id: member.id, namespace: namespace, reduceMotion: reduceMotion))
        } label: { label().matchedTransitionSource(id: member.id, in: namespace) }.buttonStyle(.plain)
    }
}
struct MemberDetailView: View {
    let member: Member
    let group: IdolGroup
    @Environment(Catalog.self) private var catalog
    private var profile: MemberProfile? { catalog.profile(for: member) }
    var body: some View {
        ZStack {
            AtlasBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    MemberPortrait(member: member, group: group, showCredit: true)
                        .frame(maxWidth: 360).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "MEMBER ARCHIVE")
                        Text(member.name).font(.largeTitle.bold())
                        if let profile, !profile.localName.isEmpty { Text(profile.localName).font(.title3).foregroundStyle(.secondary) }
                        Text(group.name).font(.title3).foregroundStyle(Color.atlasAccent)
                    }.fixedSize(horizontal: false, vertical: true)
                    if let profile {
                        VStack(alignment: .leading, spacing: 16) {
                            if let birthday = profile.birthday {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("生日").font(.caption).foregroundStyle(.secondary)
                                    Text(birthday).font(.title3.bold())
                                }
                            }
                            Text("\(member.name) 收錄於 \(group.name) 的成員圖鑑。姓名與生日欄位以連結的官方人物資料為參考。")
                                .lineSpacing(5)
                            if let url = URL(string: profile.sourceURL) {
                                NavigationLink { WebPageView(url: url, title: "官方人物資料") } label: {
                                    Label("查閱官方人物資料", systemImage: "checkmark.seal")
                                }
                            }
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.opacity(0.9), in: .rect(cornerRadius: 20))
                    } else {
                        Text("此人物已收錄在團體歷年名錄中，個人生日與詳細介紹尚待補充，可由下方連結繼續查閱。")
                            .foregroundStyle(.secondary).lineSpacing(5)
                    }
                    ArtistLink(group: group) { Label("認識 \(group.name)", systemImage: "person.3").foregroundStyle(Color.atlasAccent) }
                    NavigationLink {
                        WebPageView(url: profile.flatMap { URL(string: "https://en.wikipedia.org/wiki/" + $0.wikipediaTitle.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!) } ?? member.searchURL(group: group.name), title: member.name)
                    } label: { Label("閱讀人物延伸資料", systemImage: "book") }
                    Text("歷年名錄包含現任、前成員與已故成員。個人經紀公司及活動狀態請以最新官方公告為準。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    ShareLink(item: member.searchURL(group: group.name)) { Label("分享人物搜尋", systemImage: "square.and.arrow.up") }
                }.padding(20).frame(maxWidth: 750).frame(maxWidth: .infinity)
            }.scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationTitle(member.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { AtlasFavoriteToolbar(id: member.id) }
    }
}
