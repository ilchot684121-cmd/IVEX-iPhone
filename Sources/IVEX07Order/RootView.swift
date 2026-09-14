import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: OrderStore
    var body: some View {
        Group {
            if model.profile.isComplete {
                mainTabs
            } else {
                ProfileView(isFirstLaunch: true)
            }
        }
    }

    private var mainTabs: some View {
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
                .tabItem { Label("Профил", systemImage: "person.crop.circle") }
        }
        .tint(IVEXTheme.green)
    }
}
