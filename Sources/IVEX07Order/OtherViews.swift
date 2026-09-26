import SwiftUI
import UIKit
import PhotosUI

struct StoresView: View {
    @EnvironmentObject private var model: OrderStore
    var onOpenStore: () -> Void = {}

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                storesHeader

                HStack(alignment: .firstTextBaseline) {
                    Text("Всички магазини")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(IVEXTheme.navy)
                    Spacer()
                    Text("Натисни карта, за да отвориш")
                        .font(.caption2)
                        .foregroundStyle(IVEXTheme.slate)
                }
                .padding(.horizontal, 16)
                .padding(.top, 3)

                ForEach(model.stores) { store in
                    Button {
                        model.select(store.id)
                        onOpenStore()
                    } label: {
                        storeCard(store)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Изтрий магазина", systemImage: "trash", role: .destructive) {
                            model.deleteStore(store.id)
                        }
                    }
                }

                IVEXPrimaryButton(title: "ДОБАВИ НОВ МАГАЗИН", icon: "storefront.fill.badge.plus") {
                    model.addStore()
                    onOpenStore()
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
            }
            .padding(.bottom, 28)
        }
        .background(IVEXTheme.appBackground)
    }

    private var usedStores: [StoreOrder] {
        model.stores.filter { !$0.usedProducts.isEmpty }
    }

    private var sentStores: Int {
        usedStores.filter(\.sentToSupplier).count
    }

    private var storesHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("МОИТЕ МАГАЗИНИ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.72))
                    Text("Покупна сесия")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Spacer()
                Label("\(usedStores.count)", systemImage: "storefront.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 10) {
                HeaderMetric(label: "ПРОДУКТИ", value: "\(usedStores.reduce(0) { $0 + $1.usedProducts.count })")
                HeaderMetric(label: "ОБЩО RMB", value: String(format: "%.2f", usedStores.reduce(0) { $0 + $1.totalPrice }))
                HeaderMetric(label: "ОБЩО CBM", value: String(format: "%.4f", usedStores.reduce(0) { $0 + $1.totalCBM }))
            }
            .padding(.top, 20)

            HStack {
                Text("Изпратени")
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text("\(sentStores) / \(usedStores.count)")
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .font(.system(size: 12))
            .padding(.top, 17)

            ProgressView(value: usedStores.isEmpty ? 0 : Double(sentStores) / Double(usedStores.count))
                .tint(IVEXTheme.green)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .padding(.top, 7)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 21)
        .background(
            LinearGradient(colors: [IVEXTheme.navySoft, IVEXTheme.navy], startPoint: .top, endPoint: .bottom)
        )
    }

    private func HeaderMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func storeCard(_ store: StoreOrder) -> some View {
        let isEmpty = store.usedProducts.isEmpty
        let statusColor = store.sentToSupplier ? IVEXTheme.green : (isEmpty ? IVEXTheme.red : IVEXTheme.amber)
        let status = store.sentToSupplier ? "ИЗПРАТЕН" : (isEmpty ? "ПРАЗЕН" : "В РАБОТА")
        let cartons = store.usedProducts.reduce(0.0) { $0 + $1.cartons }

        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 44, height: 44)
                    .background(statusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(IVEXTheme.navy)
                    HStack(spacing: 6) {
                        Circle().fill(statusColor).frame(width: 7, height: 7)
                        Text(status)
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(statusColor)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(IVEXTheme.navy.opacity(0.42))
            }

            if isEmpty {
                IVEXEmptyCard(text: "Няма добавени продукти")
            } else {
                Divider().overlay(IVEXTheme.border)
                HStack(spacing: 6) {
                    StoreMetric(value: "\(store.usedProducts.count)", label: "Продукти")
                    StoreMetric(value: String(format: "%.0f", cartons), label: "Кашони")
                    StoreMetric(value: String(format: "%.2f", store.totalPrice), label: "RMB")
                    StoreMetric(value: String(format: "%.4f", store.totalCBM), label: "CBM")
                }
            }
        }
        .padding(15)
        .background(IVEXTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(store.sentToSupplier ? IVEXTheme.green.opacity(0.35) : IVEXTheme.border)
        }
        .shadow(color: IVEXTheme.navy.opacity(0.09), radius: 3, y: 2)
        .padding(.horizontal, 14)
    }

    private func StoreMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(IVEXTheme.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(IVEXTheme.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryYearGroup: Identifiable {
    let year: String
    let stores: [StoreOrder]
    var id: String { year }
}

private struct HistoryPeriodGroup: Identifiable {
    let key: String
    let title: String
    let stores: [StoreOrder]
    var id: String { key }
}

struct HistoryView: View {
    @EnvironmentObject private var model: OrderStore
    @State private var query = ""
    @State private var expandedYears: Set<String> = []
    @State private var expandedPeriods: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("История")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(IVEXTheme.text)
                    Text("Старите магазини, продукти, снимки и визитки остават запазени")
                        .font(.system(size: 15))
                        .foregroundStyle(IVEXTheme.slate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(IVEXTheme.slate)
                    TextField("Търси продукт, магазин или поръчка", text: $query)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 17)
                .frame(height: 62)
                .background(IVEXTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(IVEXTheme.border)
                }

                Text("Отвори стар магазин и натисни „Поръчай отново“, за да го заредиш в текущата поръчка. После можеш да редактираш, добавяш или изтриваш продукти.")
                    .font(.system(size: 13))
                    .foregroundStyle(IVEXTheme.slate)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if filteredHistory.isEmpty {
                    IVEXEmptyCard(text: query.isEmpty ? "Все още няма запазени магазини" : "Няма намерени резултати")
                } else {
                    ForEach(historyByYear) { yearGroup in
                        let yearOpen = expandedYears.contains(yearGroup.year) || !query.isEmpty
                        FolderRow(
                            title: yearGroup.year,
                            subtitle: "\(yearGroup.stores.count) магазина",
                            expanded: yearOpen,
                            level: 0,
                            purple: false
                        ) {
                            toggleYear(yearGroup.year)
                        }

                        if yearOpen {
                            ForEach(periods(in: yearGroup.stores)) { period in
                                let periodOpen = expandedPeriods.contains(period.key) || !query.isEmpty
                                FolderRow(
                                    title: "Пазаруване \(period.title)",
                                    subtitle: "\(period.stores.count) магазина",
                                    expanded: periodOpen,
                                    level: 1,
                                    purple: true
                                ) {
                                    togglePeriod(period.key)
                                }

                                if periodOpen {
                                    ForEach(period.stores) { store in
                                        HistoryStoreCard(store: store)
                                            .padding(.leading, 18)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(IVEXTheme.appBackground)
        .onAppear {
            if expandedYears.isEmpty, let first = historyByYear.first?.year {
                expandedYears.insert(first)
            }
        }
    }

    private var filteredHistory: [StoreOrder] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return model.history }
        return model.history.filter { store in
            store.name.localizedCaseInsensitiveContains(clean) ||
            store.orderNumber.localizedCaseInsensitiveContains(clean) ||
            store.usedProducts.contains { $0.name.localizedCaseInsensitiveContains(clean) }
        }
    }

    private var historyByYear: [HistoryYearGroup] {
        let grouped = Dictionary(grouping: filteredHistory) { store in
            yearString(store.completedAt ?? .distantPast)
        }
        return grouped.map { HistoryYearGroup(year: $0.key, stores: $0.value) }
            .sorted { $0.year > $1.year }
    }

    private func periods(in stores: [StoreOrder]) -> [HistoryPeriodGroup] {
        let grouped = Dictionary(grouping: stores) { store in
            periodKey(store.completedAt ?? .distantPast)
        }
        return grouped.map { key, items in
            let date = items.compactMap(\.completedAt).max() ?? .distantPast
            return HistoryPeriodGroup(key: key, title: periodTitle(date), stores: items)
        }
        .sorted { $0.key > $1.key }
    }

    private func toggleYear(_ key: String) {
        if expandedYears.contains(key) { expandedYears.remove(key) } else { expandedYears.insert(key) }
    }

    private func togglePeriod(_ key: String) {
        if expandedPeriods.contains(key) { expandedPeriods.remove(key) } else { expandedPeriods.insert(key) }
    }

    private func FolderRow(title: String, subtitle: String, expanded: Bool, level: Int, purple: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: expanded ? "folder.fill.badge.minus" : "folder.fill")
                    .font(.system(size: level == 0 ? 27 : 23, weight: .semibold))
                    .foregroundStyle(purple ? IVEXTheme.violet : IVEXTheme.greenDark)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: level == 0 ? 18 : 15, weight: .heavy))
                        .foregroundStyle(IVEXTheme.navy)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(IVEXTheme.slate)
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(IVEXTheme.slate)
            }
            .padding(.horizontal, 15)
            .frame(minHeight: level == 0 ? 76 : 68)
            .background(purple ? IVEXTheme.violetSoft : (level == 0 ? Color(red: 231 / 255, green: 248 / 255, blue: 237 / 255) : IVEXTheme.cardBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: IVEXTheme.navy.opacity(0.07), radius: 2, y: 1)
            .padding(.leading, level == 0 ? 0 : 14)
        }
        .buttonStyle(.plain)
    }

    private func HistoryStoreCard(store: StoreOrder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.name)
                    .font(.headline)
                    .foregroundStyle(IVEXTheme.navy)
                Spacer()
                Text(store.orderStatus.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(IVEXTheme.greenDark)
            }
            Text("Поръчка \(store.orderNumber) • \(store.usedProducts.count) продукта • \(String(format: "%.3f", store.totalCBM)) m³")
                .font(.caption)
                .foregroundStyle(IVEXTheme.slate)
            Text("Общо \(store.totalPrice, specifier: "%.2f") RMB • Капаро \(store.depositRmb, specifier: "%.2f") RMB • Остатък \(store.remainingRmb, specifier: "%.2f") RMB")
                .font(.caption.weight(.semibold))
                .foregroundStyle(IVEXTheme.slate)

            if let data = store.businessCardData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ForEach(store.usedProducts) { product in
                HStack(spacing: 9) {
                    if let data = product.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(.subheadline.weight(.bold))
                        Text("\(product.totalQuantity, specifier: "%.0f") бр. • \(product.totalPrice, specifier: "%.2f") RMB • \(product.status.rawValue)")
                            .font(.caption2)
                            .foregroundStyle(IVEXTheme.slate)
                    }
                }
            }
            Button {
                model.reorder(store)
            } label: {
                Label("Поръчай отново", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(IVEXTheme.greenDark)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(IVEXTheme.softGreen)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(IVEXTheme.border)
        }
    }

    private func yearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }

    private func periodKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: date)
    }

    private func periodTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }
}

