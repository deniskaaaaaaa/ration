import Foundation

// MARK: - КБЖУ

public struct Macros: Codable, Hashable, Sendable {
    public var kcal: Double
    public var p: Double
    public var f: Double
    public var c: Double

    public init(kcal: Double = 0, p: Double = 0, f: Double = 0, c: Double = 0) {
        self.kcal = kcal; self.p = p; self.f = f; self.c = c
    }

    public static let zero = Macros()

    public static func + (a: Macros, b: Macros) -> Macros {
        Macros(kcal: a.kcal + b.kcal, p: a.p + b.p, f: a.f + b.f, c: a.c + b.c)
    }
    public static func - (a: Macros, b: Macros) -> Macros {
        Macros(kcal: a.kcal - b.kcal, p: a.p - b.p, f: a.f - b.f, c: a.c - b.c)
    }
    public static func * (a: Macros, k: Double) -> Macros {
        Macros(kcal: a.kcal * k, p: a.p * k, f: a.f * k, c: a.c * k)
    }

    /// Калории, посчитанные из БЖУ (4/9/4).
    public var kcalFromMacros: Double { p * 4 + f * 9 + c * 4 }
}

// MARK: - Роль продукта в блюде

public enum Role: String, Codable, CaseIterable, Sendable {
    case meat, fish, eggs, cottage, yogurt, milk, cheese
    case grain, pasta, oats, bread, potato, legumes
    case vegetable, greens, fruit, berries, nuts
    case sweet, protein, ready, sausage, snack
    case sauce, fat, spice, drink, other

    public var title: String {
        switch self {
        case .meat: return "Мясо и птица"
        case .fish: return "Рыба и морепродукты"
        case .eggs: return "Яйца"
        case .cottage: return "Творог"
        case .yogurt: return "Йогурт"
        case .milk: return "Молоко и кефир"
        case .cheese: return "Сыр"
        case .grain: return "Крупы"
        case .pasta: return "Макароны и лапша"
        case .oats: return "Хлопья и овсянка"
        case .bread: return "Хлеб и лепёшки"
        case .potato: return "Картофель"
        case .legumes: return "Бобовые и тофу"
        case .vegetable: return "Овощи"
        case .greens: return "Зелень и салат"
        case .fruit: return "Фрукты"
        case .berries: return "Ягоды"
        case .nuts: return "Орехи и семечки"
        case .sweet: return "Сладкое"
        case .protein: return "Протеин"
        case .ready: return "Готовая еда"
        case .sausage: return "Колбаса и сосиски"
        case .snack: return "Перекусы"
        case .sauce: return "Соусы"
        case .fat: return "Масло"
        case .spice: return "Специи"
        case .drink: return "Напитки"
        case .other: return "Другое"
        }
    }

    /// Формы для текста рецепта, если у продукта нет своих.
    public var defaultForms: Forms {
        switch self {
        case .meat: return Forms("Мясо", acc: "мясо", ins: "мясом")
        case .fish: return Forms("Рыба", acc: "рыбу", ins: "рыбой")
        case .eggs: return Forms("Яйца", acc: "яйца", ins: "яйцами")
        case .cottage: return Forms("Творог", acc: "творог", ins: "творогом")
        case .yogurt: return Forms("Йогурт", acc: "йогурт", ins: "йогуртом")
        case .milk: return Forms("Молоко", acc: "молоко", ins: "молоком")
        case .cheese: return Forms("Сыр", acc: "сыр", ins: "сыром")
        case .grain: return Forms("Крупа", acc: "крупу", ins: "крупой")
        case .pasta: return Forms("Макароны", acc: "макароны", ins: "макаронами")
        case .oats: return Forms("Хлопья", acc: "хлопья", ins: "хлопьями")
        case .bread: return Forms("Хлеб", acc: "хлеб", ins: "хлебом")
        case .potato: return Forms("Картофель", acc: "картофель", ins: "картофелем")
        case .legumes: return Forms("Фасоль", acc: "фасоль", ins: "фасолью")
        case .vegetable: return Forms("Овощи", acc: "овощи", ins: "овощами")
        case .greens: return Forms("Зелень", acc: "зелень", ins: "зеленью")
        case .fruit: return Forms("Фрукты", acc: "фрукты", ins: "фруктами")
        case .berries: return Forms("Ягоды", acc: "ягоды", ins: "ягодами")
        case .nuts: return Forms("Орехи", acc: "орехи", ins: "орехами")
        case .sweet: return Forms("Сладкое", acc: "сладкое", ins: "сладким")
        case .protein: return Forms("Протеин", acc: "протеин", ins: "протеином")
        case .ready: return Forms("Готовое блюдо", acc: "готовое блюдо", ins: "готовым блюдом")
        case .sausage: return Forms("Колбаски", acc: "колбаски", ins: "колбасками")
        case .snack: return Forms("Перекус", acc: "перекус", ins: "перекусом")
        case .sauce: return Forms("Соус", acc: "соус", ins: "соусом")
        case .fat: return Forms("Масло", acc: "масло", ins: "маслом")
        case .spice: return Forms("Специи", acc: "специи", ins: "специями")
        case .drink: return Forms("Напиток", acc: "напиток", ins: "напитком")
        case .other: return Forms("Продукт", acc: "продукт", ins: "продуктом")
        }
    }

