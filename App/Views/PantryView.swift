import SwiftUI
import UIKit

enum PantrySheet: Identifiable {
    case shelf
    case label
    case search(staple: Bool)
    case edit(PantryItem)

    var id: String {
        switch self {
        case .shelf: return "shelf"
        case .label: return "label"
        case .search(let s): return s ? "search-staple" : "search"
        case .edit(let item): return "edit-\(item.id)"
        }
    }
}

struct PantryView: View {
    @EnvironmentObject var store: AppStore
    @State private var sheet: PantrySheet?
    @State private var scanning = false
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppHeader()
                ScreenTitle(step: "Шаг 2 из 3", title: "Что есть дома",
                            subtitle: "Сканируй штрихкоды, сфоткай полку или этикетку — приложение само найдёт КБЖУ.")
                actions
                placePicker
                products
                staplesSection
                Button {
                    withAnimation(.snappy) { store.tab = .plan }
                } label: {
                    HStack(spacing: 8) { Text("Дальше — рацион"); Image(systemName: "arrow.right") }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $sheet) { s in
            Group {
                switch s {
                case .shelf: ShelfSheet()
                case .label: LabelSheet(code: nil)
                case .search(let staple): SearchSheet(stapleMode: staple)
                case .edit(let item): EditItemSheet(item: item)
                }
            }
            .environmentObject(store)
            .presentationBackground(Theme.bg)
            .presentationCornerRadius(30)
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $scanning) {
            ScanScreen().environmentObject(store).preferredColorScheme(.dark)
        }
        .confirmationDialog("Очистить весь список продуктов?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Очистить", role: .destructive) { withAnimation { store.clearPantry() } }
            Button("Отмена", role: .cancel) {}
        }
    }

    // MARK: Способы добавить

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ActionTile(icon: "barcode.viewfinder", title: "Сканер", subtitle: "штрихкод на упаковке", hero: true) { scanning = true }
                ActionTile(icon: "camera.viewfinder", title: "Фото полки", subtitle: "много продуктов сразу") { sheet = .shelf }
                ActionTile(icon: "text.viewfinder", title: "Этикетка", subtitle: "КБЖУ с упаковки") { sheet = .label }
                ActionTile(icon: "magnifyingglass", title: "Найти", subtitle: "по названию") { sheet = .search(staple: false) }
            }
            if FoodDB.shared.available {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.fill").font(.system(size: 11))
                    Text("В базе \(fmt(Double(FoodDB.shared.count))) продуктов со штрихкодами · Open Food Facts")
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim)
                .padding(.horizontal, 4)
            }
        }
    }

    private var placePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Куда кладём новые", aside: nil)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Place.allCases, id: \.self) { p in
                        Chip(title: p.title, icon: Theme.icon(p), on: store.place == p) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            store.place = p
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
        }
    }

    // MARK: Список

    struct PlaceGroup: Identifiable {
        let place: Place
        let items: [PantryItem]
        var id: Place { place }
    }

    private var groups: [PlaceGroup] {
        Place.allCases.compactMap { p in
            let items = store.pantry.filter { $0.place == p }
            return items.isEmpty ? nil : PlaceGroup(place: p, items: items)
        }
    }

    private var products: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Продукты", aside: store.pantry.isEmpty ? nil : "\(store.pantry.count) \(plural(store.pantry.count, "позиция", "позиции", "позиций"))")
            if store.pantry.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox").font(.system(size: 30, weight: .light)).foregroundStyle(Theme.dim)
                    Text("Пока пусто. Отсканируй пару упаковок или сфоткай холодильник — список соберётся сам.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(26)
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundStyle(Theme.line2))
            } else {
                ForEach(groups) { group in
                    let place = group.place
                    let items = group.items
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: Theme.icon(place)).font(.system(size: 13, weight: .semibold))
                            Text(place.title).font(.system(size: 13, weight: .semibold))
                            Text("\(items.count)").font(.system(size: 13)).foregroundStyle(Theme.dim)
                        }
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                        Card(padding: 0) {
                            ForEach(items) { item in
                                if item.id != items.first?.id { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 16) }
                                PantryRow(item: item,
                                          onTap: { sheet = .edit(item) },
                                          onDelete: { withAnimation(.snappy) { store.remove(item.id) } })
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                Button("Очистить список") { confirmClear = true }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.dim)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var staplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Всегда есть дома", aside: "нажми, чтобы выключить")
            Card {
                FlowLayout(spacing: 8) {
                    ForEach(store.staples) { s in
                        Chip(title: s.food.name, on: s.on, strikeWhenOff: true) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            store.toggleStaple(s.id)
                        }
                        .contextMenu {
                            Button(role: .destructive) { store.removeStaple(s.id) } label: { Label("Убрать из списка", systemImage: "trash") }
                        }
                    }
                    Button {
                        sheet = .search(staple: true)
                    } label: {
                        Label("Добавить", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .foregroundStyle(Theme.accentInk)
                            .background(Capsule().fill(Theme.accentGradient))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Специи, соусы и масла приложение берёт без фото. Калории масла, майонеза и кетчупа оно считает в КБЖУ.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

func plural(_ n: Int, _ a: String, _ b: String, _ c: String) -> String {
    let m10 = n % 10, m100 = n % 100
    if m10 == 1 && m100 != 11 { return a }
    if (2...4).contains(m10) && !(12...14).contains(m100) { return b }
    return c
}

struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var hero = false
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(hero ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.raised))
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(hero ? Theme.accentInk : Theme.text)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold))
                    Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(hero ? AnyShapeStyle(LinearGradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Theme.surface))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(hero ? Theme.accent.opacity(0.5) : Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PantryRow: View {
    let item: PantryItem
    var onTap: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.food.name).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                if let b = item.food.brand, !b.isEmpty {
                    Text(b).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineLimit(1)
                }
                HStack(spacing: 8) {
                    MacroLine(per100: item.food.per100)
                    SourceBadge(source: item.food.source)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                Text(amountText(item)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.dim)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Удалить")
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

func amountText(_ item: PantryItem) -> String {
    guard let g = item.grams, g > 0 else { return "много" }
    if let pg = item.food.pieceGrams, pg > 0, pg < 400 {
        let n = (g / pg).rounded()
        if n >= 1 && abs(n * pg - g) < pg * 0.2 { return "\(Int(n)) шт" }
    }
    if g >= 1000 { return "\(fmtSmart((g / 100).rounded() / 10)) кг" }
    return "\(fmt(g)) г"
}

struct MacroLine: View {
    let per100: Macros
    var body: some View {
        HStack(spacing: 6) {
            Text("\(fmt(per100.kcal)) ккал").foregroundStyle(Theme.muted)
            Text("Б \(fmtSmart(per100.p))").foregroundStyle(Theme.prot)
            Text("Ж \(fmtSmart(per100.f))").foregroundStyle(Theme.fat)
            Text("У \(fmtSmart(per100.c))").foregroundStyle(Theme.carb)
        }
        .font(.system(size: 12.5).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

struct SourceBadge: View {
    let source: FoodSource
    var body: some View {
        switch source {
        case .catalog: Badge(text: "каталог")
        case .barcode: Badge(text: "штрихкод", good: true)
        case .label: Badge(text: "с этикетки", good: true)
        case .manual: Badge(text: "вручную")
        }
    }
}
