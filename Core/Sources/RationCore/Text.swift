import Foundation

/// Фразы для шагов рецепта. Всё — в повелительном наклонении, на «ты».
public enum Say {
    public static func cap(_ s: String) -> String {
        guard let f = s.first else { return s }
        return f.uppercased() + s.dropFirst()
    }

    public static func list(_ xs: [String]) -> String {
        let a = xs.filter { !$0.isEmpty }
        switch a.count {
        case 0: return ""
        case 1: return a[0]
        default: return a.dropLast().joined(separator: ", ") + " и " + a[a.count - 1]
        }
    }

    /// «с курицей», «со сметаной», «со шпинатом».
    public static func with(_ ins: String) -> String {
        let w = Array(ins.lowercased())
        if w.count >= 2, "сзшжщ".contains(w[0]), !"аеёиоуыэюя".contains(w[1]) { return "со " + ins }
        if ins.lowercased().hasPrefix("мн") { return "со " + ins }
        return "с " + ins
    }

    static func acc(_ f: Food?) -> String { f?.words.acc ?? "" }
    static func ins(_ f: Food?) -> String { f?.words.ins ?? "" }
    static func ttl(_ f: Food?) -> String { f?.words.title ?? "" }
    static func low(_ f: Food?) -> String { ttl(f).lowercased() }

    static func cook(_ f: Food) -> Cook { f.cook ?? defaultCook(f.role) }

    static func defaultCook(_ r: Role) -> Cook {
        switch r {
        case .meat: return .chicken
        case .fish: return .fishFillet
        case .eggs: return .egg
        case .grain: return .rice
        case .pasta: return .pasta
        case .potato: return .potato
        case .legumes: return .cannedLegumes
        case .vegetable: return .freshVeg
        case .greens: return .leafy
        case .sausage: return .sausage
        case .ready: return .readyFrozen
        default: return .noCook
        }
    }

    /// Нужно ли жарить или варить этот белок.
    static func needsHeat(_ f: Food) -> Bool {
        switch cook(f) {
        case .noCook, .cannedFish, .cookedMeat: return false
        default: return true
        }
    }

    /// Подготовка белка перед жаркой: нарезка, специи.
    static func prep(_ f: Food) -> String? {
        let a = acc(f)
        switch cook(f) {
        case .chicken:
            return f.has("bone") ? "Натри \(a) солью, перцем и специями." : "Нарежь \(a) кубиками 2–3 см, посыпь солью и специями."
        case .beef, .pork: return "Нарежь \(a) тонкими полосками поперёк волокон, посоли и поперчи."
        case .liver: return "Нарежь \(a) кусочками и убери плёнки."
        case .fishFillet, .salmon: return "Обсуши \(a) бумажным полотенцем, посоли и поперчи."
        case .tofu: return "Нарежь \(a) кубиками и промокни полотенцем."
        case .shrimp: return "Если \(a) замороженные — подержи их 5 минут в холодной воде."
        case .cannedFish: return "Слей жидкость из банки и разбери \(a) вилкой на кусочки."
        case .cookedMeat: return "Сними кожу и разбери \(a) руками на кусочки."
        default: return nil
        }
    }

    /// Жарка белка на сковороде.
    static func pan(_ f: Food) -> String {
        let a = acc(f)
        switch cook(f) {
        case .chicken:
            return f.has("bone") ? "Обжарь \(a) со всех сторон 5 минут, накрой крышкой и держи ещё 15–20 минут до готовности." : "Обжарь \(a) на сильном огне 6–8 минут до золотистой корочки — внутри не должно остаться розового."
        case .groundMeat: return "Обжарь \(a) на среднем огне 7–8 минут, разбивая лопаткой на крошку."
        case .beef: return "Обжарь \(a) на сильном огне 4–6 минут, постоянно помешивая."
        case .pork: return "Обжарь \(a) 8–10 минут до полной готовности."
        case .liver: return "Обжарь \(a) по 2–3 минуты с каждой стороны — дольше не надо, иначе станет жёсткой."
        case .cookedMeat: return "Прогрей \(a) на сковороде 1–2 минуты."
        case .bacon: return "Обжарь \(a) до хруста 4–5 минут и выложи на бумажное полотенце."
        case .sausage: return "Нарежь \(a) кружочками и обжарь 3–4 минуты."
        case .fishFillet: return "Обжарь \(a) по 3–4 минуты с каждой стороны."
        case .salmon: return "Обжарь \(a) кожей вниз 4 минуты, переверни и держи ещё 2–3 минуты."
        case .shrimp: return "Обжарь \(a) 2–3 минуты, пока не станут розовыми."
        case .cannedFish: return "Добавь \(a) в самом конце, только чтобы прогреть."
        case .tofu: return "Обжарь \(a) 5–6 минут до корочки."
        case .egg: return "Взбей яйца с щепоткой соли и вылей на сковороду."
        default: return "Обжарь \(a) до готовности."
        }
    }

