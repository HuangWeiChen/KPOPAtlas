# SwiftUI 電子書 App｜K-POP 星圖：從公司、團體到成員的韓流圖鑑

平常接觸 K-pop 時，常常會先認識一首歌，再慢慢去查團體、成員與所屬公司。不過，這些資訊通常分散在不同網站，想同時了解不同團體時，就需要一直切換頁面。

因此，這次的電子書 App 作業，我選擇以 K-pop 為主題，製作「K-POP 星圖」。希望讓使用者能從公司出發，一路找到團體與成員，也能透過圖片、收藏與搜尋，建立自己的追星小圖鑑。

## 一、App 簡介

K-POP 星圖是一款以 SwiftUI 製作的繁體中文圖鑑，目前收錄 39 個公司／廠牌、116 個團體，以及 841 筆歷年成員紀錄。

這裡的成員紀錄包含現任與前成員，同一人物若參與不同團體，也可能分別出現在各團的名單中，所以這個數字不代表 841 位不同人物。整體內容以歷史介紹為主，並不是即時更新的現役名單。

視覺上，我希望它保有追星的活潑感，同時讓文字容易閱讀。因此使用照片卡片、柔和背景與清楚的資訊層級，將大量資料分成可以逐步探索的頁面。

> 建議插入圖片：探索首頁、團體頁、成員頁。

## 二、主要功能與實作

### 1. 使用 TabView 整合多個頁面

App 將探索、公司、圖鑑與收藏分成四個分頁，設定則由關於頁提供，讓每個分頁都有明確用途。

探索頁提供精選團體與公司入口；公司頁適合依廠牌瀏覽；圖鑑頁則讓使用者直接搜尋。分頁採用系統自適應設計，在 iPhone 使用底部分頁列，iPad 則透過 `.sidebarAdaptable` 支援適合大螢幕的導覽方式。

以下節錄主畫面的分頁結構。每個分頁各自包在 `NavigationStack` 裡，讓不同功能保有自己的導覽路徑；共用資料則由 `.environment(catalog)` 傳入。

```swift
TabView {
            Tab("探索", systemImage: "sparkles") {
                NavigationStack { DiscoverView() }
            }
            Tab("公司", systemImage: "building.2") {
                NavigationStack { CompaniesView() }
            }
            Tab("圖鑑", systemImage: "magnifyingglass", role: .search) {
                NavigationStack { DirectoryView() }
            }
            Tab("收藏", systemImage: "heart") {
                NavigationStack { FavoritesView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.atlasAccent)
        .environment(catalog)
```

### 2. 使用 NavigationStack 傳遞資料

使用者可以從公司進入團體，再點選成員查看人物頁面。這些頁面透過 `NavigationStack` 與 `NavigationLink` 串接，將選取的資料傳給下一頁，並在導覽列顯示對應標題。

這樣的流程讓資料之間的關係更清楚，也能保留返回上一層的操作習慣。

公司頁的導覽會將使用者點選的 `company` 傳入下一頁。下一頁再依公司 ID 取得對應團體，因此不需要為每家公司另外寫一個頁面。

```swift
ForEach(items) { company in
    NavigationLink {
        CompanyDetailView(company: company)
    } label: {
        CompanyRow(company: company)
    }
}
```

### 3. 用自訂 Model 管理資料

資料主要分成 `Company`、`IdolGroup` 與 `Member`，各自遵從 `Identifiable`。公司與團體資料存放在 JSON，讀取後轉換為 Swift 的陣列，交給畫面呈現。

例如，公司資料的結構如下：

```swift
struct Company: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let family: String
    let summary: String
    let website: String
}
```

每筆資料都有穩定的 ID，除了方便 `List` 與 `ForEach` 顯示，也能用來建立公司與團體之間的關聯，以及儲存收藏。

JSON 讀取的核心程式碼如下，這段位於 `Catalog` 的初始化流程中。`Codable` 讓 JSON 轉成自訂型別；外層再以 `do / catch` 處理讀取失敗的情況。

```swift
guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
```

### 4. 搜尋、篩選與兩種瀏覽方式

