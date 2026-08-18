import SwiftUI

struct StoresView: View {
    @EnvironmentObject private var model: OrderStore
    var body: some View {
        List {
            ForEach(model.stores) { store in
                Button { model.select(store.id) } label: {
                    HStack {
                        Image(systemName: store.sentToSupplier ? "checkmark.circle.fill" : "storefront")
                            .foregroundStyle(store.sentToSupplier ? .green : .orange)
                        VStack(alignment: .leading) {
                            Text(store.name).font(.headline)
                            Text("\(store.usedProducts.count) продукта • \(store.totalCBM, specifier: "%.3f") m³")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.onDelete { offsets in offsets.map { model.stores[$0].id }.forEach(model.deleteStore) }
        }
        .navigationTitle("Магазини")
        .toolbar { Button { model.addStore() } label: { Image(systemName: "plus") } }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: OrderStore
    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView("Историята е празна", systemImage: "clock", description: Text("Приключените магазини ще се пазят тук."))
            } else {
                List(model.history) { store in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.name).font(.headline)
                        Text("Поръчка \(store.orderNumber) • \(store.usedProducts.count) продукта • \(store.totalCBM, specifier: "%.3f") m³").font(.caption)
                        Button("Поръчай отново") { model.reorder(store) }.buttonStyle(.bordered)
                    }.padding(.vertical, 4)
                }
            }
        }.navigationTitle("История")
    }
}

struct ExcelView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "tablecells.fill").font(.system(size: 62)).foregroundStyle(IVEXTheme.green)
            Text("Excel експорт").font(.title2).bold()
            Text("В следващия етап добавяме същия Excel файл като в Android и изпращането към IVEX Office.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
        }.padding().navigationTitle("Excel")
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "cart.fill").font(.system(size: 68)).foregroundStyle(IVEXTheme.green)
                Text("IVEX07 ORDER").font(.largeTitle).bold().foregroundStyle(IVEXTheme.navy)
                Text("Система за поръчки и доставки от Китай").multilineTextAlignment(.center)
                GroupBox("iPhone версия 0.1") {
                    Text("Първи работещ етап: магазини, продукти, количества, RMB, кубици, история и локално запазване.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding()
        }.navigationTitle("За IVEX")
    }
}
