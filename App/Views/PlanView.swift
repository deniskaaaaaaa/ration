import SwiftUI
import UIKit

struct PlanView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppHeader()
                    ScreenTitle(step: "Шаг 3 из 3", title: "Рацион на сегодня", subtitle: targetLine)
                    PlanSettings()
                    generate
                    if store.busy {
                        Card {
                            HStack(spacing: 14) {
                                ProgressView().tint(Theme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Подбираю блюда").font(.system(size: 16, weight: .semibold))
                                    Text("Перебираю сотни сочетаний и подгоняю граммы под КБЖУ…").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                        .transition(.opacity)
                    } else if let plan = store.plan {
                        PlanPager(plan: plan)
                            .id("pager")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.busy) { _, busy in
                if !busy && store.plan != nil {
                    withAnimation(.snappy) { proxy.scrollTo("pager", anchor: .top) }
                }
            }
            .onChange(of: store.page) { _, _ in
                withAnimation(.snappy) { proxy.scrollTo("pager", anchor: .top) }
            }
        }
    }

    private var targetLine: String {
        let t = store.target
        return "Цель: \(fmt(t.kcal)) ккал · Б \(fmt(t.p)) · Ж \(fmt(t.f)) · У \(fmt(t.c))"
    }

    private var generate: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await store.generate() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(store.plan == nil ? "Составить рацион" : "Пересобрать рацион")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.busy || store.pantry.isEmpty)
            if store.pantry.isEmpty {
                Button {
                    withAnimation(.snappy) { store.tab = .food }
                } label: {
                    Text("Сначала добавь продукты во вкладке «Продукты» →")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.warn)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Настройки дня

struct PlanSettings: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Приёмов пищи").font(.system(size: 15, weight: .semibold))
                Segmented(items: [(3, "3"), (4, "4"), (5, "5"), (6, "6")], selection: $store.options.mealCount)
            }
            .padding(16)
            line
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Первый приём").font(.system(size: 15, weight: .semibold))
                    Text("остальные через 3–4 часа").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ru_RU"))
            }
            .padding(16)
            line
            VStack(alignment: .leading, spacing: 10) {
                Text("Готовить не дольше").font(.system(size: 15, weight: .semibold))
                Segmented(items: [(0, "Любое"), (15, "15 мин"), (30, "30 мин"), (45, "45 мин")], selection: minutesBinding)
            }
            .padding(16)
            line
            VStack(alignment: .leading, spacing: 10) {
                Text("Пожелания").font(.system(size: 15, weight: .semibold))
                FlowLayout(spacing: 8) {
                    wish("Обед с собой в машину", "car.fill", \.portableLunch)
                    wish("Без духовки", "oven", \.noOven)
                    wish("Минимум посуды", "frying.pan", \.fewDishes)
                    wish("Готовить сразу на 2 дня", "2.circle", \.cookForTwoDays)
                    wish("Сладкий перекус", "birthday.cake", \.sweetSnack)
                    wish("Протеиновый десерт", "star.fill", \.proteinDessert)
                    wish("Без рыбы", "fish", \.noFish)
                    wish("Без свинины", "nosign", \.noPork)
                    wish("Вегетарианское", "leaf", \.vegetarian)
                }
            }
            .padding(16)
        }
    }

    private var line: some View { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 16) }

    private func wish(_ title: String, _ icon: String, _ key: WritableKeyPath<PlanOptions, Bool>) -> some View {
        Chip(title: title, icon: icon, on: store.options[keyPath: key]) {
            UISelectionFeedbackGenerator().selectionChanged()
            store.options[keyPath: key].toggle()
        }
    }

    private var minutesBinding: Binding<Int> {
        Binding(get: { store.options.maxMinutes ?? 0 },
                set: { store.options.maxMinutes = $0 == 0 ? nil : $0 })
    }

    private var timeBinding: Binding<Date> {
        Binding(get: {
            let m = Schedule.minutes(of: store.options.firstMeal)
            return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            store.options.firstMeal = String(format: "%02d:%02d", c.hour ?? 7, c.minute ?? 0)
        })
    }
}

// MARK: - Страницы рациона

