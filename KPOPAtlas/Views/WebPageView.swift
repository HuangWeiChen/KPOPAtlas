import SwiftUI
import WebKit

struct WebPageView: View {
    let url: URL
    let title: String
    @State private var page = WebPage()
    @State private var failed = false
    @State private var attempt = 0
    var body: some View {
        ZStack {
            WebView(page).onAppear { page.load(url) }
            if failed {
                ContentUnavailableView {
                    Label("網頁暫時無法載入", systemImage: "wifi.exclamationmark")
                } description: { Text("請檢查網路連線，或用瀏覽器開啟。") } actions: {
                    Button("重試") { failed = false; attempt += 1; page.load(url) }
                    Link("在瀏覽器開啟", destination: url)
                }.background(.background)
            } else if page.isLoading {
                ProgressView("正在載入網頁…").padding().background(.regularMaterial, in: .rect(cornerRadius: 16))
            }
        }
        .task(id: attempt) {
            do {
                for try await _ in page.navigations { }
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("重新載入", systemImage: "arrow.clockwise") { failed = false; attempt += 1; page.load(url) }
                Link(destination: url) { Image(systemName: "safari") }.accessibilityLabel("在瀏覽器開啟")
            }
        }
    }
}
