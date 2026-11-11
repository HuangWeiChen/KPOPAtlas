# K‑POP 星圖 · K‑POP Atlas

使用 SwiftUI 製作的繁體中文 K-pop 互動圖鑑，收錄 **39 個公司／廠牌、116 個團體、841 筆歷年成員紀錄**。

## 執行

1. 使用 Xcode 27 或更新版本開啟 `KPOPAtlas.xcodeproj`。
2. 選擇共用 Scheme **KPOPAtlas**，以及 iOS 26／iPadOS 26 以上的模擬器或實機。
3. 按 Run。實機執行須在 Signing & Capabilities 選擇自己的開發團隊；如有 Bundle ID 衝突，改成自己的識別碼。

主畫面名稱為 **K-POP 星圖**。專案、Target、Scheme 與執行檔名稱為 **KPOPAtlas**。App Icon 與啟動畫面已設定。原始 `Untitled Project` 目錄已重新命名為本目錄。

不需要 API Key、登入或第三方套件。公司、團體、成員及收藏可離線使用；圖片、網頁與 YouTube 搜尋需要網路。

## 功能

- **探索**：可左右滑動的精選、主要公司入口，以及垂直頁面中的水平團體區塊。
- **公司**：依公司家族分類，逐層瀏覽公司、團體與成員。
- **圖鑑**：搜尋團體、韓文名、成員、粉絲名稱或公司；依類型篩選，按名稱／年份排序，切換照片牆與列表。
- **收藏**：收藏團體與成員，儲存於此裝置的 UserDefaults；支援搜尋及滑動取消收藏。
- **團體／成員**：團體簡介、出道年份、粉絲名稱、歷年成員、參考網頁、影片搜尋與分享。成員頁提供歷史關聯與人物搜尋，尚未建立逐人的生日、國籍與完整傳記。
- **設定**：跟隨系統、淺色或深色模式；資料範圍與來源說明。
- **影片**：在「關於與設定 → 影片播放」選取有權使用的本機影片，透過 `VideoPlayer` 播放，不會上傳。

## 作業需求對照

| 需求 | 實作位置 |
| --- | --- |
| 多頁面、NavigationStack／NavigationLink、傳遞資料、導覽標題 | `ContentView.swift`、`Views/` |
| 自訂 struct、Identifiable 與 array | `Models/Catalog.swift`、`Resources/catalog.json` |
| List 與 Identifiable 資料 | `CompaniesView`、`CompanyDetailView`、`FavoritesView`、圖鑑列表模式 |
| TabView 與 Tab、iPhone 下方分頁、iPad 上方分頁與側邊欄 | `ContentView.swift` 的 `.sidebarAdaptable` |
| 水平滑動分頁 | `DiscoverView.swift` 的 `.page` TabView |
| animation 與 transition | 收藏切換、團體成員區展開／收合 |
| SF Symbols 與 symbolEffect | 分頁與操作圖示、收藏愛心 bounce；尊重減少動態效果設定 |
| WebView | `WebPageView.swift`，原生 WebKit WebPage／WebView |
| 深淺模式 | `AtlasBackground` 與外觀設定 |
| 格狀照片牆與 AsyncImage | `DirectoryView.swift`、`ArtistPhoto`、`PhotoService` |
| 垂直頁面中的水平捲動區塊 | `DiscoverView.swift` |
| VideoPlayer | `AboutView.swift` 的 `LocalVideoView` |
| App 名稱、圖示及 Info.plist 啟動畫面 | 專案設定、`Assets.xcassets`、`Info.plist` |

iPhone／iPad 的分頁位置採系統自適應行為；iPad 可使用系統提供的側邊欄切換控制。已透過 Device Hub 檢視 iPhone 畫面；尚未整理展示截圖或操作影片。額外加分項目中的對外 landing page 與 pinned header／footer 尚未製作。

## 資料與圖片

這是精選的歷史圖鑑，**並非全部 K-pop 團體的完整資料庫，也不是即時現役名單**。公司依出道廠牌、前身及沿革分類；個人與團體目前的合約可能不同。名錄包含現任、前成員及已故成員，尚未逐筆標註任期與狀態。同一人物跨團體可能重複計入成員紀錄。

出道年份通常採韓國出道年份，個別跨國企劃會註明例外。資料為人工編輯，未對每位成員逐一完成獨立事實查核；發布前仍須核對原始公告。主要公司研究來源及各團體延伸參考連結見 [SOURCES.md](SOURCES.md)。

圖片索引已內建於 `media-manifest.json`：115 個團體封面、610 筆成員圖片及 15 個公司 Logo。圖片本體仍需網路；未收錄的公司顯示字母圖示，其他圖片可透過 Wikipedia／Wikidata 補查。太近期且未有獨立百科的項目暫緩補齊，不以其他人物代替。所有藝人照片以完整比例顯示。

另有 8 張具完整署名的策展照片、6 篇團體介紹與 38 筆成員延伸資料。批次圖片的個別作者與授權尚未全部人工核對，因此圖片旁直接連結原始檔案查閱；不把它們一律標成 CC 授權。App Icon 使用使用者指定的 Winter／NEWS1 照片，來源見 App 內關於頁。本 App 為非官方學習作品。

導覽加入原生縮放轉場、減少動態效果支援及 Liquid Glass 操作；iOS 27 的圖片快取工作階段、淡化轉場與工具列 API 均有版本檢查，維持 iOS 26 相容。

## 維護

編輯 `KPOPAtlas/Resources/catalog.json` 即可擴充內容。每個團體的 `companyID` 必須對應公司 ID，`id` 應保持穩定，避免既有收藏失效。成員收藏以「團體 ID + 成員姓名」作識別；修改成員姓名時須考慮舊收藏的遷移。

驗證資料：

```sh
python3 Scripts/validate_catalog.py
```

一般無簽章編譯：

```sh
xcodebuild -project KPOPAtlas.xcodeproj -scheme KPOPAtlas \
  -sdk iphoneos -configuration Debug \
  -derivedDataPath /tmp/kpop-atlas-build CODE_SIGNING_ALLOWED=NO build
```

## 本次驗證範圍

- iPhone／iPad 通用 iOS 目標 Debug 編譯成功。
- 資料 ID 唯一性、公司關聯、必填欄位、網址格式及部分團體成員數量檢查通過。
- 檢查編譯產物的顯示名稱、圖示、啟動畫面與打包資料。
- 已檢視生成的 App Icon。
- 已透過 Xcode／Device Hub 檢視 iPhone 18 Pro 的實際圖片與介面；本次新增的大量圖片索引尚未逐張檢視。iPad、VoiceOver、影片及收藏跨啟動尚未完成端到端驗證。
- 此環境的巢狀編譯器 sandbox 無法啟動巨集外掛；驗證指令額外使用 `OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'`。此設定僅用於本次命令，沒有寫入專案；一般 Xcode 執行不需加入。