struct ExcelView: View {
    @EnvironmentObject private var model: OrderStore
    @State private var currentStoreURL: URL?
    @State private var allStoresURL: URL?
    @State private var sendError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text("Офис и Excel")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(IVEXTheme.text)

                Text("Изпрати истински Excel файл със снимките на продуктите и визитката към търговеца или IVEX07 Office.")
                    .font(.system(size: 16))
                    .foregroundStyle(IVEXTheme.slate)

                CloudConnectionCard()

                IVEXCard {
                    VStack(alignment: .leading, spacing: 0) {
                        IVEXSectionTitle(icon: "building.columns.fill", title: "ОБОБЩЕНИЕ")
                        IVEXReportRow(label: "Запазени магазини", value: "\(model.stores.count)")
                        IVEXReportRow(label: "Обща стойност", value: String(format: "%.2f RMB", totalPrice))
                        IVEXReportRow(label: "Общ обем", value: String(format: "%.4f CBM", totalCBM))
                        IVEXReportRow(label: "Текущ магазин", value: "\(model.selectedStore?.number ?? 1)")
                    }
                }

                if let currentStoreURL {
                    ShareLink(item: currentStoreURL) {
                        Label("ИЗПРАТИ МАГАЗИН \(model.selectedStore?.number ?? 1)", systemImage: "square.and.arrow.up.fill")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .background(IVEXTheme.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: IVEXTheme.green.opacity(0.18), radius: 3, y: 2)
                    }
                } else {
                    IVEXPrimaryButton(title: "СЪЗДАЙ ФАЙЛ ЗА ТЕКУЩИЯ МАГАЗИН", icon: "doc.badge.plus") {
                        currentStoreURL = model.selectedStore.flatMap { model.xlsxURL(for: $0) }
                    }
                }

