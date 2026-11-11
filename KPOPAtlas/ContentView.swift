import SwiftUI

struct ContentView: View {
    @State private var catalog = Catalog()
    @AppStorage("atlas.appearance") private var appearance = "system"
    var body: some View {
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
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .overlay {
            if let error = catalog.loadError {
                ContentUnavailableView("資料載入失敗", systemImage: "exclamationmark.triangle", description: Text(error))
                    .background(.background)
            }
        }
    }
}

#Preview("iPhone") { ContentView() }
#Preview("深色模式") { ContentView().preferredColorScheme(.dark) }
