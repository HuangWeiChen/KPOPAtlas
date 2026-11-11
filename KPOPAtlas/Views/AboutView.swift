import SwiftUI
import AVKit

struct AboutView: View {
    @Environment(Catalog.self) private var catalog
    @AppStorage("atlas.appearance") private var appearance = "system"
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sparkles.square.filled.on.square").font(.largeTitle).foregroundStyle(Color.atlasAccent)
                    Text("K‑POP 星圖").font(.largeTitle.bold())
                    Text("K‑POP ATLAS / 每一次心動，都有一個名字。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("一本用來探索公司、團體與歷年成員的互動圖鑑。")
                }.padding(.vertical, 12)
            }
            Section("外觀") {
                Picker("顯示模式", selection: $appearance) {
                    Text("跟隨系統").tag("system")
                    Text("淺色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            Section("資料範圍") {
                LabeledContent("公司與廠牌", value: "\(catalog.companies.count)")
                LabeledContent("團體", value: "\(catalog.groups.count)")
                LabeledContent("歷年成員紀錄", value: "\(catalog.memberCount)")
                Text("此版本是精選歷史圖鑑，不是所有韓國藝人的完整資料庫，亦非即時現役名單。成員紀錄按團體計算，同一人物跨團體可能重複出現。")
                Text("公司依出道廠牌及歷史沿革分類；母公司標籤僅協助瀏覽。THE BOYZ、Apink 等團體也包含廠牌前身時期；子團分開收錄，並不代表涵蓋 NCT 的全部活動編制。")
                Text("成員名錄包含現任、前成員及已故成員。未逐一標示任期，不應用於判定目前陣容、合約或活動狀態。")
                Text("本地資料編輯：2026 年 11 月。個別歷史紀錄仍可能有缺漏，請由團體參考頁核對。")
            }.font(.subheadline)
            Section("參考來源與圖片") {
                Text("公司網站與官方藝人目錄用於核對廠牌與藝人關聯；各團體頁連結 Wikipedia，供進一步核對出道及成員沿革。")
                ForEach(catalog.companies.filter { ["bighit", "sm", "jyp", "yg", "starship", "cube", "fnc"].contains($0.id) }) { company in
                    NavigationLink { WebPageView(url: company.url, title: company.name) } label: { Text(company.name) }
                }
                LabeledContent("精選署名照片", value: "\(catalog.photos.count) 張")
                LabeledContent("深入團體介紹", value: "\(catalog.stories.count) 組")
                LabeledContent("人物小檔案", value: "\(catalog.profiles.count) 位")
                Text("精選照片附有作者、授權與原始圖片連結；另可連線讀取 Wikimedia Commons 的照片及署名資料。相簿提供全螢幕檢視，所有圖片皆保留完整比例。")
                Text("所有成員頁都會依團體關聯核對人物圖片；找不到可核對的照片時保留替代圖像，不以同名人物的照片代替。公司圖示優先載入資料來源列出的 Logo，未取得 Logo 時顯示公司字母圖示。")
                Text("人物小檔案目前提供部分成員的韓文名、官方生日與資料來源；未補齊的欄位不會以推測資料填入。海報與字母圖示是 App 原創圖形。")
                Text("App 圖示使用你指定的 Winter 照片，原刊載於 Korea JoongAng Daily，照片署名 NEWS1。僅作方形構圖與尺寸調整，保留原始人物樣貌。")
                NavigationLink { WebPageView(url: URL(string: "https://www.koreajoongangdaily.com/entertainment/aespas-winter-misses-dallas-concert-after-shingles-diagnosis/12898469")!, title: "Winter 圖示照片來源") } label: {
                    Label("Winter 圖示照片來源", systemImage: "photo")
                }
                Text("本 App 為非官方學習作品，與各公司及藝人無隸屬或代言關係。")
            }.font(.subheadline)
            Section("影片播放") {
                Text("團體頁提供 YouTube 音樂影片搜尋。下方可播放你有權使用的本機影片，影片不會上傳。")
                LocalVideoView()
            }
            Section("操作小提示") {
                Text("點選團體卡片即可進入詳情；在介紹、成員與相簿間切換，找到想看的資訊。")
                Text("圖鑑可依團體類型及出道年代篩選。顯示模式會記住你的選擇，找不到結果時也能一鍵清除篩選。")
                Text("App 會配合系統字體大小與「減少動態效果」設定。重要操作與圖片說明保留在安全範圍內。")
            }
            Section("離線使用") {
                Text("公司、團體、成員與收藏可離線使用。圖片首次載入、網頁與 YouTube 需要網路。圖片快取視系統及伺服器設定保留，不保證離線永久可用；未載入時顯示替代圖像或重試提示。")
            }
        }.navigationTitle("關於與設定").navigationBarTitleDisplayMode(.inline)
    }
}

struct LocalVideoView: View {
    @State private var importing = false
    @State private var player: AVPlayer?
    @State private var selectedURL: URL?
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("選取本機影片", systemImage: "film") { importing = true }
            if let player {
                VideoPlayer(player: player).frame(height: 220).clipShape(.rect(cornerRadius: 12))
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.movie]) { result in
            switch result {
            case .success(let url):
                player?.pause()
                if let selectedURL { selectedURL.stopAccessingSecurityScopedResource() }
                guard url.startAccessingSecurityScopedResource() else {
                    selectedURL = nil; player = nil; error = "無法存取這個檔案，請重新選取。"; return
                }
                selectedURL = url; player = AVPlayer(url: url); error = nil
            case .failure:
                error = "影片無法開啟，請再試一次。"
            }
        }
        .onDisappear {
            player?.pause(); player = nil
            selectedURL?.stopAccessingSecurityScopedResource(); selectedURL = nil
        }
    }
}