    /// Разумные пределы порции одного ингредиента в одном приёме пищи, г.
    public var portion: ClosedRange<Double> {
        switch self {
        case .meat: return 90...320
        case .fish: return 90...300
        case .eggs: return 50...250
        case .cottage: return 100...350
        case .yogurt: return 100...350
        case .milk: return 100...400
        case .cheese: return 10...60
        case .grain: return 30...130
        case .pasta: return 40...140
        case .oats: return 30...110
        case .bread: return 25...130
        case .potato: return 120...450
        case .legumes: return 60...260
        case .vegetable: return 50...300
        case .greens: return 20...150
        case .fruit: return 80...260
        case .berries: return 50...200
        case .nuts: return 10...40
        case .sweet: return 5...30
        case .protein: return 20...60
        case .ready: return 150...450
        case .sausage: return 50...200
        case .snack: return 25...90
        case .sauce: return 10...40
        case .fat: return 3...15
        case .spice: return 0...0
        case .drink: return 150...400
        case .other: return 20...250
        }
    }

    /// Обычная порция, от которой начинается подбор граммов.
    public var typical: Double {
        let r = portion
        switch self {
        case .meat, .fish: return 180
        case .eggs: return 110
        case .grain, .pasta: return 75
        case .oats: return 60
        case .potato: return 250
        case .vegetable: return 150
        case .fat: return 7
        case .sauce: return 15
        case .cheese: return 25
        case .nuts: return 20
        case .spice: return 0
        default: return (r.lowerBound + r.upperBound) / 2
        }
    }
}

/// Слова для текста рецепта: заголовок (именительный), «обжарь …» (винительный), «с …» (творительный).
public struct Forms: Codable, Hashable, Sendable {
    public var title: String
    public var acc: String
    public var ins: String
    public init(_ title: String, acc: String, ins: String) {
        self.title = title; self.acc = acc; self.ins = ins
    }
}

/// Способ приготовления: от него зависят фразы в шагах рецепта.
public enum Cook: String, Codable, Sendable {
    // мясо и птица
    case chicken, groundMeat, beef, pork, sausage, liver, cookedMeat, bacon, cannedMeat
    // рыба
    case fishFillet, salmon, shrimp, cannedFish
    // гарниры
    case rice, buckwheat, quinoa, bulgur, couscous, millet, barley, pasta, noodles
    case potato, sweetPotato, fries
    case cannedLegumes, lentils, dryBeans, tofu
    // овощи
    case freshVeg, frozenVeg, cannedVeg, leafy
    // прочее
    case egg, noCook, ready, readyFrozen, dumplings
}

// MARK: - Продукт

public enum FoodSource: String, Codable, Sendable {
    case catalog   // встроенный каталог на русском
    case barcode   // база Open Food Facts по штрихкоду
    case label     // прочитано с этикетки
    case manual    // вписано вручную
}