                if let allStoresURL {
                    ShareLink(item: allStoresURL) {
                        Label("СПОДЕЛИ ОБЩИЯ EXCEL ФАЙЛ", systemImage: "square.and.arrow.up.fill")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .background(IVEXTheme.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                } else {
                    IVEXPrimaryButton(title: "СЪЗДАЙ ОБЩ ФАЙЛ ЗА ОФИСА", icon: "building.2.crop.circle") {
                        allStoresURL = model.xlsxURL()
                    }
                }

                IVEXPrimaryButton(
                    title: model.isSyncing ? "ИЗПРАЩАНЕ..." : "ИЗПРАТИ ПОРЪЧКИТЕ КЪМ ОФИСА",
                    icon: "icloud.and.arrow.up.fill",
                    color: IVEXTheme.blue,
                    disabled: model.isSyncing || model.stores.allSatisfy { $0.usedProducts.isEmpty }
                ) {
                    Task {
                        do { try await model.sendAndCompleteShopping() }
                        catch { sendError = error.localizedDescription }
                    }
                }

                Text("Един магазин изпраща само избрания магазин. Общият файл включва всички магазини, продуктови снимки, визитки и обобщение.")
                    .font(.system(size: 13))
                    .foregroundStyle(IVEXTheme.slate)
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 34)
        }
        .background(IVEXTheme.appBackground)
        .task { await model.checkCloudConnection() }
        .alert("Поръчката не е изпратена", isPresented: Binding(
            get: { !sendError.isEmpty },
            set: { if !$0 { sendError = "" } }
        )) { Button("Добре", role: .cancel) {} } message: { Text(sendError) }
    }

    private var totalPrice: Double {
        model.stores.reduce(0) { $0 + $1.totalPrice }
    }

    private var totalCBM: Double {
        model.stores.reduce(0) { $0 + $1.totalCBM }
    }
}

