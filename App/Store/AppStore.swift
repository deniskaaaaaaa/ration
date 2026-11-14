import SwiftUI
import UIKit

enum AppTab: String, Codable {
    case goal, food, plan
}

struct StapleEntry: Codable, Hashable, Identifiable {
    var food: Food
    var on: Bool
    var id: String { food.id }
}

/// Всё, что хранится между запусками.
struct SavedState: Codable {
    var profile: Profile
    var pantry: [PantryItem]
    var staples: [StapleEntry]
    var options: PlanOptions
    var plan: DayPlan?
    var done: [String: Bool]
}

@MainActor
final class AppStore: ObservableObject {
    @Published var tab: AppTab = .goal
    @Published var profile: Profile { didSet { scheduleSave() } }
    @Published var pantry: [PantryItem] { didSet { scheduleSave() } }
    @Published var staples: [StapleEntry] { didSet { scheduleSave() } }
    @Published var options: PlanOptions { didSet { scheduleSave() } }
    @Published var plan: DayPlan? { didSet { scheduleSave() } }
    @Published var done: [String: Bool] { didSet { scheduleSave() } }

    /// Куда кладём новые продукты.
    @Published var place: Place = .fridge
    @Published var busy = false
    @Published var replacing: Int?
    @Published var toast: String?
    /// Страница рациона: 0 — итог дня, дальше — приёмы пищи.
    @Published var page = 0

    private var saveTask: Task<Void, Never>?
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("state.json")
        if let data = try? Data(contentsOf: fileURL), let s = try? JSONDecoder().decode(SavedState.self, from: data) {
            profile = s.profile
            pantry = s.pantry
            staples = s.staples
            options = s.options
            plan = s.plan
            done = s.done
        } else {
            profile = Profile()
            pantry = []
            staples = Catalog.defaultStapleIDs.compactMap { Catalog.food($0) }.map { StapleEntry(food: $0, on: true) }
            options = PlanOptions()
            plan = nil
            done = [:]
        }
    }

    var target: Macros { profile.target }
    var enabledStaples: [Food] { staples.filter { $0.on }.map { $0.food } }

    // MARK: Сохранение

    private func scheduleSave() {
        saveTask?.cancel()
        let state = SavedState(profile: profile, pantry: pantry, staples: staples, options: options, plan: plan, done: done)
        let url = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            guard let data = try? JSONEncoder().encode(state) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: Продукты

    func add(_ food: Food, grams: Double?, place: Place? = nil) {
        if let i = pantry.firstIndex(where: { $0.food.id == food.id }) {
            if let g = grams { pantry[i].grams = (pantry[i].grams ?? 0) + g }
            showToast("\(food.name) — уже в списке, количество обновлено")
        } else {
            pantry.insert(PantryItem(food: food, grams: grams, place: place ?? self.place), at: 0)
            showToast("Добавлено: \(food.name)")
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func update(_ item: PantryItem) {
        if let i = pantry.firstIndex(where: { $0.id == item.id }) { pantry[i] = item }
    }

    func remove(_ id: UUID) {
        pantry.removeAll { $0.id == id }
    }

    func clearPantry() { pantry = [] }

    func toggleStaple(_ id: String) {
        if let i = staples.firstIndex(where: { $0.id == id }) { staples[i].on.toggle() }
    }

    func addStaple(_ food: Food) {
        if let i = staples.firstIndex(where: { $0.id == food.id }) {
            staples[i].on = true
        } else {
            staples.append(StapleEntry(food: food, on: true))
        }
        showToast("«\(food.name)» теперь всегда есть дома")
    }

    func removeStaple(_ id: String) {
        staples.removeAll { $0.id == id }
    }

    // MARK: Рацион

    func generate() async {
        guard !busy else { return }
        busy = true
        let input = PlannerInput(pantry: pantry, staples: enabledStaples, target: target, options: options,
                                 seed: UInt64.random(in: 1...UInt64.max))
        let result = await Task.detached(priority: .userInitiated) { Planner.generate(input) }.value
        withAnimation(.snappy) {
            plan = result
            page = 0
            done = [:]
            busy = false
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func replace(_ index: Int) async {
        guard let current = plan, replacing == nil else { return }
        replacing = index
        let input = PlannerInput(pantry: pantry, staples: enabledStaples, target: target, options: options,
                                 seed: UInt64.random(in: 1...UInt64.max))
        let result = await Task.detached(priority: .userInitiated) { Planner.replace(meal: index, in: current, input: input) }.value
        withAnimation(.snappy) {
            plan = result
            done = done.filter { !$0.key.hasPrefix("\(index):") }
            replacing = nil
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func toggleStep(_ meal: Int, _ step: Int) {
        let k = "\(meal):\(step)"
        done[k] = !(done[k] ?? false)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: Подсказки

    func showToast(_ s: String) {
        withAnimation(.snappy) { toast = s }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toast == s { withAnimation(.snappy) { toast = nil } }
        }
    }
}

// MARK: - Текст рациона для «Скопировать» и «Поделиться»

extension DayPlan {
    var shareText: String {
        let t = macros
        var lines = ["РАЦИОН — \(fmt(t.kcal)) ккал · Б \(fmt(t.p)) · Ж \(fmt(t.f)) · У \(fmt(t.c))",
                     "Цель: \(fmt(target.kcal)) ккал · Б \(fmt(target.p)) · Ж \(fmt(target.f)) · У \(fmt(target.c))"]
        for m in meals {
            let mm = m.macros
            lines.append("")
            lines.append("\(m.slot.time) \(m.slot.name.uppercased()) — \(m.title)\(m.minutes > 0 ? " (\(m.minutes) мин)" : "")")
            lines.append("\(fmt(mm.kcal)) ккал · Б \(fmt(mm.p)) · Ж \(fmt(mm.f)) · У \(fmt(mm.c))")
            for i in m.ingredients {
                let amount = i.locked ? "по вкусу" : "\(fmt(i.grams)) г" + (i.measure.isEmpty ? "" : " (\(i.measure))")
                lines.append("• \(i.food.name) — \(amount)")
            }
            for (k, s) in m.steps.enumerated() { lines.append("\(k + 1). \(s)") }
            if !m.tip.isEmpty { lines.append("Совет: \(m.tip)") }
        }
        if !buy.isEmpty {
            lines.append("")
            lines.append("Докупить: " + buy.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }
}