struct PlanPager: View {
    @EnvironmentObject var store: AppStore
    let plan: DayPlan
    @State private var edge: Edge = .trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        pill(0, "Итог", "весь день")
                        ForEach(plan.meals.indices, id: \.self) { i in
                            pill(i + 1, plan.meals[i].slot.name, plan.meals[i].slot.time)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -16)
                .onChange(of: store.page) { _, p in
                    withAnimation(.snappy) { proxy.scrollTo(p, anchor: .center) }
                }
            }

            Group {
                if store.page == 0 || store.page > plan.meals.count {
                    SummaryPage(plan: plan, open: go(to:))
                } else {
                    MealPage(plan: plan, index: store.page - 1)
                }
            }
            .id(store.page)
            .transition(.asymmetric(insertion: .move(edge: edge).combined(with: .opacity), removal: .opacity))

            HStack(spacing: 10) {
                Button { step(-1) } label: { Label("Назад", systemImage: "chevron.left") }
                    .buttonStyle(SecondaryButtonStyle(height: 48))
                    .disabled(store.page == 0)
                Text("\(store.page + 1) / \(plan.meals.count + 1)")
                    .font(.rounded(15, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .frame(width: 60)
                Button { step(1) } label: {
                    HStack(spacing: 6) { Text("Дальше"); Image(systemName: "chevron.right") }
                }
                .buttonStyle(SecondaryButtonStyle(height: 48))
                .disabled(store.page >= plan.meals.count)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                if abs(dx) > 70 && abs(dx) > abs(dy) * 1.6 { step(dx < 0 ? 1 : -1) }
            }
        )
    }

    private func pill(_ i: Int, _ title: String, _ sub: String) -> some View {
        let on = store.page == i
        return Button { go(to: i) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(sub).font(.system(size: 11.5, weight: .medium)).monospacedDigit()
                    .foregroundStyle(on ? Theme.bg.opacity(0.6) : Theme.dim)
            }
            .foregroundStyle(on ? Theme.bg : Theme.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(on ? Theme.text : Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(on ? Theme.text : Theme.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .id(i)
    }

    private func step(_ d: Int) {
        go(to: min(max(store.page + d, 0), plan.meals.count))
    }

    private func go(to p: Int) {
        guard p != store.page else { return }
        edge = p > store.page ? .trailing : .leading
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.snappy(duration: 0.32)) { store.page = p }
    }
}

// MARK: - Итог дня

struct SummaryPage: View {
    @EnvironmentObject var store: AppStore
    let plan: DayPlan
    let open: (Int) -> Void

    var body: some View {
        let t = plan.macros
        let T = plan.target
        VStack(alignment: .leading, spacing: 20) {
            Card {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Рацион на " + plan.created.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))))
                            .font(.rounded(21, .heavy))
                        Text("\(plan.meals.count) \(plural(plan.meals.count, "приём", "приёма", "приёмов")) пищи · \(fmt(t.kcal)) ккал")
                            .font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }
                HStack(spacing: 4) {
                    RingStat(name: "Калории", value: t.kcal, target: T.kcal, unit: "", color: Theme.accent, key: .kcal)
                    RingStat(name: "Белки", value: t.p, target: T.p, unit: " г", color: Theme.prot, key: .p)
                    RingStat(name: "Жиры", value: t.f, target: T.f, unit: " г", color: Theme.fat, key: .f)
                    RingStat(name: "Углеводы", value: t.c, target: T.c, unit: " г", color: Theme.carb, key: .c)
                }
                .padding(.top, 18)
                if !plan.note.isEmpty {
                    Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 14)
                    Text(plan.note).font(.system(size: 14.5)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "План дня", aside: "нажми, чтобы открыть рецепт")
                VStack(spacing: 10) {
                    ForEach(plan.meals.indices, id: \.self) { i in
                        Button { open(i + 1) } label: { TimelineRow(meal: plan.meals[i], last: i == plan.meals.count - 1) }
                            .buttonStyle(PressStyle())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Таблица КБЖУ")
                Card(padding: 14) {
                    Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 0) {
                        GridRow {
                            head("Приём").gridColumnAlignment(.leading)
                            head("Ккал"); head("Б", Theme.prot); head("Ж", Theme.fat); head("У", Theme.carb)
                        }
                        .padding(.bottom, 8)
                        ForEach(plan.meals.indices, id: \.self) { i in
                            let m = plan.meals[i]
                            let mm = m.macros
                            Divider().overlay(Theme.line).gridCellUnsizedAxes(.horizontal)
                            GridRow {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(m.slot.name).font(.system(size: 14, weight: .medium))
                                    Text(m.slot.time).font(.system(size: 12)).foregroundStyle(Theme.dim)
                                }
                                .gridColumnAlignment(.leading)
                                num(mm.kcal); num(mm.p, Theme.prot); num(mm.f, Theme.fat); num(mm.c, Theme.carb)
                            }
                            .padding(.vertical, 9)
                        }
                        Divider().overlay(Theme.line2).gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            Text("Итого").font(.system(size: 14, weight: .bold)).gridColumnAlignment(.leading)
                            num(t.kcal, bold: true); num(t.p, bold: true); num(t.f, bold: true); num(t.c, bold: true)
                        }
                        .padding(.top, 9)
                        GridRow {
                            Text("Цель").font(.system(size: 13)).foregroundStyle(Theme.dim).gridColumnAlignment(.leading)
                            num(T.kcal, Theme.dim); num(T.p, Theme.dim); num(T.f, Theme.dim); num(T.c, Theme.dim)
                        }
                        .padding(.top, 5)
                    }
                }
            }

            if !plan.buy.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bag.fill").foregroundStyle(Theme.warn)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Докупить, чтобы добрать цель").font(.system(size: 15, weight: .semibold))
                        Text(plan.buy.joined(separator: ", ")).font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.warn.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.warn.opacity(0.3), lineWidth: 1))
            }

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = plan.shareText
                    store.showToast("Рацион скопирован")
                } label: { Label("Скопировать", systemImage: "doc.on.doc") }
                    .buttonStyle(SecondaryButtonStyle())
                ShareLink(item: plan.shareText) { Label("Поделиться", systemImage: "square.and.arrow.up") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func head(_ s: String, _ c: Color = Theme.dim) -> some View {
        Text(s.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.8).foregroundStyle(c)
    }

    private func num(_ v: Double, _ c: Color = Theme.text, bold: Bool = false) -> some View {
        Text(fmt(v)).font(.system(size: 14, weight: bold ? .bold : .regular)).monospacedDigit().foregroundStyle(c)
    }
}