private struct CloudConnectionCard: View {
    @EnvironmentObject private var model: OrderStore

    private var color: Color {
        switch model.cloudConnectionState {
        case .checking: return .orange
        case .connected: return IVEXTheme.green
        case .disconnected: return IVEXTheme.red
        }
    }

    private var title: String {
        switch model.cloudConnectionState {
        case .checking: return "ПРОВЕРКА НА ВРЪЗКАТА"
        case .connected: return "СВЪРЗАН С IVEX OFFICE"
        case .disconnected: return "НЯМА ВРЪЗКА С ОФИСА"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.cloudConnectionState == .connected ? "checkmark.icloud.fill" : "icloud.slash.fill")
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.weight(.heavy)).foregroundStyle(color)
                Text(model.syncMessage).font(.caption).foregroundStyle(IVEXTheme.slate)
                if let date = model.lastCloudContact {
                    Text("Последен успешен контакт: \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(IVEXTheme.slate)
                }
            }
            Spacer()
            Button { Task { await model.checkCloudConnection() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.isSyncing)
        }
        .padding(15)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AboutView: View {
    var body: some View {
        ProfileView(isFirstLaunch: false)
    }
}

struct ProfileView: View {
    @EnvironmentObject private var model: OrderStore
    @State private var profile = ClientProfile()
    @State private var settings = AppSettings()
    @State private var selectedWechatQR: PhotosPickerItem?
    @State private var showClearHistory = false
    @State private var showFinishShopping = false
    @State private var showFactoryReset = false
    @State private var confirmationText = ""
    let isFirstLaunch: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isFirstLaunch {
                IVEXBrandHeader()
            }
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        Image("IVEXLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 29, style: .continuous))
                            .shadow(color: IVEXTheme.navy.opacity(0.12), radius: 5, y: 2)
                        Text("IVEX07 ORDER")
                            .font(.system(size: 27, weight: .heavy))
                            .foregroundStyle(IVEXTheme.navy)
                        Text("Professional Purchasing System")
                            .foregroundStyle(IVEXTheme.slate)
                    }

