import SwiftUI
import PhotosUI

struct OrderView: View {
    @EnvironmentObject private var model: OrderStore
    var onOpenStores: () -> Void = {}
    @State private var showSendConfirmation = false
    @State private var sendError = ""
    @State private var showBusinessCardScanner = false
    @State private var storeToRename: StoreOrder?
    @State private var renameText = ""
    @State private var showWechatQR = false
    @State private var showDeleteStoreConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                dashboard
                if let store = model.selectedStore {
                    storeCard(store)
                    businessCardSection(store)
                    ForEach(Array(store.products.enumerated()), id: \.element.id) { index, product in
                        InlineProductCard(number: index + 1, product: product, storeID: store.id)
                    }
                    IVEXPrimaryButton(title: "ДОБАВИ ПРОДУКТ", icon: "plus", action: { model.addProduct(to: store.id) })
                    IVEXPrimaryButton(title: "МОИТЕ МАГАЗИНИ", icon: "storefront.fill", color: IVEXTheme.blue, action: onOpenStores)
                    IVEXPrimaryButton(title: "МОЯТ WECHAT QR", icon: "qrcode", color: IVEXTheme.green) {
                        showWechatQR = true
                    }
                    Button { model.saveNow() } label: {
                        Label("Запази сега", systemImage: "checkmark.icloud.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(IVEXTheme.slate)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .overlay(Capsule().stroke(IVEXTheme.border, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    Button { showDeleteStoreConfirmation = true } label: {
                        Label("Изтрий \(store.name)", systemImage: "trash.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(IVEXTheme.red)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .overlay(Capsule().stroke(IVEXTheme.border, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    Label("Автоматично запазване", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(IVEXTheme.green)
                }
                if !model.syncMessage.isEmpty {
                    Label(model.syncMessage, systemImage: model.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(IVEXTheme.greenDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                IVEXPrimaryButton(
                    title: model.isSyncing ? "ИЗПРАЩАНЕ..." : "ИЗПРАТИ И ПРИКЛЮЧИ",
                    icon: "icloud.and.arrow.up.fill",
                    color: IVEXTheme.navy,
                    disabled: model.isSyncing || model.stores.allSatisfy { $0.usedProducts.isEmpty },
                    action: { showSendConfirmation = true }
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(IVEXTheme.appBackground)
        .fullScreenCover(isPresented: $showBusinessCardScanner) {
            BusinessCardScanner { imageData in
                guard var store = model.selectedStore else { return }
                store.businessCardData = imageData
                model.updateStore(store)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showWechatQR) {
            WeChatQRView(data: model.settings.wechatQRData)
        }
        .confirmationDialog("Да изпратя ли поръчката към IVEX Office?", isPresented: $showSendConfirmation) {
            Button("Изпрати поръчката") {
                Task {
                    do { try await model.sendAndCompleteShopping() }
                    catch { sendError = error.localizedDescription }
                }
            }
            Button("Отказ", role: .cancel) {}
        } message: {
            Text("След успешно изпращане поръчката ще се премести в История.")
        }
        .confirmationDialog("Да изтрия ли текущия магазин?", isPresented: $showDeleteStoreConfirmation) {
            if let store = model.selectedStore {
                Button("Изтрий \(store.name)", role: .destructive) { model.deleteStore(store.id) }
            }
            Button("Отказ", role: .cancel) {}
        }
        .alert("Поръчката не е изпратена", isPresented: Binding(
            get: { !sendError.isEmpty },
            set: { if !$0 { sendError = "" } }
        )) { Button("Добре", role: .cancel) {} } message: { Text(sendError) }
        .alert("Преименувай магазин", isPresented: Binding(
            get: { storeToRename != nil },
            set: { if !$0 { storeToRename = nil } }
        )) {
            TextField("Име на магазина", text: $renameText)
            Button("Запази") {
                if let store = storeToRename { model.renameStore(store.id, to: renameText) }
                storeToRename = nil
            }
            Button("Отказ", role: .cancel) { storeToRename = nil }
        }
    }

    private var usedStores: [StoreOrder] {
        model.stores.filter { !$0.usedProducts.isEmpty }
    }

    private var totalProducts: Int {
        model.stores.reduce(0) { $0 + $1.usedProducts.count }
    }

    private var totalPrice: Double {
        model.stores.reduce(0) { $0 + $1.totalPrice }
    }

    private var totalCBM: Double {
        model.stores.reduce(0) { $0 + $1.totalCBM }
    }

    private var sentStores: Int {
        usedStores.filter(\.sentToSupplier).count
    }

    private var progress: Double {
        guard !usedStores.isEmpty else { return 0 }
        return Double(sentStores) / Double(usedStores.count)
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("IVEX")
                    .foregroundStyle(.white)
                Text("07")
                    .foregroundStyle(Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255))
            }
            .font(.system(size: 42, weight: .black, design: .rounded))
            .tracking(1)

            Text("PROFESSIONAL BUYING SYSTEM")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.1)
                .foregroundStyle(Color(red: 215 / 255, green: 227 / 255, blue: 236 / 255))
                .padding(.top, 2)

            HStack(spacing: 8) {
                PremiumMetric(icon: "storefront.fill", label: "МАГАЗИНИ", value: "\(usedStores.count)", subtitle: "използвани", accent: IVEXTheme.green)
                PremiumMetric(icon: "shippingbox.fill", label: "ПРОДУКТИ", value: "\(totalProducts)", subtitle: "общо", accent: IVEXTheme.blue)
            }
            .padding(.top, 22)

            HStack(spacing: 8) {
                PremiumMetric(icon: "yensign", label: "RMB", value: String(format: "%.0f", totalPrice), subtitle: "общо", accent: .green)
                PremiumMetric(icon: "eurosign", label: "EUR", value: String(format: "%.2f", totalPrice / 8.40), subtitle: "общо", accent: .teal)
                PremiumMetric(icon: "shippingbox", label: "CBM", value: String(format: "%.2f", totalCBM), subtitle: "общо", accent: IVEXTheme.violet)
            }
            .padding(.top, 10)

            Divider()
                .overlay(.white.opacity(0.16))
                .padding(.top, 20)

            HStack {
                Text("ПРОГРЕС")
                Spacer()
                Text("\(sentStores) / \(usedStores.count) магазина")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.top, 14)

            ProgressView(value: progress)
                .tint(Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255))
                .scaleEffect(x: 1, y: 1.8, anchor: .center)
                .padding(.vertical, 10)

            Text("\(Int(progress * 100))% изпратени")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 74 / 255, green: 222 / 255, blue: 128 / 255))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(IVEXTheme.navy)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: IVEXTheme.navy.opacity(0.2), radius: 6, y: 3)
    }