enum MacroKey { case kcal, p, f, c }

struct RingStat: View {
    let name: String
    let value: Double
    let target: Double
    let unit: String
    let color: Color
    let key: MacroKey

    private var inTarget: Bool {
        guard target > 0 else { return true }
        let d = abs(value - target) / target
        switch key {
        case .kcal: return d <= 0.04
        case .p: return value >= target - 5 && d <= 0.12
        default: return d <= 0.12
        }
    }

    var body: some View {
        let frac = target > 0 ? value / target : 0
        VStack(spacing: 6) {
            ZStack {
                ProgressRing(fraction: frac, color: color, lineWidth: 7)
                Text("\(Int((frac * 100).rounded()))%").font(.rounded(14, .bold)).monospacedDigit()
            }
            .frame(width: 70, height: 70)
            Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            Text("\(fmt(value)) / \(fmt(target))\(unit)").font(.system(size: 11.5)).monospacedDigit().foregroundStyle(Theme.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(inTarget ? "в цели" : (value > target ? "+" : "−") + fmt(abs(value - target)) + unit)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(inTarget ? Theme.ok : Theme.warn)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TimelineRow: View {
    let meal: Meal
    let last: Bool

    var body: some View {
        let m = meal.macros
        HStack(alignment: .top, spacing: 0) {
            Text(meal.slot.time)
                .font(.rounded(13, .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
                .frame(width: 46, alignment: .leading)
                .padding(.top, 18)
            VStack(spacing: 0) {
                Circle().stroke(Theme.accent, lineWidth: 2).background(Circle().fill(Theme.bg)).frame(width: 10, height: 10).padding(.top, 21)
                if !last { Rectangle().fill(Theme.line2).frame(width: 1).frame(maxHeight: .infinity) }
            }
            .frame(width: 14)
            VStack(alignment: .leading, spacing: 6) {
                Text(meal.slot.name.uppercased()).font(.system(size: 11.5, weight: .semibold)).tracking(1.2).foregroundStyle(Theme.accent2)
                Text(meal.title).font(.system(size: 16, weight: .bold)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text(fmt(m.kcal)).font(.rounded(16, .bold)) + Text(" ккал").font(.system(size: 13)).foregroundColor(Theme.muted)
                    Text("Б \(fmt(m.p)) · Ж \(fmt(m.f)) · У \(fmt(m.c))").font(.system(size: 13)).monospacedDigit().foregroundStyle(Theme.muted)
                    if meal.minutes > 0 {
                        Label("\(meal.minutes) мин", systemImage: "clock").font(.system(size: 12)).foregroundStyle(Theme.dim).labelStyle(.titleAndIcon)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                MacroBar(macros: m).padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .padding(.leading, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Theme.text)
    }
}

// MARK: - Страница приёма пищи

struct MealPage: View {
    @EnvironmentObject var store: AppStore
    let plan: DayPlan
    let index: Int

    var body: some View {
        let meal = plan.meals[index]
        let m = meal.macros
        VStack(alignment: .leading, spacing: 20) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(RadialGradient(colors: [Theme.accent.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 220, height: 220)
                    .offset(x: 70, y: -80)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(meal.slot.time).font(.rounded(16, .heavy)).foregroundStyle(Theme.accent2)
                        Circle().fill(Theme.dim).frame(width: 4, height: 4)
                        Text(meal.slot.name).font(.system(size: 14)).foregroundStyle(Theme.muted)
                        if meal.minutes > 0 {
                            Circle().fill(Theme.dim).frame(width: 4, height: 4)
                            Label("\(meal.minutes) мин", systemImage: "clock").font(.system(size: 14)).foregroundStyle(Theme.muted)
                        }
                    }
                    Text(meal.title).font(.rounded(26, .heavy)).tracking(-0.4).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        StatBox(value: m.kcal, name: "ккал", color: Theme.accent, wide: true)
                        StatBox(value: m.p, name: "белки", color: Theme.prot)
                        StatBox(value: m.f, name: "жиры", color: Theme.fat)
                        StatBox(value: m.c, name: "углев.", color: Theme.carb)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.surface))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Ингредиенты", aside: "вес до готовки")
                Card(padding: 14) {
                    Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 0) {
                        GridRow {
                            head("Продукт").gridColumnAlignment(.leading)
                            head("г"); head("ккал"); head("Б", Theme.prot); head("Ж", Theme.fat); head("У", Theme.carb)
                        }
                        .padding(.bottom, 8)
                        ForEach(meal.ingredients) { ing in
                            let x = ing.macros
                            Divider().overlay(Theme.line).gridCellUnsizedAxes(.horizontal)
                            GridRow {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ing.food.name).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                                    if !ing.measure.isEmpty { Text(ing.measure).font(.system(size: 12)).foregroundStyle(Theme.dim) }
                                }
                                .gridColumnAlignment(.leading)
                                if ing.locked {
                                    Text("—").foregroundStyle(Theme.dim)
                                    Text(""); Text(""); Text(""); Text("")
                                } else {
                                    Text(fmt(ing.grams)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                                    num(x.kcal); num(x.p, Theme.prot); num(x.f, Theme.fat); num(x.c, Theme.carb)
                                }
                            }
                            .padding(.vertical, 9)
                        }
                        Divider().overlay(Theme.line2).gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            Text("Итого").font(.system(size: 14, weight: .bold)).gridColumnAlignment(.leading)
                            Text("")
                            num(m.kcal, bold: true); num(m.p, bold: true); num(m.f, bold: true); num(m.c, bold: true)
                        }
                        .padding(.top, 9)
                    }
                }
            }

            if !meal.steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Как готовить", aside: "отмечай готовые шаги")
                    VStack(spacing: 8) {
                        ForEach(meal.steps.indices, id: \.self) { k in
                            StepRow(number: k + 1, text: meal.steps[k], done: store.done["\(index):\(k)"] ?? false) {
                                withAnimation(.snappy) { store.toggleStep(index, k) }
                            }
                        }
                    }
                }
            }

            if !meal.tip.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Theme.prot)
                    Text(meal.tip).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.prot.opacity(0.10), Theme.carb.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.prot.opacity(0.25), lineWidth: 1))
            }