                    IVEXCard {
                        VStack(alignment: .leading, spacing: 0) {
                            IVEXSectionTitle(icon: "info.circle.fill", title: "ЗА ПРИЛОЖЕНИЕТО", color: IVEXTheme.blue)
                            IVEXReportRow(label: "Версия", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.4.1")
                            IVEXReportRow(label: "Последна актуализация", value: "19.09.2026")
                            IVEXReportRow(label: "Магазини", value: "Динамични")
                            IVEXReportRow(label: "Режим", value: "Офлайн база данни + Excel")
                        }
                    }

                    IVEXCard {
                        VStack(alignment: .leading, spacing: 12) {
                            IVEXSectionTitle(icon: "qrcode", title: "МОЯТ WECHAT QR", color: IVEXTheme.green)
                            Text("Избери снимка на своя WeChat QR. Кодът се пази офлайн и може да се показва на търговците.")
                                .font(.system(size: 13))
                                .foregroundStyle(IVEXTheme.slate)
                            if let data = settings.wechatQRData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 260)
                                    .frame(maxWidth: .infinity)
                            }
                            PhotosPicker(selection: $selectedWechatQR, matching: .images) {
                                Label(settings.wechatQRData == nil ? "ИЗБЕРИ QR СНИМКА" : "СМЕНИ QR СНИМКАТА", systemImage: "photo.on.rectangle")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(IVEXTheme.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            }
                        }
                    }

