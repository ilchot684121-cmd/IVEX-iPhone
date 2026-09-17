import SwiftUI

private enum IVEXTab: String, CaseIterable, Identifiable {
    case order = "Поръчка"
    case stores = "Магазини"
    case history = "История"
    case files = "Файлове"
    case about = "За нас"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .order: return "shippingbox.fill"
        case .stores: return "storefront.fill"
        case .history: return "clock.arrow.circlepath"
        case .files: return "building.columns.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: OrderStore
    @State private var selectedTab: IVEXTab = .order

    var body: some View {
        Group {
            if model.profile.isComplete {
                mainInterface
            } else {
                ProfileView(isFirstLaunch: true)
            }
        }
        .background(IVEXTheme.appBackground.ignoresSafeArea())
    }

    private var mainInterface: some View {
        VStack(spacing: 0) {
            IVEXBrandHeader()
            Group {
                switch selectedTab {
                case .order: OrderView()
                case .stores: StoresView(onOpenStore: { selectedTab = .order })
                case .history: HistoryView()
                case .files: ExcelView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IVEXTheme.appBackground)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(IVEXTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(selectedTab == tab ? IVEXTheme.greenDark : IVEXTheme.slate)
                        .frame(maxWidth: .infinity)
                        .frame(height: 65)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .background(IVEXTheme.softGreen)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(IVEXTheme.border)
                    .frame(height: 0.5)
            }
        }
    }
}