public struct Food: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var brand: String?
    public var role: Role
    public var tags: [String]
    /// КБЖУ на 100 г.
    public var per100: Macros
    /// Вес одной штуки, если продукт считают штуками (яйцо, банан, лепёшка).
    public var pieceGrams: Double?
    public var forms: Forms?
    public var cook: Cook?
    public var source: FoodSource
    public var barcode: String?
    /// Английские синонимы для поиска и распознавания по фото.
    public var aliases: [String]
    /// Вид продукта из каталога («c:chicken_breast»): от него берутся слова для рецепта и способ готовки.
    public var kind: String?

    public init(id: String, name: String, brand: String? = nil, role: Role, tags: [String] = [],
                per100: Macros, pieceGrams: Double? = nil, forms: Forms? = nil, cook: Cook? = nil,
                source: FoodSource = .catalog, barcode: String? = nil, aliases: [String] = [], kind: String? = nil) {
        self.id = id; self.name = name; self.brand = brand; self.role = role; self.tags = tags
        self.per100 = per100; self.pieceGrams = pieceGrams; self.forms = forms; self.cook = cook
        self.source = source; self.barcode = barcode; self.aliases = aliases
        self.kind = kind ?? (source == .catalog ? id : nil)
    }

    /// Совпадает ли продукт с видом из каталога (сам вид или продукт этого вида).
    public func isKind(_ k: String) -> Bool { id == k || kind == k }

    public var words: Forms { forms ?? role.defaultForms }
    public func has(_ tag: String) -> Bool { tags.contains(tag) }
    public func macros(grams: Double) -> Macros { per100 * (grams / 100) }
}

// MARK: - Запасы дома

public enum Place: String, Codable, CaseIterable, Sendable {
    case fridge, freezer, cupboard, table, other
    public var title: String {
        switch self {
        case .fridge: return "Холодильник"
        case .freezer: return "Морозилка"
        case .cupboard: return "Шкаф"
        case .table: return "Стол"
        case .other: return "Другое"
        }
    }
}

public struct PantryItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var food: Food
    /// Сколько есть, г. nil — «много / не считаю».
    public var grams: Double?
    public var place: Place
    public var added: Date

    public init(id: UUID = UUID(), food: Food, grams: Double? = nil, place: Place = .fridge, added: Date = Date()) {
        self.id = id; self.food = food; self.grams = grams; self.place = place; self.added = added
    }
}

// MARK: - Рацион

public enum MealKind: String, Codable, Sendable {
    case breakfast, main, snack, evening
}

public struct MealSlot: Codable, Hashable, Sendable {
    public var name: String
    public var kind: MealKind
    public var time: String
    /// Доля калорий дня, которую обычно занимает этот приём.
    public var share: Double
    public init(name: String, kind: MealKind, time: String, share: Double) {
        self.name = name; self.kind = kind; self.time = time; self.share = share
    }
}

public struct Ingredient: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var food: Food
    public var grams: Double
    /// Не трогать граммы при подгонке (специи, «по вкусу»).
    public var locked: Bool
    public init(id: UUID = UUID(), food: Food, grams: Double, locked: Bool = false) {
        self.id = id; self.food = food; self.grams = grams; self.locked = locked
    }
    public var macros: Macros { food.macros(grams: grams) }

    /// Понятная мера рядом с граммами: «2 шт», «1 ч. л.», «по вкусу».
    public var measure: String {
        if food.role == .spice { return "по вкусу" }
        if let pg = food.pieceGrams, pg > 0 {
            let n = grams / pg
            let r = (n * 2).rounded() / 2
            if abs(n - r) < 0.08, r > 0 {
                let whole = r == r.rounded()
                let s = whole ? String(Int(r)) : String(format: "%.1f", r).replacingOccurrences(of: ".", with: ",")
                let unit: (String, String, String)
                if food.has("canned") { unit = ("банка", "банки", "банок") }
                else if food.has("slice") { unit = ("ломтик", "ломтика", "ломтиков") }
                else { unit = ("шт", "шт", "шт") }
                let word = whole ? Say.plural(Int(r), unit.0, unit.1, unit.2) : unit.1
                return "\(s) \(word)"
            }
        }
        if food.role == .fat {
            if grams <= 6 { return "1 ч. л." }
            if grams <= 11 { return "2 ч. л." }
            return "1 ст. л."
        }
        if food.role == .sauce && grams <= 35 {
            let spoons = max(1, Int((grams / 15).rounded()))
            return "\(spoons) ст. л."
        }
        return ""
    }
}

