import SwiftUI
import UIKit
import PhotosUI

// MARK: - Общие части

struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.rounded(24, .heavy))
                if let subtitle {
                    Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.raised))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
    }
}

/// Сколько продукта есть дома.
struct AmountPicker: View {
    let food: Food
    @Binding var grams: Double?
    @State private var custom = ""

    private var options: [(Double?, String)] {
        var out: [(Double?, String)] = [(nil, "не считать")]
        if let pg = food.pieceGrams, pg > 0, pg <= 200 {
            for n in [1, 2, 4, 6, 10, 12, 20, 30] where Double(n) * pg <= 3000 {
                out.append((Double(n) * pg, "\(n) шт"))
            }
        } else {
            for g in [100.0, 200, 300, 500, 1000, 2000] { out.append((g, g >= 1000 ? "\(fmt(g / 1000)) кг" : "\(fmt(g)) г")) }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Сколько есть дома").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
            FlowLayout(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in
                    let o = options[i]
                    Chip(title: o.1, on: grams == o.0) {
                        grams = o.0
                        custom = ""
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("свой вес", text: $custom)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .onChange(of: custom) { _, v in
                        if let g = Double(v.filter { $0.isNumber }), g > 0 { grams = g }
                    }
                Text("г").foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }
}

func defaultGrams(_ f: Food) -> Double? {
    if let pg = f.pieceGrams, pg > 0, pg <= 200 { return f.role == .eggs ? pg * 10 : nil }
    return nil
}

struct PlaceRow: View {
    @Binding var place: Place
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Place.allCases, id: \.self) { p in
                    Chip(title: p.title, icon: Theme.icon(p), on: place == p) { place = p }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct RoleMenu: View {
    @Binding var role: Role
    var body: some View {
        Menu {
            ForEach(Role.allCases.filter { $0 != .spice }, id: \.self) { r in
                Button(r.title) { role = r }
            }
        } label: {
            HStack(spacing: 6) {
                Text(role.title)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.accent2)
        }
    }
}

struct FoodSummary: View {
    let food: Food
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SourceBadge(source: food.source)
                Text(food.role.title).font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            Text(food.name).font(.system(size: 19, weight: .bold)).fixedSize(horizontal: false, vertical: true)
            if let b = food.brand, !b.isEmpty { Text(b).font(.system(size: 13)).foregroundStyle(Theme.muted) }
            HStack(spacing: 6) {
                Text("На 100 г:").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                MacroLine(per100: food.per100)
            }
        }
    }
}

// MARK: - Живой сканер

struct ScanScreen: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var code: String?
    @State private var found: Food?
    @State private var loading = false
    @State private var notFound = false
    @State private var grams: Double?
    @State private var showLabel = false
    @State private var added = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if BarcodeScannerView.isSupported {
                BarcodeScannerView { c in handle(c) }.ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.metering.unknown").font(.system(size: 40, weight: .light)).foregroundStyle(Theme.muted)
                    Text("Живой сканер не работает на этом iPhone. Добавь продукты через «Фото полки» — штрихкоды на фото тоже читаются.")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
                .padding(32)
            }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сканер").font(.rounded(22, .heavy))
                        Text(added > 0 ? "Добавлено: \(added)" : "Кладём в: \(store.place.title.lowercased())")
                            .font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.75))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Готово").font(.system(size: 15, weight: .bold))
                            .padding(.horizontal, 16).frame(height: 38)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                Spacer()
                bottom
                    .padding(16)
            }
        }
        .foregroundStyle(Theme.text)
        .sheet(isPresented: $showLabel) {
            LabelSheet(code: code)
                .environmentObject(store)
                .presentationBackground(Theme.bg)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder private var bottom: some View {
        VStack(alignment: .leading, spacing: 14) {
            if loading {
                HStack(spacing: 12) {
                    ProgressView().tint(Theme.accent)
                    Text("Ищу продукт \(code ?? "")…").font(.system(size: 15))
                }
            } else if let f = found {
                FoodSummary(food: f)
                AmountPicker(food: f, grams: $grams)
                PlaceRow(place: $store.place)
                Button {
                    store.add(f, grams: grams)
                    added += 1
                    withAnimation(.snappy) { found = nil; code = nil; grams = nil }
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle(height: 52))
            } else if notFound {
                Text("Штрихкод \(code ?? "") не нашёлся ни во встроенной базе, ни в интернете.")
                    .font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { showLabel = true } label: { Label("Фото этикетки", systemImage: "text.viewfinder") }
                        .buttonStyle(PrimaryButtonStyle(height: 50))
                    Button { withAnimation { notFound = false; code = nil } } label: { Text("Дальше") }
                        .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder").font(.system(size: 22)).foregroundStyle(Theme.accent)
                    Text("Наведи камеру на штрихкод упаковки. Продукты можно сканировать один за другим.")
                        .font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.surface.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.line2, lineWidth: 1))
        .animation(.snappy, value: found?.id)
        .animation(.snappy, value: loading)
    }

    private func handle(_ c: String) {
        if c == code && (loading || found != nil || notFound) { return }
        code = c
        found = nil
        notFound = false
        loading = true
        Task { @MainActor in
            let f = await Lookup.barcode(c)
            guard code == c else { return }
            loading = false
            if let f {
                grams = defaultGrams(f)
                withAnimation(.snappy) { found = f }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                withAnimation(.snappy) { notFound = true }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }
}

// MARK: - Поиск

struct SearchSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let stapleMode: Bool
    @State private var query = ""
    @State private var results: [Food] = []
    @State private var searching = false
    @State private var selected: Food?
    @State private var grams: Double?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: stapleMode ? "Всегда есть дома" : "Найти продукт",
                        subtitle: stapleMode ? "Специя, соус или масло, которые всегда под рукой." : "Русские названия из каталога и \(fmt(Double(FoodDB.shared.count))) продуктов с упаковок.") { dismiss() }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("курица, Chobani, гречка…", text: $query)
                    .font(.system(size: 17))
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if searching { ProgressView().tint(Theme.accent) }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(focused ? Theme.accent.opacity(0.55) : Theme.line2, lineWidth: 1))

            if let f = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Card { FoodSummary(food: f) }
                        AmountPicker(food: f, grams: $grams)
                        PlaceRow(place: $store.place)
                        Button {
                            store.add(f, grams: grams)
                            withAnimation(.snappy) { selected = nil; grams = nil }
                            focused = true
                        } label: { Label("Добавить", systemImage: "plus") }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Назад к поиску") { withAnimation(.snappy) { selected = nil } }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if results.isEmpty && !query.isEmpty && !searching {
                            Text("Ничего не нашлось. Попробуй другое слово или английское название с упаковки.")
                                .font(.system(size: 15)).foregroundStyle(Theme.muted).padding(.vertical, 20)
                        }
                        if query.isEmpty { suggestions }
                        ForEach(results) { f in
                            Button { choose(f) } label: { resultRow(f) }
                                .buttonStyle(.plain)
                            Rectangle().fill(Theme.line).frame(height: 1)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .padding(20)
        .onAppear { focused = true }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { results = []; return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            searching = true
            let found = await Lookup.search(q)
            if Task.isCancelled { return }
            if stapleMode {
                let kinds: Set<Role> = [.spice, .sauce, .fat, .sweet, .other]
                results = found.filter { kinds.contains($0.role) } + found.filter { !kinds.contains($0.role) }
            } else {
                results = found
            }
            searching = false
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Часто ищут")
            FlowLayout(spacing: 8) {
                ForEach(stapleMode ? ["Аджика", "Соус", "Сметана", "Чили", "Кумин", "Корица"] : ["Курица", "Гречка", "Творог", "Яйца", "Рис", "Банан", "Тунец", "Овсянка"], id: \.self) { s in
                    Chip(title: s, on: false) { query = s }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func resultRow(_ f: Food) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(f.name).font(.system(size: 16, weight: .semibold)).multilineTextAlignment(.leading)
                if let b = f.brand, !b.isEmpty { Text(b).font(.system(size: 12.5)).foregroundStyle(Theme.dim) }
                MacroLine(per100: f.per100)
            }
            Spacer()
            SourceBadge(source: f.source)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func choose(_ f: Food) {
        UISelectionFeedbackGenerator().selectionChanged()
        if stapleMode {
            store.addStaple(f)
            dismiss()
        } else {
            grams = defaultGrams(f)
            focused = false
            withAnimation(.snappy) { selected = f }
        }
    }
}

// MARK: - Фото полки

struct ShelfSheet: View {
    struct Candidate: Identifiable {
        let id = UUID()
        var food: Food
        var how: String
        var on = true
    }

    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var picks: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var working: String?
    @State private var results: [Candidate] = []
    @State private var missed: [String] = []
    @State private var photos = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: "Фото полки",
                        subtitle: "На снимке ищутся все штрихкоды, а фрукты и овощи узнаются по виду. Снимай ближе, чтобы штрихкоды было видно.") { dismiss() }
            HStack(spacing: 10) {
                Button { camera = true } label: { Label("Снять", systemImage: "camera.fill") }
                    .buttonStyle(PrimaryButtonStyle(height: 50))
                PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .images) {
                    Label("Галерея", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .disabled(working != nil)

            if let w = working {
                HStack(spacing: 12) {
                    ProgressView().tint(Theme.accent)
                    Text(w).font(.system(size: 15))
                }
                .padding(.vertical, 6)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !results.isEmpty {
                        SectionHeader(title: "Нашлось", aside: "\(photos) фото")
                        Card(padding: 0) {
                            ForEach($results) { $c in
                                Button { c.on.toggle() } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: c.on ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(c.on ? Theme.accent : Theme.dim)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(c.food.name).font(.system(size: 15, weight: .semibold)).multilineTextAlignment(.leading)
                                            HStack(spacing: 8) {
                                                Text(c.how).font(.system(size: 12)).foregroundStyle(Theme.dim)
                                                MacroLine(per100: c.food.per100)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !missed.isEmpty {
                        Text("Не нашлись в базе: \(missed.joined(separator: ", ")). Их можно добавить через «Этикетку».")
                            .font(.system(size: 13)).foregroundStyle(Theme.warn).fixedSize(horizontal: false, vertical: true)
                    }
                    if results.isEmpty && working == nil && photos > 0 {
                        Text("На фото не нашлось ни штрихкодов, ни знакомых продуктов. Сними ближе, при хорошем свете.")
                            .font(.system(size: 15)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if results.contains(where: { $0.on }) {
                PlaceRow(place: $store.place)
                Button {
                    for c in results where c.on { store.add(c.food, grams: nil) }
                    dismiss()
                } label: {
                    Text("Добавить выбранные · \(results.filter { $0.on }.count)")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .fullScreenCover(isPresented: $camera) {
            CameraPicker(onImage: { img in
                camera = false
                Task { await analyze([img]) }
            }, onCancel: { camera = false })
            .ignoresSafeArea()
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var imgs: [UIImage] = []
                for it in items {
                    if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { imgs.append(img) }
                }
                picks = []
                await analyze(imgs)
            }
        }
    }

    @MainActor
    private func analyze(_ images: [UIImage]) async {
        var seenFoods = Set(results.map { $0.food.id })
        for (i, img) in images.enumerated() {
            working = images.count > 1 ? "Смотрю фото \(i + 1) из \(images.count)…" : "Смотрю фото…"
            let f = await PhotoAnalyzer.analyze(img, readText: false)
            photos += 1
            for code in f.barcodes {
                working = "Ищу штрихкод \(code)…"
                if let food = await Lookup.barcode(code) {
                    if seenFoods.insert(food.id).inserted {
                        withAnimation(.snappy) { results.append(Candidate(food: food, how: "штрихкод")) }
                    }
                } else if !missed.contains(code) {
                    missed.append(code)
                }
            }
            for (label, _) in f.labels {
                if let food = Catalog.matchVisionLabel(label), seenFoods.insert(food.id).inserted {
                    withAnimation(.snappy) { results.append(Candidate(food: food, how: "узнал по виду")) }
                }
            }
        }
        working = nil
        UINotificationFeedbackGenerator().notificationOccurred(results.isEmpty ? .warning : .success)
    }
}

// MARK: - Фото этикетки

struct LabelSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let code: String?

    @State private var camera = false
    @State private var pick: PhotosPickerItem?
    @State private var working = false
    @State private var scanned = false
    @State private var name = ""
    @State private var role: Role = .other
    @State private var roleTouched = false
    @State private var per100 = Macros()
    @State private var perServing: Macros?
    @State private var serving = ""
    @State private var grams: Double?
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(title: "Этикетка",
                            subtitle: "Сфоткай таблицу «Nutrition Facts» или «Пищевая ценность» — цифры перепишутся сами. Потом их можно поправить.") { dismiss() }
                HStack(spacing: 10) {
                    Button { camera = true } label: { Label(scanned ? "Переснять" : "Снять", systemImage: "camera.fill") }
                        .buttonStyle(PrimaryButtonStyle(height: 50))
                    PhotosPicker(selection: $pick, matching: .images) { Label("Галерея", systemImage: "photo") }
                        .buttonStyle(SecondaryButtonStyle())
                }
                if working {
                    HStack(spacing: 12) { ProgressView().tint(Theme.accent); Text("Читаю этикетку…") }
                }
                if !message.isEmpty {
                    Text(message).font(.system(size: 14)).foregroundStyle(scanned && per100.kcal > 0 ? Theme.ok : Theme.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Название").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                            TextField("например, Греческий йогурт", text: $name)
                                .font(.system(size: 17, weight: .semibold))
                                .onChange(of: name) { _, v in
                                    guard !roleTouched else { return }
                                    let r = RoleMap.classify(categories: [], name: v).0
                                    if r != .other { role = r }
                                }
                        }
                        HStack {
                            Text("Что это").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                            Spacer()
                            RoleMenu(role: Binding(get: { role }, set: { role = $0; roleTouched = true }))
                        }
                        Text("КБЖУ на 100 г").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                        HStack(spacing: 8) {
                            NumberBox(title: "Ккал", color: Theme.accent, value: $per100.kcal)
                            NumberBox(title: "Белки", color: Theme.prot, value: $per100.p)
                            NumberBox(title: "Жиры", color: Theme.fat, value: $per100.f)
                            NumberBox(title: "Углев.", color: Theme.carb, value: $per100.c)
                        }
                        if perServing != nil {
                            HStack(spacing: 8) {
                                Text("Порция на этикетке, г").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                Spacer()
                                TextField("55", text: $serving)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .onChange(of: serving) { _, v in recalc(v) }
                            }
                        }
                    }
                }

                let food = makeFood()
                AmountPicker(food: food, grams: $grams)
                PlaceRow(place: $store.place)
                Button {
                    store.add(makeFood(), grams: grams)
                    dismiss()
                } label: { Label("Добавить", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || per100.kcal <= 0 && per100.p <= 0)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .fullScreenCover(isPresented: $camera) {
            CameraPicker(onImage: { img in
                camera = false
                Task { await read(img) }
            }, onCancel: { camera = false })
            .ignoresSafeArea()
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await read(img) }
                pick = nil
            }
        }
    }

    private func makeFood() -> Food {
        let n = name.trimmingCharacters(in: .whitespaces)
        let (_, kind) = RoleMap.classify(categories: [], name: n)
        let k = kind.flatMap { Catalog.food($0) }.flatMap { $0.role == role ? $0 : nil }
        return Food(id: "lbl:" + (code ?? UUID().uuidString), name: n.isEmpty ? "Продукт" : n, role: role,
                    tags: k?.tags ?? [], per100: per100, pieceGrams: k?.pieceGrams, forms: k?.forms, cook: k?.cook,
                    source: .label, barcode: code, kind: k?.id)
    }

    private func recalc(_ v: String) {
        guard let s = perServing, let g = Double(v.replacingOccurrences(of: ",", with: ".")), g > 0 else { return }
        per100 = s * (100 / g)
    }

    @MainActor
    private func read(_ img: UIImage) async {
        working = true
        let f = await PhotoAnalyzer.analyze(img, readText: true)
        let r = LabelParser.parse(f.text)
        working = false
        scanned = true
        perServing = nil
        if let p = r.per100, r.isUseful {
            per100 = Macros(kcal: p.kcal.rounded(), p: (p.p * 10).rounded() / 10, f: (p.f * 10).rounded() / 10, c: (p.c * 10).rounded() / 10)
            if let s = r.servingGrams { serving = fmtSmart(s); perServing = r.perServing }
            message = "Прочитано с этикетки. Проверь цифры и впиши название."
        } else if let s = r.perServing, r.isUseful {
            perServing = s
            per100 = s
            message = "Нашлись цифры на порцию, но не её вес. Впиши вес порции в граммах — пересчитаю на 100 г."
        } else {
            message = "Не получилось прочитать таблицу. Сними её ровно и ближе или впиши цифры вручную."
        }
        UINotificationFeedbackGenerator().notificationOccurred(r.isUseful ? .success : .warning)
    }
}

// MARK: - Правка продукта

struct EditItemSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var item: PantryItem
    @State private var name = ""
    @State private var role: Role = .other
    @State private var per100 = Macros()
    @State private var grams: Double?
    @State private var place: Place = .fridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(title: "Продукт") { dismiss() }
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Название", text: $name).font(.system(size: 18, weight: .bold))
                        if let b = item.food.brand, !b.isEmpty { Text(b).font(.system(size: 13)).foregroundStyle(Theme.dim) }
                        HStack {
                            Text("Что это").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                            Spacer()
                            RoleMenu(role: $role)
                        }
                        Text("КБЖУ на 100 г").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                        HStack(spacing: 8) {
                            NumberBox(title: "Ккал", color: Theme.accent, value: $per100.kcal)
                            NumberBox(title: "Белки", color: Theme.prot, value: $per100.p)
                            NumberBox(title: "Жиры", color: Theme.fat, value: $per100.f)
                            NumberBox(title: "Углев.", color: Theme.carb, value: $per100.c)
                        }
                        HStack(spacing: 8) {
                            SourceBadge(source: item.food.source)
                            if let bc = item.food.barcode { Text("штрихкод \(bc)").font(.system(size: 12)).foregroundStyle(Theme.dim) }
                        }
                    }
                }
                AmountPicker(food: item.food, grams: $grams)
                if let g = grams { Text("Сейчас: \(amountText(PantryItem(food: item.food, grams: g)))").font(.system(size: 13)).foregroundStyle(Theme.muted) }
                Text("Где лежит").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                PlaceRow(place: $place)
                Button { save(); dismiss() } label: { Text("Сохранить") }
                    .buttonStyle(PrimaryButtonStyle())
                Button(role: .destructive) {
                    store.remove(item.id)
                    dismiss()
                } label: { Label("Удалить продукт", systemImage: "trash").foregroundStyle(Theme.warn) }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            name = item.food.name
            role = item.food.role
            per100 = item.food.per100
            grams = item.grams
            place = item.place
        }
    }

    private func save() {
        var f = item.food
        f.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? f.name : name.trimmingCharacters(in: .whitespaces)
        if f.per100 != per100 {
            f.per100 = per100
            if f.source == .catalog { f.source = .manual; f.id = "man:" + UUID().uuidString }
        }
        if f.role != role {
            f.role = role
            if let k = f.kind, Catalog.food(k)?.role != role {
                f.kind = nil
                f.forms = nil
                f.cook = nil
                f.tags = []
            }
        }
        var updated = item
        updated.food = f
        updated.grams = grams
        updated.place = place
        store.update(updated)
    }
}