                    IVEXCard {
                        VStack(alignment: .leading, spacing: 12) {
                            IVEXSectionTitle(icon: "calculate", title: "SMART PRICE — RMB КЪМ EUR")
                            Text("Цената в RMB се умножава по този коефициент за приблизителна крайна цена до България.")
                                .font(.system(size: 13))
                                .foregroundStyle(IVEXTheme.slate)
                            TextField("Коефициент", value: $settings.smartPriceCoefficient, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            Text("Пример: 10.00 RMB → \(10 * settings.smartPriceCoefficient, specifier: "%.2f") €")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(IVEXTheme.greenDark)

                            Divider()

                            IVEXSectionTitle(icon: "eurosign.arrow.circlepath", title: "ВАЛУТЕН КУРС — EUR", color: IVEXTheme.blue)
                            TextField("RMB за 1 EUR", value: $settings.eurExchangeRate, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            IVEXPrimaryButton(title: "ЗАПАЗИ НАСТРОЙКИТЕ", icon: "checkmark.circle.fill") {
                                model.updateSettings(settings)
                            }
                        }
                    }

                    IVEXCard {
                        VStack(alignment: .leading, spacing: 12) {
                            IVEXSectionTitle(icon: "gearshape.fill", title: "НАСТРОЙКИ И НУЛИРАНЕ", color: IVEXTheme.red)
                            Button("ПРИКЛЮЧИ ТЕКУЩОТО ПАЗАРУВАНЕ") { confirmationText = ""; showFinishShopping = true }
                                .buttonStyle(IVEXWideButtonStyle(color: IVEXTheme.green))
                            Button("ИЗТРИЙ САМО ИСТОРИЯТА") { showClearHistory = true }
                                .buttonStyle(IVEXWideButtonStyle(color: IVEXTheme.red))
                            Button("ФАБРИЧНО НУЛИРАНЕ") { confirmationText = ""; showFactoryReset = true }
                                .buttonStyle(IVEXWideButtonStyle(color: IVEXTheme.red))
                        }
                    }

                    IVEXCard {
                        VStack(alignment: .leading, spacing: 12) {
                            IVEXSectionTitle(
                                icon: "person.fill",
                                title: isFirstLaunch ? "РЕГИСТРАЦИЯ НА КЛИЕНТА" : "МОЯТ ПРОФИЛ",
                                color: IVEXTheme.blue
                            )

                            StyledField(title: "Име и фамилия", text: $profile.name)
                            StyledField(title: "Фирма", text: $profile.company)
                            StyledField(title: "Телефон", text: $profile.phone, keyboard: .phonePad)
                            StyledField(title: "Имейл", text: $profile.email, keyboard: .emailAddress, autocapitalization: .never)

                            IVEXPrimaryButton(
                                title: isFirstLaunch ? "ЗАПОЧНИ РАБОТА" : "ЗАПАЗИ ПРОМЕНИТЕ",
                                icon: "checkmark.circle.fill",
                                color: IVEXTheme.green,
                                disabled: !profile.isComplete,
                                action: { model.saveProfile(profile) }
                            )

                            CloudConnectionCard()
                        }
                    }

                    IVEXCard {
                        VStack(alignment: .leading, spacing: 9) {
                            IVEXSectionTitle(icon: "checkmark.shield.fill", title: "РАБОТЕЩИ ФУНКЦИИ")
                            Text("Регистрация и изпращане на поръчките към IVEX Office, магазини, продукти със снимки, RMB, кубици, статуси, история и Excel/CSV експорт.")
                                .font(.system(size: 13))
                                .foregroundStyle(IVEXTheme.slate)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .background(IVEXTheme.appBackground)
        .onAppear {
            profile = model.profile
            settings = model.settings
            Task { await model.checkCloudConnection() }
        }
        .onChange(of: selectedWechatQR) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    settings.wechatQRData = data
                    model.updateSettings(settings)
                }
            }
        }
        .confirmationDialog("Изтриване на историята", isPresented: $showClearHistory) {
            Button("Изтрий историята", role: .destructive) { model.clearHistory() }
            Button("Отказ", role: .cancel) {}
        } message: { Text("Текущите магазини няма да бъдат изтрити.") }
        .alert("Приключване на текущото пазаруване", isPresented: $showFinishShopping) {
            TextField("Напиши ПОТВЪРЖДАВАМ", text: $confirmationText)
            Button("Приключи", role: .destructive) {
                if confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "ПОТВЪРЖДАВАМ" {
                    model.completeShopping()
                }
            }
            Button("Отказ", role: .cancel) {}
        } message: { Text("Напиши ПОТВЪРЖДАВАМ, за да продължиш.") }
        .alert("Фабрично нулиране", isPresented: $showFactoryReset) {
            TextField("Напиши ИЗТРИЙ", text: $confirmationText)
            Button("Изтрий всичко", role: .destructive) {
                if confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "ИЗТРИЙ" {
                    model.factoryReset()
                }
            }
            Button("Отказ", role: .cancel) {}
        } message: { Text("Това изтрива профила, магазините, снимките, визитките и историята.") }
    }

    private func StyledField(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization? = .words
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(IVEXTheme.border)
            }
    }
}

private struct IVEXWideButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}