圖鑑可以搜尋團體名稱、韓文名稱、成員、粉絲名稱與公司，並搭配類型、年代篩選及排序。

考慮到有人喜歡看圖片，也有人想快速掃描名稱，因此加入照片牆與列表模式。當搜尋沒有結果時，畫面也會提供清除篩選的入口，避免使用者不知道如何回到完整名單。

搜尋邏輯集中在 `Catalog`，讓不同畫面需要搜尋時能共用同一套規則。輸入先移除頭尾空白，再比對團體、公司與成員等欄位。

```swift
func matches(_ group: IdolGroup, query: String) -> Bool {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return search.isEmpty || ([group.name, group.koreanName, group.fandom, company(for: group)?.name ?? ""] + group.memberNames)
            .contains { $0.localizedStandardContains(search) }
    }
```

### 5. 在垂直頁面中加入水平瀏覽

探索頁使用垂直捲動呈現不同主題，部分區塊則採水平滑動。使用者可以先上下查看分類，再左右瀏覽同一區塊的團體，不需要一次看到所有內容。

照片牆則使用 `LazyVGrid`，讓欄位隨可用寬度調整，並針對較大的文字尺寸增加卡片寬度。

以下節錄照片牆的排列方式。`adaptive` 會依可用空間調整欄數；當使用者啟用輔助使用的大字體尺寸時，增加最小欄寬，避免卡片內的文字過度擠壓。

```swift
LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 155), spacing: 16)], alignment: .leading, spacing: 24) {
                            ForEach(filtered) { group in
                                ArtistLink(group: group) { GroupCard(group: group) }.buttonStyle(.plain)
                            }
                        }.padding(22).frame(maxWidth: 1200).frame(maxWidth: .infinity)
```

### 6. 圖片保留完整構圖

團體照經常很寬，如果直接填滿固定框架，兩側成員就容易被裁掉。因此，藝人照片使用 `.scaledToFit()`，在卡片內保留完整比例，名稱則放在照片外面，避免遮住人物。

目前已內建 115 個團體封面、610 筆成員圖片與 15 個公司 Logo 的來源索引，圖片本體仍需網路載入。尚未補齊的公司使用字母圖示，未取得人物照片時則保留姓名縮寫。

照片主要透過 Wikipedia 與 Wikidata 的資料建立關聯。比起直接用姓名搜尋圖片，先確認人物與團體的關係，更能降低同名人物配錯照片的機會。太近期、尚未有獨立百科的項目，目前先暫緩補齊。

圖片載入元件會區分成功、失敗與等待三種狀態。成功時使用 `.scaledToFit()`，載入失敗則顯示提示，而不是讓畫面只留下空白。以下為 `RemoteArtwork` 的核心節錄，`photo`、`reloadToken` 與 `reduceMotion` 都是元件既有屬性。

```swift
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
```

### 7. 收藏、動畫與轉場

使用者可以收藏團體與成員，收藏 ID 透過 `UserDefaults` 儲存在裝置上。操作時搭配愛心符號動畫與觸覺回饋，讓收藏狀態更容易辨識。

頁面導覽與全螢幕照片使用原生縮放轉場，圖片載入則搭配淡入效果。App 也會配合系統的「減少動態效果」設定，降低不必要的動態變化。

介面另外採用 Liquid Glass 按鈕樣式，並對較新系統的圖片快取與轉場 API 加上版本檢查，維持 iOS 26 的相容性。

收藏的儲存邏輯放在 `Catalog`。當集合改變時，`didSet` 會把 ID 轉成陣列寫入 `UserDefaults`；再次啟動時再讀回集合。以下為同一個類別內的相關節錄。

```swift
var favorites: Set<String> {
    didSet {
        UserDefaults.standard.set(Array(favorites), forKey: "atlas.favorites")
    }
}

// 在 init() 中還原收藏
// favorites = Set(UserDefaults.standard.stringArray(forKey: "atlas.favorites") ?? [])

func toggle(_ id: String) {
    if favorites.contains(id) {
        favorites.remove(id)
    } else {
        favorites.insert(id)
    }
}
```