    private func PremiumMetric(icon: String, label: String, value: String, subtitle: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.16))
                .clipShape(Circle())
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 215 / 255, green: 227 / 255, blue: 236 / 255))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(Color(red: 185 / 255, green: 200 / 255, blue: 214 / 255))
        }
        .frame(maxWidth: .infinity)
    }

    private func storeCard(_ store: StoreOrder) -> some View {
        IVEXCard {
            VStack(spacing: 13) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(store.usedProducts.isEmpty ? IVEXTheme.red : IVEXTheme.amber)
                        .frame(width: 11, height: 11)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.name)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(IVEXTheme.greenDark)
                        Text("\(store.usedProducts.count) продукта  •  \(String(format: "%.0f", store.usedProducts.reduce(0.0) { $0 + $1.cartons })) кашона")
                            .font(.caption)
                            .foregroundStyle(IVEXTheme.slate)
                    }
                    Spacer()
                    Button {
                        renameText = store.name
                        storeToRename = store
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(IVEXTheme.slate)
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    Menu {
                        ForEach(model.stores) { item in
                            Button(item.name) { model.select(item.id) }
                        }
                        Divider()
                        Button("Добави магазин", systemImage: "plus") { model.addStore() }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "storefront.fill")
                            Text("\(store.number)").fontWeight(.bold)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(IVEXTheme.navySoft)
                        .padding(.horizontal, 15)
                        .frame(height: 44)
                        .background(.white)
                        .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Номер на поръчка")
                        .font(.caption)
                        .foregroundStyle(IVEXTheme.slate)
                    Text(store.orderNumber)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(IVEXTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(IVEXTheme.softGreen.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(IVEXTheme.border)
                        }
                }

                DepositEditor(store: store)
            }
        }
    }

    private func businessCardSection(_ store: StoreOrder) -> some View {
        IVEXCard {
            VStack(spacing: 12) {
                Button {
                    showBusinessCardScanner = true
                } label: {
                    Label(
                        store.businessCardData == nil ? "СКАНИРАЙ ВИЗИТКА" : "СКАНИРАЙ ОТНОВО",
                        systemImage: "doc.viewfinder"
                    )
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(IVEXTheme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if let data = store.businessCardData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(IVEXTheme.border)
                        }

                    HStack {
                        Label("Визитката е запазена", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(IVEXTheme.greenDark)
                        Spacer()
                        Button("Изтрий", role: .destructive) {
                            var updated = store
                            updated.businessCardData = nil
                            model.updateStore(updated)
                        }
                        .font(.footnote.weight(.bold))
                    }
                }
            }
        }
    }

    private func productCard(_ product: ProductLine, store: StoreOrder) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 12) {
                if let data = product.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(IVEXTheme.slate)
                        .frame(width: 76, height: 76)
                        .background(IVEXTheme.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(product.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(IVEXTheme.navy)
                    Text(product.status.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(IVEXTheme.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(IVEXTheme.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 7) {
                ProductMetric(value: String(format: "%.0f", product.totalQuantity), label: "бройки")
                ProductMetric(value: String(format: "%.2f", product.totalPrice), label: "RMB")
                ProductMetric(value: String(format: "%.3f", product.totalCBM), label: "CBM")
            }
        }
        .padding(15)
        .background(IVEXTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(IVEXTheme.border)
        }
        .shadow(color: IVEXTheme.navy.opacity(0.07), radius: 2, y: 1)
        .contextMenu {
            Button("Изтрий продукта", systemImage: "trash", role: .destructive) {
                model.deleteProduct(product.id, from: store.id)
            }
        }
    }

    private func ProductMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(IVEXTheme.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(IVEXTheme.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(IVEXTheme.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct WeChatQRView: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(22)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: IVEXTheme.navy.opacity(0.15), radius: 8, y: 3)
                } else {
                    ContentUnavailableView(
                        "Няма избран WeChat QR",
                        systemImage: "qrcode",
                        description: Text("Добави снимката от За нас → Моят WeChat QR.")
                    )
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IVEXTheme.appBackground)
            .navigationTitle("Моят WeChat QR")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}

private struct DepositEditor: View {
    @EnvironmentObject private var model: OrderStore
    let store: StoreOrder
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Платено капаро (RMB)", text: $text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(IVEXTheme.border)
                }
                .onChange(of: text) { _, value in
                    let normalized = value.replacingOccurrences(of: ",", with: ".")
                    model.updateDeposit(Double(normalized) ?? 0, for: store.id)
                }
            Text("Остатък: \(store.remainingRmb, specifier: "%.2f") RMB от общо \(store.totalPrice, specifier: "%.2f") RMB")
                .font(.caption)
                .foregroundStyle(IVEXTheme.slate)
        }
        .onAppear {
            text = store.depositRmb > 0 ? String(format: "%.2f", store.depositRmb) : ""
        }
        .onChange(of: store.depositRmb) { _, value in
            let parsed = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
            if abs(parsed - value) > 0.001 {
                text = value > 0 ? String(format: "%.2f", value) : ""
            }
        }
    }
}

