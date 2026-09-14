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
    @EnvironmentObject private var model: OrderStore
    @State private var exportURL: URL?
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "tablecells.fill").font(.system(size: 62)).foregroundStyle(IVEXTheme.green)
            Text("Excel експорт").font(.title2).bold()
            Text("Експортирай всички магазини и изпрати файла към IVEX Office.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Изпрати файла", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.borderedProminent).tint(IVEXTheme.green)
            } else {
                Button("Създай Excel/CSV файл") { exportURL = model.csvURL() }
                    .buttonStyle(.borderedProminent).tint(IVEXTheme.green)
            }
        }.padding().navigationTitle("Excel")
    }
}

struct AboutView: View {
    @EnvironmentObject private var model: OrderStore
    var body: some View {
        ProfileView(isFirstLaunch: false)
    }
}

struct ProfileView: View {
    @EnvironmentObject private var model: OrderStore
    @State private var profile = ClientProfile()
    let isFirstLaunch: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "cart.fill").font(.system(size: 68)).foregroundStyle(IVEXTheme.green)
                Text("IVEX07 ORDER").font(.largeTitle).bold().foregroundStyle(IVEXTheme.navy)
                Text("Система за поръчки и доставки от Китай").multilineTextAlignment(.center)
                GroupBox(isFirstLaunch ? "Регистрация на клиента" : "Моят профил") {
                    VStack(spacing: 12) {
                        TextField("Име и фамилия", text: $profile.name).textFieldStyle(.roundedBorder)
                        TextField("Фирма", text: $profile.company).textFieldStyle(.roundedBorder)
                        TextField("Телефон", text: $profile.phone).textFieldStyle(.roundedBorder).keyboardType(.phonePad)
                        TextField("Имейл", text: $profile.email).textFieldStyle(.roundedBorder).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        Button(isFirstLaunch ? "Започни работа" : "Запази промените") { model.saveProfile(profile) }
                            .buttonStyle(.borderedProminent).tint(IVEXTheme.green)
                            .disabled(!profile.isComplete)
                        if !model.syncMessage.isEmpty {
                            Text(model.syncMessage).font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.top, 8)
                }
                GroupBox("iPhone версия 0.3") {
                    Text("Регистрация и изпращане на поръчките към IVEX Office, магазини, продукти със снимки, RMB, кубици, статуси, история и Excel/CSV експорт.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding()
            }.navigationTitle(isFirstLaunch ? "Добре дошли" : "Профил")
        }.onAppear { profile = model.profile }
    }
}