按鈕則透過環境取得同一份 `Catalog`。愛心狀態、符號動畫與觸覺回饋都由收藏集合的變化觸發，並配合「減少動態效果」設定。

```swift
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
```

導覽縮放轉場的來源與目的地必須使用相同 ID 和 namespace。專案將這段行為封裝在 `ArtistLink` 中，讓照片卡片與列表列都能共用。以下省略目的地的減少動態效果判斷，示範一般情況的核心寫法。

```swift
NavigationLink {
    GroupDetailView(group: group)
        .navigationTransition(.zoom(sourceID: group.id, in: namespace))
} label: {
    label()
        .matchedTransitionSource(id: group.id, in: namespace)
}
.buttonStyle(.plain)
```

### 8. 網頁、影片與深淺模式

團體與成員頁提供參考資料入口，透過 WebView 閱讀延伸內容。音樂探索目前提供 YouTube 搜尋連結；影片播放功能則讓使用者選取本機影片，以 `VideoPlayer` 播放。

外觀支援跟隨系統、淺色及深色模式，讓不同使用情境都有合適的閱讀背景。

網頁部分使用 WebKit 的 `WebPage` 與 `WebView`。以下為簡化範例，完整專案另外加入載入指示、失敗提示、重試及外部瀏覽器入口。

```swift
import SwiftUI
import WebKit

struct ReferencePage: View {
    let url: URL
    @State private var page = WebPage()

    var body: some View {
        WebView(page)
            .onAppear { page.load(url) }
    }
}
```

外觀偏好使用 `@AppStorage` 保存，再交給 `.preferredColorScheme`。其中 `nil` 代表跟隨系統，不需要手動為每個畫面切換背景。這些修飾放在主畫面的根 View 上。

```swift
@AppStorage("atlas.appearance") private var appearance = "system"

// 套用在主畫面的 TabView 上：
// .preferredColorScheme(
//     appearance == "dark" ? .dark : appearance == "light" ? .light : nil
// )
```

## 三、App 名稱與圖示

我將 App 命名為「K-POP 星圖」，因為公司、團體與成員就像彼此相連的星點，可以從不同入口慢慢探索。

App Icon 使用選定的 Winter 照片，並另外保留原始圖片。介面中的藝人照片維持完整比例，圖示則依系統的正方形規格調整。這是非官方學習作品，圖片來源與權利仍屬原作者。

## 四、製作過程中的挑戰

這次最需要處理的，是資料與圖片的正確對應。K-pop 團體可能經歷改名、轉換公司或成員異動，因此單純放上一份名單，很容易讓人誤以為那就是目前的完整陣容。

我的做法是將內容定位為歷史圖鑑，清楚說明名單範圍，並保留來源連結。圖片部分也區分已整理署名的照片與批次建立的來源索引，沒有把所有圖片都標示為相同授權。

目前編譯與資料檢查已通過，也透過 iPhone 畫面確認部分圖片及版面。不過，大量圖片尚未逐張人工核對，iPad、VoiceOver 與其他操作情境也仍需要持續測試。

## 五、心得與後續方向

這次實作讓我發現，電子書 App 除了把內容放進畫面，更需要考慮使用者會從哪裡開始、如何找到下一筆資料，以及閱讀時會不會被圖片裁切或過多資訊打斷。

透過拆分 Model、頁面與圖片服務，我也比較能理解資料管理和畫面呈現之間的關係。之後希望補上更完整的成員任期、團體沿革與圖片署名，並持續調整大螢幕及輔助使用體驗，讓「K-POP 星圖」成為更容易探索的韓流圖鑑。

## 參考資料

- [新聞閱讀 App：本篇文章的呈現方式參考](https://medium.com/海大-ios-app-程式設計/新聞閱讀-app-630f58c7db71)
- [Apple SwiftUI 文件](https://developer.apple.com/documentation/swiftui)
- [Wikipedia](https://en.wikipedia.org/)
- [Wikidata](https://www.wikidata.org/)
- [Winter 圖示照片來源：Korea JoongAng Daily／NEWS1](https://www.koreajoongangdaily.com/entertainment/aespas-winter-misses-dallas-concert-after-shingles-diagnosis/12898469)