    /// Запекание белка в духовке.
    static func oven(_ f: Food) -> String {
        let a = acc(f)
        switch cook(f) {
        case .chicken: return f.has("bone") ? "Запекай \(a) 35–40 минут до румяной корочки." : "Запекай \(a) 20–25 минут."
        case .fishFillet, .salmon: return "Добавь \(a) на противень за 15 минут до конца."
        case .beef: return "Запекай \(a) 20–25 минут, потом дай отдохнуть 5 минут."
        case .pork: return "Запекай \(a) 25–30 минут."
        case .sausage: return "Добавь \(a) на противень за 15 минут до конца."
        case .shrimp: return "Добавь \(a) на противень за 8 минут до конца."
        case .tofu: return "Запекай \(a) 20 минут."
        default: return "Запекай \(a) до готовности."
        }
    }

    /// Гарнир: варка или приготовление по упаковке.
    static func side(_ f: Food) -> String {
        let a = acc(f)
        switch cook(f) {
        case .rice: return "Промой \(a) и вари в подсоленной воде 15–18 минут: одна часть крупы на две части воды."
        case .buckwheat: return "Промой \(a), залей водой 1:2, посоли и вари на слабом огне 15–20 минут, потом дай постоять под крышкой."
        case .quinoa: return "Промой \(a) и вари в подсоленной воде 1:2 около 15 минут."
        case .bulgur: return "Вари \(a) в подсоленной воде 1:2 10–12 минут."
        case .couscous: return "Залей \(a) кипятком 1:1,5, посоли, накрой и оставь на 5 минут, потом разрыхли вилкой."
        case .millet: return "Промой \(a) горячей водой и вари 20 минут: одна часть крупы на 2,5 части воды."
        case .barley: return "Вари \(a) 40–45 минут в воде 1:3 — быстрее, если замочить заранее."
        case .pasta: return "Отвари \(a) в подсоленной воде по времени на упаковке, обычно 8–11 минут."
        case .noodles: return "Отвари \(a) 3–5 минут и откинь на дуршлаг."
        case .potato: return "Почисть \(a), нарежь кубиками и отвари в подсоленной воде 15–18 минут."
        case .sweetPotato: return "Почисть \(a), нарежь кубиками и отвари 12–15 минут."
        case .fries: return "Запеки \(a) при 220 °C по времени на упаковке, обычно 15–20 минут."
        case .cannedLegumes: return "Откинь \(a) на дуршлаг и промой водой."
        case .lentils: return "Промой \(a) и вари 15–20 минут до мягкости."
        case .dryBeans: return "Вари \(a) 50–60 минут — лучше замочить её с вечера."
        case .dumplings: return "Опусти \(a) в кипящую подсоленную воду и вари 5–7 минут после всплытия."
        case .readyFrozen: return "Приготовь \(a) по инструкции на упаковке — в духовке или микроволновке."
        case .ready: return "Приготовь \(a) по инструкции на упаковке."
        case .frozenVeg: return "Отвари или обжарь \(a) 5–7 минут прямо из морозилки."
        default: return "Приготовь \(a) по инструкции на упаковке."
        }
    }

    /// Гарнир в духовке.
    static func roast(_ f: Food, with veg: [Food]) -> String {
        let extra = veg.isEmpty ? "" : ", \(list(veg.map { $0.words.acc })) — крупными кусками"
        switch cook(f) {
        case .fries: return "Выложи \(acc(f))\(extra) на противень."
        default: return "Нарежь \(acc(f)) дольками\(extra), смешай с маслом, солью и специями и выложи на противень."
        }
    }

    /// Подготовка овощей.
    static func vegPrep(_ v: [Food]) -> [String] {
        var out: [String] = []
        let cut = v.filter { [.freshVeg, .noCook].contains(cook($0)) }
        let leaf = v.filter { cook($0) == .leafy && !$0.has("herb") }
        let herb = v.filter { cook($0) == .leafy && $0.has("herb") }
        let frozen = v.filter { cook($0) == .frozenVeg }
        let canned = v.filter { cook($0) == .cannedVeg }
        if !cut.isEmpty { out.append("Нарежь \(list(cut.map { $0.words.acc })).") }
        if !leaf.isEmpty { out.append("Промой и обсуши \(list(leaf.map { $0.words.acc })).") }
        if !herb.isEmpty { out.append("Мелко порежь \(list(herb.map { $0.words.acc })).") }
        for f in frozen { out.append("\(cap(f.words.acc)) бери прямо из морозилки — размораживать не нужно.") }
        for f in canned { out.append("Откинь \(f.words.acc) на дуршлаг.") }
        return out
    }

    /// Овощи, которые идут в сковороду (не сырые салатные).
    static func panVeg(_ v: [Food]) -> [Food] {
        v.filter { ![.leafy].contains(cook($0)) || $0.has("cookable") }
    }

    static func spices(_ s: [Food]) -> String {
        list(s.filter { $0.role == .spice && !$0.isKind("c:salt") && !$0.isKind("c:vinegar") && !$0.isKind("c:lemon_juice") }.prefix(3).map { $0.words.acc })
    }
}