private struct InlineProductCard: View {
    @EnvironmentObject private var model: OrderStore
    let number: Int
    let storeID: UUID
    @State private var product: ProductLine
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    init(number: Int, product: ProductLine, storeID: UUID) {
        self.number = number
        self.storeID = storeID
        _product = State(initialValue: product)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(IVEXTheme.navy)
                    .clipShape(Circle())
                Text("Продукт \(number)")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(IVEXTheme.text)
                Spacer()
                Button(role: .destructive) {
                    model.deleteProduct(product.id, from: storeID)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(IVEXTheme.red)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
            }

            AndroidField(placeholder: "Име / 品名", text: $product.name)

            HStack(spacing: 10) {
                AndroidNumberField(title: "Кашони", value: $product.cartons)
                AndroidNumberField(title: "Бр./кашон", value: $product.piecesPerCarton)
            }
            HStack(spacing: 10) {
                AndroidNumberField(title: "Цена RMB", value: $product.unitPrice)
                AndroidNumberField(title: "CBM/кашон", value: $product.cbmPerCarton)
            }

            AndroidField(placeholder: "Бележка / 备注", text: $product.note)

            HStack(spacing: 12) {
                Group {
                    if let data = product.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(IVEXTheme.slate)
                    }
                }
                .frame(width: 105, height: 112)
                .background(IVEXTheme.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipped()

                VStack(spacing: 10) {
                    Button { showCamera = true } label: {
                        Label("СНИМАЙ", systemImage: "camera.fill")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(IVEXTheme.navySoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("ОТ ГАЛЕРИЯТА", systemImage: "photo.on.rectangle.angled")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(IVEXTheme.greenDark)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(.white)
                            .overlay(Capsule().stroke(IVEXTheme.border, lineWidth: 1.5))
                            .clipShape(Capsule())
                    }
                }
            }

            Text("€ \(product.totalPrice / model.settings.eurExchangeRate, specifier: "%.2f")")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(IVEXTheme.greenDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(IVEXTheme.softGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(17)
        .background(IVEXTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(IVEXTheme.border, lineWidth: 1.2))
        .shadow(color: IVEXTheme.navy.opacity(0.1), radius: 3, y: 2)
        .onChange(of: product) { _, value in model.updateProduct(value, in: storeID) }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    product.photoData = data
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { image in product.photoData = image.jpegData(compressionQuality: 0.88) }
                .ignoresSafeArea()
        }
    }
}

private struct AndroidField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.system(size: 17))
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(IVEXTheme.border, lineWidth: 1.2))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct AndroidNumberField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(IVEXTheme.slate)
            TextField(title, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 17))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity).frame(height: 66)
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(IVEXTheme.border, lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct ProductEditor: View {
    @EnvironmentObject private var model: OrderStore
    @Environment(\.dismiss) private var dismiss
    @State var store: StoreOrder
    @State private var product = ProductLine()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("СНИМАЙ", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IVEXTheme.navySoft)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("ОТ ГАЛЕРИЯТА", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(IVEXTheme.greenDark)
                }
                if let data = product.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                }
                TextField("Продукт", text: $product.name)
                TextField("Кашони", value: $product.cartons, format: .number).keyboardType(.decimalPad)
                TextField("Бройки в кашон", value: $product.piecesPerCarton, format: .number).keyboardType(.decimalPad)
                TextField("Единична цена RMB", value: $product.unitPrice, format: .number).keyboardType(.decimalPad)
                TextField("Кубици на кашон", value: $product.cbmPerCarton, format: .number).keyboardType(.decimalPad)
                TextField("Бележка", text: $product.note, axis: .vertical)
                Picker("Статус", selection: $product.status) {
                    ForEach(ProductStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Section("Общо") {
                    Text("Количество: \(product.totalQuantity, specifier: "%.0f")")
                    Text("Цена: \(product.totalPrice, specifier: "%.2f") RMB")
                    Text("Обем: \(product.totalCBM, specifier: "%.3f") m³")
                }
            }
            .navigationTitle("Нов продукт")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отказ") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Запази") { store.products.append(product); model.updateStore(store); dismiss() }
                        .disabled(product.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task { product.photoData = try? await newValue?.loadTransferable(type: Data.self) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { image in
                product.photoData = image.jpegData(compressionQuality: 0.88)
            }
            .ignoresSafeArea()
        }
    }
}
