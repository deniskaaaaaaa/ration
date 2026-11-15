import Foundation

/// Общие фразы для новых рецептов (десерты, завтраки, обеды).
enum RK {
    /// Винительный падеж: «творог», «яйца».
    static func A(_ fs: [Food?]) -> [String] { fs.compactMap { $0?.words.acc } }
    /// Творительный падеж: «творогом», «яйцами».
    static func I(_ fs: [Food?]) -> [String] { fs.compactMap { $0?.words.ins } }

    /// Есть ли среди специй блюда такая.
    static func on(_ f: Fill, _ id: String) -> Bool { f.spices.contains { $0.isKind(id) } }

    /// Названия выбранных специй в винительном падеже, в заданном порядке.
    static func spiceAcc(_ f: Fill, _ ids: [String]) -> [String] {
        ids.compactMap { id in f.spices.first(where: { $0.isKind(id) })?.words.acc }
    }

    static let sweet = ["c:sweetener", "c:honey", "c:sugar"]
    static let syrup = ["c:maple_syrup", "c:honey", "c:jam", "c:sweetener"]
    static let sour = ["c:sour_cream", "c:sour_cream_10", "c:greek_yogurt_0"]

    /// Подсластить готовое блюдо.
    static func sweeten(_ sw: Food?) -> String? {
        guard let sw = sw else { return nil }
        if sw.role == .spice { return "Подсласти \(sw.words.ins) по вкусу." }
        if sw.isKind("c:sugar") { return "Добавь сахар по вкусу." }
        return "Полей \(sw.words.ins)."
    }

    /// Фрукты или ягоды сверху.
    static func top(_ fr: Food?) -> String? {
        guard let fr = fr else { return nil }
        if fr.role == .berries { return "Добавь сверху \(fr.words.acc)\(fr.has("frozen") ? " — можно прямо замороженные" : "")." }
        if fr.has("dried") { return "Посыпь \(fr.words.ins)." }
        return "Нарежь \(fr.words.acc) и выложи сверху."
    }

    /// Фрукты или ягоды в тесто или массу.
    static func into(_ fr: Food?) -> String? {
        guard let fr = fr else { return nil }
        if fr.role == .berries { return "Вмешай \(fr.words.acc)." }
        if fr.has("dried") { return "Добавь \(fr.words.acc) и перемешай." }
        if fr.has("banana") { return "Разомни \(fr.words.acc) вилкой и вмешай." }
        return "Нарежь \(fr.words.acc) мелкими кубиками и вмешай."
    }

    /// «Подавай со сметаной и укропом».
    static func serve(_ fs: [Food?]) -> String? {
        let x = I(fs)
        return x.isEmpty ? nil : "Подавай \(Say.with(Say.list(x)))."
    }

    static func boiled(_ soft: Bool) -> String {
        soft ? "Свари яйца: 7 минут после закипания — желток останется чуть мягким."
             : "Свари яйца вкрутую: 9 минут после закипания, потом подержи в холодной воде и почисть."
    }

    /// Белок: подготовка и жарка, если нужны.
    static func protein(_ p: Food) -> [String] {
        var s: [String] = []
        let c = Say.cook(p)
        if c == .lentils || c == .dryBeans { return [Say.side(p)] }
        if let pr = Say.prep(p) { s.append(pr) }
        if Say.needsHeat(p) {
            if c != .cannedMeat { s.append("Разогрей масло в сковороде.") }
            s.append(Say.pan(p))
        }
        return s
    }

    /// Масло нужно, только если белок блюда жарится.
    static let heats: (Fill) -> Bool = { f in
        guard let p = f["p"] else { return false }
        return p.role != .eggs && Say.needsHeat(p) && Say.cook(p) != .cannedMeat
    }

    /// Мясо, которое варят в бульоне: сколько минут.
    static func brothMinutes(_ p: Food) -> String? {
        switch Say.cook(p) {
        case .beef: return "50–60 минут"
        case .pork: return "35–40 минут"
        case .chicken: return p.has("bone") ? "35–40 минут" : "20 минут"
        default: return nil
        }
    }

    /// Томатная основа: паста разводится водой, соус — просто вливается.
    static func tomatoPour(_ t: Food, water: Int) -> String {
        if t.isKind("c:tomato_paste") || t.isKind("c:ketchup") {
            return "Разведи \(t.words.acc) в \(water) мл воды"
        }
        return "Влей \(t.words.acc) и \(max(water / 2, 100)) мл воды"
    }
}
