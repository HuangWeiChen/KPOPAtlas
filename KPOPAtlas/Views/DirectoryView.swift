import SwiftUI

struct DirectoryView: View {
    @Environment(Catalog.self) private var catalog
    @State private var query = ""
    @State private var kind = "全部"
    @State private var sort = "名稱"
    @AppStorage("atlas.directoryList") private var isList = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var decade = 0
    private let kinds = ["全部", "女團", "男團", "樂團", "混聲團"]
    private var filtered: [IdolGroup] {
        catalog.groups.filter { catalog.matches($0, query: query) && (kind == "全部" || $0.kind == kind) && (decade == 0 || $0.debutYear / 10 * 10 == decade) }
            .sorted { sort == "出道年份" ? ($0.debutYear, $0.name) < ($1.debutYear, $1.name) : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        ZStack {
            AtlasBackground()
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(kinds, id: \.self) { item in
                            Button { withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { kind = item } } label: {
                                Text(item).font(.subheadline.weight(.semibold)).padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(kind == item ? Color.atlasAccent : Color.atlasAccent.opacity(0.08), in: .capsule)
                                    .foregroundStyle(kind == item ? .white : .primary)
                            }.accessibilityAddTraits(kind == item ? .isSelected : [])
                        }
                    }.padding(.horizontal, 22).padding(.vertical, 12)
                }
                HStack {
                    Text("\(filtered.count) 個團體").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Picker("排序", selection: $sort) {
                            Text("名稱").tag("名稱")
                            Text("出道年份").tag("出道年份")
                        }
                        Picker("出道年代", selection: $decade) {
                            Text("所有年代").tag(0)
                            ForEach([1990, 2000, 2010, 2020], id: \.self) { year in
                                Text("\(year.formatted(.number.grouping(.never))) 年代").tag(year)
                            }
                        }
                        Button("重設篩選") { kind = "全部"; decade = 0; query = "" }
                    } label: {
                        Label(decade == 0 ? "排序與年代" : "\(decade.formatted(.number.grouping(.never))) 年代", systemImage: "line.3.horizontal.decrease")
                            .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 9)
                    }.buttonStyle(.glass)
                }.padding(.horizontal, 22)
                if filtered.isEmpty {
                    ContentUnavailableView {
                        Label("沒有符合的團體", systemImage: "magnifyingglass")
                    } description: {
                        Text("試試其他名稱，或清除類型與年代篩選。")
                    } actions: {
                        Button("清除篩選") { query = ""; kind = "全部"; decade = 0 }
                    }
                } else if isList {
                    List(filtered) { group in
                        ArtistLink(group: group) { GroupRow(group: group) }
                    }.listStyle(.plain).scrollContentBackground(.hidden).refreshable { catalog.imageReloadToken += 1 }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 155), spacing: 16)], alignment: .leading, spacing: 24) {
                            ForEach(filtered) { group in
                                ArtistLink(group: group) { GroupCard(group: group) }.buttonStyle(.plain)
                            }
                        }.padding(22).frame(maxWidth: 1200).frame(maxWidth: .infinity)
                    }.refreshable { catalog.imageReloadToken += 1 }
                }
            }
        }
        .navigationTitle("團體圖鑑")
        .searchable(text: $query, prompt: "搜尋團體、韓文名、成員或公司")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isList ? "切換照片牆" : "切換列表", systemImage: isList ? "square.grid.2x2" : "list.bullet") { isList.toggle() }
            }
        }
    }
}

struct CompaniesView: View {
    @Environment(Catalog.self) private var catalog
    @State private var query = ""
    private var companies: [Company] {
        catalog.companies.filter { query.isEmpty || ($0.name + $0.family).localizedStandardContains(query) }
    }
    var body: some View {
        List {
            Section {
                Text("以出道公司與廠牌沿革分類。歷史團體亦收錄於原出道公司；這不是現行合約名單。")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
            }
            ForEach(["HYBE", "SM", "JYP", "YG", "獨立廠牌", "RBW 旗下", "CJ ENM", "歷史廠牌"], id: \.self) { family in
                let items = companies.filter { $0.family == family }
                if !items.isEmpty {
                    Section(family) {
                        ForEach(items) { company in
                            NavigationLink { CompanyDetailView(company: company) } label: { CompanyRow(company: company) }
                        }
                    }
                }
            }
        }
        .overlay { if companies.isEmpty { ContentUnavailableView.search(text: query) } }
        .navigationTitle("公司與廠牌")
        .searchable(text: $query, prompt: "搜尋公司或母公司")
    }
}

struct CompanyRow: View {
    let company: Company
    @Environment(Catalog.self) private var catalog
    var body: some View {
        HStack(spacing: 14) {
            CompanyLogo(company: company).frame(width: 56)
            VStack(alignment: .leading, spacing: 5) {
                Text(company.name).font(.headline)
                Text("收錄 \(catalog.groups(for: company).count) 個團體").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }
}

struct FamilyView: View {
    let family: String
    @Environment(Catalog.self) private var catalog
    var body: some View {
        List(catalog.companies.filter { $0.family == family }) { company in
            NavigationLink { CompanyDetailView(company: company) } label: { CompanyRow(company: company) }
        }.navigationTitle(family)
    }
}

struct CompanyDetailView: View {
    let company: Company
    @Environment(Catalog.self) private var catalog
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    CompanyLogo(company: company, showCredit: true).frame(maxWidth: 180)
                    Eyebrow(text: company.family.uppercased())
                    Text(company.name).font(.largeTitle.bold())
                    Text(company.summary).foregroundStyle(.secondary)
                    NavigationLink { WebPageView(url: company.url, title: company.name) } label: {
                        Label(company.family == "歷史廠牌" ? "歷史參考頁" : "造訪公司網站", systemImage: "globe")
                    }
                }.padding(.vertical, 12)
            }
            Section("團體圖鑑 · 出道與廠牌沿革") {
                ForEach(catalog.groups(for: company).sorted { $0.debutYear < $1.debutYear }) { group in
                    ArtistLink(group: group) { GroupRow(group: group) }
                }
            }
            Section {
                Text("成員個人、團體合約與商標權可能分屬不同公司。請以藝人及公司的最新公告為準。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle(company.name).navigationBarTitleDisplayMode(.inline)
    }
}
