import SwiftUI

struct OrderView: View {
    @EnvironmentObject private var model: OrderStore
    @State private var editingStore: StoreOrder?
    @State private var showAddProduct = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if let store = model.selectedStore {
                    metrics(store)
                    storeCard(store)
                    ForEach(store.usedProducts) { product in productCard(product, store: store) }
                    Button { showAddProduct = true } label: {
                        Label("Добави продукт", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity).padding(13)
                    }
                    .buttonStyle(.borderedProminent).tint(IVEXTheme.green)
                }
                Button(role: .destructive) { model.completeShopping() } label: {
                    Label("Приключи текущото пазаруване", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity).padding(10)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(IVEXTheme.softGreen)
        .navigationTitle("IVEX07 ORDER")
        .sheet(isPresented: $showAddProduct) {
            if let store = model.selectedStore { ProductEditor(store: store) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Нова поръчка").font(.title2).bold().foregroundStyle(.white)
            Text("Поръчки и доставки от Китай").font(.subheadline).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(LinearGradient(colors: [IVEXTheme.navySoft, IVEXTheme.navy], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
    }

    private func metrics(_ store: StoreOrder) -> some View {
        HStack(spacing: 8) {
            MetricCard(icon: "storefront", title: "МАГАЗИНИ", value: "\(model.stores.count)", color: IVEXTheme.green)
            MetricCard(icon: "shippingbox", title: "ПРОДУКТИ", value: "\(model.stores.reduce(0) { $0 + $1.usedProducts.count })", color: .blue)
            MetricCard(icon: "yensign", title: "RMB", value: String(format: "%.0f", model.stores.reduce(0) { $0 + $1.totalPrice }), color: .green)
            MetricCard(icon: "cube", title: "CBM", value: String(format: "%.2f", model.stores.reduce(0) { $0 + $1.totalCBM }), color: .purple)
        }
    }

    private func storeCard(_ store: StoreOrder) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(store.name).font(.headline)
                Text("Поръчка \(store.orderNumber)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(model.stores) { item in Button(item.name) { model.select(item.id) } }
                Button("Добави магазин") { model.addStore() }
            } label: { Image(systemName: "chevron.down.circle.fill").font(.title2) }
        }
        .padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func productCard(_ product: ProductLine, store: StoreOrder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(product.name).font(.headline); Spacer(); Text(product.status.rawValue).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Text("\(product.totalQuantity, specifier: "%.0f") бр.")
                Spacer(); Text("\(product.totalPrice, specifier: "%.2f") RMB")
                Spacer(); Text("\(product.totalCBM, specifier: "%.3f") m³")
            }.font(.subheadline).bold()
        }
        .padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ProductEditor: View {
    @EnvironmentObject private var model: OrderStore
    @Environment(\.dismiss) private var dismiss
    @State var store: StoreOrder
    @State private var product = ProductLine()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Продукт", text: $product.name)
                TextField("Кашони", value: $product.cartons, format: .number).keyboardType(.decimalPad)
                TextField("Бройки в кашон", value: $product.piecesPerCarton, format: .number).keyboardType(.decimalPad)
                TextField("Единична цена RMB", value: $product.unitPrice, format: .number).keyboardType(.decimalPad)
                TextField("Кубици на кашон", value: $product.cbmPerCarton, format: .number).keyboardType(.decimalPad)
                TextField("Бележка", text: $product.note, axis: .vertical)
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
    }
}
