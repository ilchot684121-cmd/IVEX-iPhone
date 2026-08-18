import SwiftUI

@main
struct IVEX07OrderApp: App {
    @StateObject private var store = OrderStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
