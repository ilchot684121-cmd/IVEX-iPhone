import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { OrderView() }
                .tabItem { Label("Поръчка", systemImage: "shippingbox") }
            NavigationStack { StoresView() }
                .tabItem { Label("Магазини", systemImage: "storefront") }
            NavigationStack { HistoryView() }
                .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }
            NavigationStack { ExcelView() }
                .tabItem { Label("Excel", systemImage: "tablecells") }
            NavigationStack { AboutView() }
                .tabItem { Label("За IVEX", systemImage: "info.circle") }
        }
        .tint(IVEXTheme.green)
    }
}