public struct Meal: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var slot: MealSlot
    public var templateID: String
    public var title: String
    public var minutes: Int
    public var ingredients: [Ingredient]
    public var steps: [String]
    public var tip: String
    public init(id: UUID = UUID(), slot: MealSlot, templateID: String, title: String, minutes: Int,
                ingredients: [Ingredient], steps: [String], tip: String) {
        self.id = id; self.slot = slot; self.templateID = templateID; self.title = title
        self.minutes = minutes; self.ingredients = ingredients; self.steps = steps; self.tip = tip
    }
    public var macros: Macros { ingredients.reduce(.zero) { $0 + $1.macros } }
}

public struct DayPlan: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var created: Date
    public var target: Macros
    public var meals: [Meal]
    public var note: String
    /// Что докупить, если из имеющихся продуктов цель не добирается.
    public var buy: [String]
    public init(id: UUID = UUID(), created: Date = Date(), target: Macros, meals: [Meal], note: String, buy: [String]) {
        self.id = id; self.created = created; self.target = target; self.meals = meals; self.note = note; self.buy = buy
    }
    public var macros: Macros { meals.reduce(.zero) { $0 + $1.macros } }
}

// MARK: - Пожелания к рациону

public struct PlanOptions: Codable, Hashable, Sendable {
    public var mealCount: Int
    public var firstMeal: String          // "07:00"
    public var maxMinutes: Int?           // nil — без ограничения
    public var portableLunch: Bool
    public var noOven: Bool
    public var fewDishes: Bool
    public var cookForTwoDays: Bool
    public var sweetSnack: Bool
    public var noFish: Bool
    public var noPork: Bool
    public var vegetarian: Bool
    /// Один из приёмов — протеиновый десерт (вечерний, перекус или завтрак).
    public var proteinDessert: Bool

    public init(mealCount: Int = 4, firstMeal: String = "07:00", maxMinutes: Int? = nil,
                portableLunch: Bool = false, noOven: Bool = false, fewDishes: Bool = false,
                cookForTwoDays: Bool = false, sweetSnack: Bool = false, noFish: Bool = false,
                noPork: Bool = false, vegetarian: Bool = false, proteinDessert: Bool = false) {
        self.mealCount = mealCount; self.firstMeal = firstMeal; self.maxMinutes = maxMinutes
        self.portableLunch = portableLunch; self.noOven = noOven; self.fewDishes = fewDishes
        self.cookForTwoDays = cookForTwoDays; self.sweetSnack = sweetSnack; self.noFish = noFish
        self.noPork = noPork; self.vegetarian = vegetarian; self.proteinDessert = proteinDessert
    }

    enum CodingKeys: String, CodingKey {
        case mealCount, firstMeal, maxMinutes, portableLunch, noOven, fewDishes, cookForTwoDays
        case sweetSnack, noFish, noPork, vegetarian, proteinDessert
    }

    /// Старые сохранения без новых полей читаются со значениями по умолчанию.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PlanOptions()
        mealCount = try c.decodeIfPresent(Int.self, forKey: .mealCount) ?? d.mealCount
        firstMeal = try c.decodeIfPresent(String.self, forKey: .firstMeal) ?? d.firstMeal
        maxMinutes = try c.decodeIfPresent(Int.self, forKey: .maxMinutes)
        portableLunch = try c.decodeIfPresent(Bool.self, forKey: .portableLunch) ?? false
        noOven = try c.decodeIfPresent(Bool.self, forKey: .noOven) ?? false
        fewDishes = try c.decodeIfPresent(Bool.self, forKey: .fewDishes) ?? false
        cookForTwoDays = try c.decodeIfPresent(Bool.self, forKey: .cookForTwoDays) ?? false
        sweetSnack = try c.decodeIfPresent(Bool.self, forKey: .sweetSnack) ?? false
        noFish = try c.decodeIfPresent(Bool.self, forKey: .noFish) ?? false
        noPork = try c.decodeIfPresent(Bool.self, forKey: .noPork) ?? false
        vegetarian = try c.decodeIfPresent(Bool.self, forKey: .vegetarian) ?? false
        proteinDessert = try c.decodeIfPresent(Bool.self, forKey: .proteinDessert) ?? false
    }
}
