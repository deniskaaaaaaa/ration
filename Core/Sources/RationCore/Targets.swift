import Foundation

public enum Goal: String, Codable, CaseIterable, Sendable {
    case cut, keep, bulk

    public var title: String {
        switch self {
        case .cut: return "Сушка"
        case .keep: return "Поддержание"
        case .bulk: return "Набор"
        }
    }
    public var subtitle: String {
        switch self {
        case .cut: return "−20% ккал"
        case .keep: return "калории в ноль"
        case .bulk: return "+10% ккал"
        }
    }
    /// Множитель к расходу калорий.
    public var kcalFactor: Double {
        switch self { case .cut: return 0.8; case .keep: return 1.0; case .bulk: return 1.1 }
    }
    /// Белок, г на кг веса.
    public var proteinPerKg: Double {
        switch self { case .cut: return 2.2; case .keep: return 1.8; case .bulk: return 1.8 }
    }
    /// Жиры, г на кг веса.
    public var fatPerKg: Double {
        switch self { case .cut: return 0.8; case .keep: return 0.9; case .bulk: return 1.0 }
    }
}

public struct ActivityLevel: Sendable {
    public let factor: Double
    public let title: String
    public let detail: String

    public static let all: [ActivityLevel] = [
        ActivityLevel(factor: 1.2, title: "Сидячая", detail: "Почти без движения и без тренировок"),
        ActivityLevel(factor: 1.375, title: "Лёгкая", detail: "1–3 тренировки в неделю"),
        ActivityLevel(factor: 1.55, title: "Средняя", detail: "3–5 тренировок или работа на ногах"),
        ActivityLevel(factor: 1.725, title: "Высокая", detail: "Физическая работа плюс регулярный зал"),
        ActivityLevel(factor: 1.9, title: "Очень высокая", detail: "Тяжёлый труд и тренировки каждый день")
    ]
}

public struct Profile: Codable, Hashable, Sendable {
    public var male: Bool
    public var age: Double
    public var height: Double
    public var weight: Double
    public var activity: Int          // индекс в ActivityLevel.all
    public var goal: Goal
    public var manual: Bool
    public var manualTarget: Macros

    public init(male: Bool = true, age: Double = 24, height: Double = 182, weight: Double = 88.5,
                activity: Int = 2, goal: Goal = .cut, manual: Bool = false,
                manualTarget: Macros = Macros(kcal: 2000, p: 150, f: 60, c: 200)) {
        self.male = male; self.age = age; self.height = height; self.weight = weight
        self.activity = activity; self.goal = goal; self.manual = manual; self.manualTarget = manualTarget
    }

    public var activityLevel: ActivityLevel {
        ActivityLevel.all[min(max(activity, 0), ActivityLevel.all.count - 1)]
    }

    /// Обмен веществ в покое по Миффлину — Сан Жеору.
    public var bmr: Double {
        10 * weight + 6.25 * height - 5 * age + (male ? 5 : -161)
    }

    /// Расход за день с учётом активности.
    public var tdee: Double { bmr * activityLevel.factor }

    /// Расчётная цель (без учёта ручного режима).
    public var computedTarget: Macros {
        let kcal = ((tdee * goal.kcalFactor) / 10).rounded() * 10
        let p = (weight * goal.proteinPerKg).rounded()
        let f = (weight * goal.fatPerKg).rounded()
        let c = max(50, ((kcal - p * 4 - f * 9) / 4).rounded())
        return Macros(kcal: kcal, p: p, f: f, c: c)
    }

    public var target: Macros { manual ? manualTarget : computedTarget }
}

// MARK: - Приёмы пищи по времени

public enum Schedule {
    /// Названия, виды и доли калорий приёмов для 3–6 приёмов в день.
    public static func slots(count: Int, firstMeal: String) -> [MealSlot] {
        let n = min(max(count, 3), 6)
        let layout: [(String, MealKind, Double)]
        switch n {
        case 3: layout = [("Завтрак", .breakfast, 0.30), ("Обед", .main, 0.40), ("Ужин", .main, 0.30)]
        case 4: layout = [("Завтрак", .breakfast, 0.25), ("Обед", .main, 0.35), ("Перекус", .snack, 0.12), ("Ужин", .main, 0.28)]
        case 5: layout = [("Завтрак", .breakfast, 0.22), ("Перекус", .snack, 0.10), ("Обед", .main, 0.30), ("Перекус", .snack, 0.10), ("Ужин", .main, 0.28)]
        default: layout = [("Завтрак", .breakfast, 0.20), ("Перекус", .snack, 0.10), ("Обед", .main, 0.27), ("Перекус", .snack, 0.10), ("Ужин", .main, 0.23), ("Перед сном", .evening, 0.10)]
        }
        let gapMinutes: Int = [3: 300, 4: 240, 5: 195, 6: 180][n] ?? 240
        let start = minutes(of: firstMeal)
        return layout.enumerated().map { i, item in
            MealSlot(name: item.0, kind: item.1, time: clock(start + i * gapMinutes), share: item.2)
        }
    }

    public static func minutes(of hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 7 * 60 }
        return parts[0] * 60 + parts[1]
    }

    public static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        let rounded = (m / 15) * 15
        return String(format: "%02d:%02d", rounded / 60, rounded % 60)
    }
}