            Button {
                Task { await store.replace(index) }
            } label: {
                HStack(spacing: 8) {
                    if store.replacing == index { ProgressView().tint(Theme.text) } else { Image(systemName: "arrow.triangle.2.circlepath") }
                    Text(store.replacing == index ? "Подбираю другое блюдо…" : "Заменить это блюдо")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(store.replacing != nil)
        }
    }

    private func head(_ s: String, _ c: Color = Theme.dim) -> some View {
        Text(s.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.8).foregroundStyle(c)
    }

    private func num(_ v: Double, _ c: Color = Theme.text, bold: Bool = false) -> some View {
        Text(fmt(v)).font(.system(size: 14, weight: bold ? .bold : .regular)).monospacedDigit().foregroundStyle(c)
    }
}

struct StatBox: View {
    let value: Double
    let name: String
    let color: Color
    var wide = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fmt(value)).font(.rounded(19, .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                Dot(color: color, size: 6)
                Text(name).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(wide ? 1 : 0)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct StepRow: View {
    let number: Int
    let text: String
    let done: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(done ? Theme.ok.opacity(0.16) : Theme.raised)
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.ok)
                    } else {
                        Text("\(number)").font(.rounded(16, .heavy)).foregroundStyle(Theme.accent2)
                    }
                }
                .frame(width: 36, height: 36)
                Text(text)
                    .font(.system(size: 15.5))
                    .strikethrough(done, color: Theme.dim)
                    .foregroundStyle(done ? Theme.muted : Theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .opacity(done ? 0.6 : 1)
        }
        .buttonStyle(PressStyle())
    }
}
