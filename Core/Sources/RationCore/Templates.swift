import Foundation

// MARK: - Описание шаблона блюда

/// Место в блюде, которое занимает один продукт из запасов.
public struct SlotSpec {
    public var key: String
    public var roles: Set<Role>
    public var required: Bool
    public var anyTags: [String]
    public var noTags: [String]
    public var cooks: Set<Cook>?
    public var noCooks: Set<Cook>
    public var range: ClosedRange<Double>?
    /// Главный продукт блюда: по нему следим, чтобы день не повторялся.
    public var main: Bool
}

/// Продукт из «всегда есть дома»: масло, соус, мука. Первый найденный из списка вариантов.
public struct ExtraSpec {
    public var key: String
    public var alts: [(String, ClosedRange<Double>)]
    public var required: Bool
    /// Брать, только если условие выполнено для уже выбранных продуктов (например, масло — только если что-то жарим).
    public var when: ((Fill) -> Bool)?
}

/// Набор продуктов, выбранных для конкретного блюда.
public struct Fill {
    public var foods: [String: Food] = [:]
    public var spices: [Food] = []
    public init() {}
    public subscript(_ k: String) -> Food? { foods[k] }
    public func all(_ keys: [String]) -> [Food] { keys.compactMap { foods[$0] } }
}

public struct DishTemplate {
    public let id: String
    public let kinds: Set<MealKind>
    public let slots: [SlotSpec]
    public let extras: [ExtraSpec]
    public let spices: [String]
    public let minutes: Int
    public let oven: Bool
    public let portable: Bool
    public let onePan: Bool
    public let sweet: Bool
    /// Протеиновый десерт (для пожелания «Протеиновый десерт»).
    public let dessert: Bool
    public let weight: Double
    public let check: (Fill) -> Bool
    public let title: (Fill) -> String
    public let steps: (Fill) -> [String]
    public let tip: (Fill) -> String
}

private func S(_ key: String, _ roles: [Role], req: Bool = true, tags: [String] = [], no: [String] = [],
               cooks: [Cook]? = nil, noCooks: [Cook] = [], range: ClosedRange<Double>? = nil, main: Bool = false) -> SlotSpec {
    SlotSpec(key: key, roles: Set(roles), required: req, anyTags: tags, noTags: no,
             cooks: cooks.map { Set($0) }, noCooks: Set(noCooks), range: range, main: main)
}

private func X(_ key: String, _ kinds: [String], _ range: ClosedRange<Double>, req: Bool = false,
               when: ((Fill) -> Bool)? = nil) -> ExtraSpec {
    ExtraSpec(key: key, alts: kinds.map { ($0, range) }, required: req, when: when)
}

private func XA(_ key: String, _ alts: [(String, ClosedRange<Double>)], req: Bool = false) -> ExtraSpec {
    ExtraSpec(key: key, alts: alts, required: req, when: nil)
}

/// Масло нужно, только если белок блюда жарится.
private let heatsProtein: (Fill) -> Bool = { f in
    guard let p = f["p"] else { return false }
    return p.role != .eggs && Say.needsHeat(p) && Say.cook(p) != .cannedMeat
}

private func T(_ id: String, _ kinds: [MealKind], minutes: Int, slots: [SlotSpec], extras: [ExtraSpec] = [],
               spices: [String] = [], oven: Bool = false, portable: Bool = false, onePan: Bool = false,
               sweet: Bool = false, dessert: Bool = false, weight: Double = 1,
               check: @escaping (Fill) -> Bool = { _ in true },
               title: @escaping (Fill) -> String,
               steps: @escaping (Fill) -> [String],
               tip: @escaping (Fill) -> String = { _ in "" }) -> DishTemplate {
    DishTemplate(id: id, kinds: Set(kinds), slots: slots, extras: extras, spices: spices, minutes: minutes,
                 oven: oven, portable: portable, onePan: onePan, sweet: sweet || dessert, dessert: dessert, weight: weight,
                 check: check, title: title, steps: steps, tip: tip)
}

// MARK: - Шаблоны

public enum Templates {
    public static let all: [DishTemplate] = build()

    public static func byID(_ id: String) -> DishTemplate? { all.first { $0.id == id } }

    static let fat = ["c:sunflower_oil", "c:olive_oil", "c:butter"]
    static let meatSpice = ["c:salt", "c:pepper", "c:paprika", "c:garlic_dry", "c:chicken_spice"]
    static let tomato: [(String, ClosedRange<Double>)] = [("c:marinara", 80...160), ("c:tomato_paste", 15...40)]

    private static func fruitStep(_ fr: Food?) -> String? {
        guard let fr = fr else { return nil }
        if fr.role == .berries { return "Добавь \(Say.acc(fr)) сверху\(fr.has("frozen") ? " — можно прямо замороженные" : "")." }
        return "Нарежь \(Say.acc(fr)) и выложи сверху."
    }

    private static func sweetStep(_ sw: Food?) -> String? {
        guard let sw = sw else { return nil }
        if sw.isKind("c:sugar") { return "Добавь сахар по вкусу." }
        return "Полей \(Say.ins(sw))."
    }

    /// Белок: подготовка и жарка, если нужны.
    private static func proteinSteps(_ p: Food, panIntro: Bool = true) -> [String] {
        var s: [String] = []
        let c = Say.cook(p)
        if c == .lentils || c == .dryBeans { return [Say.side(p)] }
        if let pr = Say.prep(p) { s.append(pr) }
        if Say.needsHeat(p) {
            if panIntro { s.append("Разогрей масло в сковороде.") }
            s.append(Say.pan(p))
        }
        return s
    }

    private static func boiledEggs(_ soft: Bool) -> String {
        soft ? "Свари яйца: 7 минут после закипания — желток останется чуть мягким."
             : "Свари яйца вкрутую: 9 минут после закипания, потом подержи в холодной воде и почисть."
    }

    private static func build() -> [DishTemplate] {
        var t: [DishTemplate] = []

        // ───────────── Завтраки ─────────────

        t.append(T("omelet", [.breakfast, .main], minutes: 12,
            slots: [S("e", [.eggs], range: 100...250, main: true),
                    S("v", [.vegetable], req: false, no: ["fatty", "raw"]),
                    S("g", [.greens], req: false, tags: ["cookable"]),
                    S("c", [.cheese], req: false, no: ["spread"], range: 15...40),
                    S("b", [.bread], req: false, range: 25...70)],
            extras: [X("fat", fat, 4...8)], spices: ["c:salt", "c:pepper", "c:italian_herbs"], onePan: true,
            title: { f in
                let add = f.all(["v", "g", "c"]).map { $0.words.ins }
                return "Омлет" + (add.isEmpty ? "" : " " + Say.with(Say.list(add)))
            },
            steps: { f in
                var s: [String] = []
                let veg = f.all(["v", "g"])
                s += Say.vegPrep(veg)
                if veg.isEmpty { s.append("Разогрей сковороду с маслом на среднем огне.") }
                else { s.append("Разогрей сковороду с маслом и обжарь \(Say.list(veg.map { $0.words.acc })) 3–4 минуты.") }
                s.append("Взбей яйца вилкой с щепоткой соли и перца и вылей на сковороду.")
                s.append("Накрой крышкой и держи на среднем огне 4–5 минут, пока омлет не схватится.")
                if let c = f["c"] { s.append("За минуту до готовности посыпь \(Say.ins(c)).") }
                if let b = f["b"] { s.append("Подавай \(Say.with(Say.ins(b))).") }
                return s
            },
            tip: { _ in "Омлет получится пышнее, если взбить яйца с ложкой воды или молока." }))

        t.append(T("porridge", [.breakfast], minutes: 10,
            slots: [S("o", [.oats], tags: ["oats"], range: 40...110, main: true),
                    S("m", [.milk], req: false, no: ["rtd", "kefir"], range: 150...300),
                    S("fr", [.fruit, .berries], req: false, no: ["dried"]),
                    S("n", [.nuts], req: false, range: 10...25)],
            extras: [X("sw", ["c:honey", "c:jam", "c:sugar"], 5...15), X("but", ["c:butter"], 3...6)],
            spices: ["c:cinnamon", "c:salt"], sweet: true,
            title: { f in
                var s = "Овсянка"
                if let m = f["m"] { s += " на \(Say.ins(m))" }
                if let fr = f["fr"] { s += " " + Say.with(Say.ins(fr)) }
                else if let n = f["n"] { s += " " + Say.with(Say.ins(n)) }
                return s
            },
            steps: { f in
                guard let o = f["o"] else { return [] }
                var s: [String] = []
                s.append("Залей \(Say.acc(o)) \(f["m"].map { Say.ins($0) } ?? "водой") — жидкости примерно в 2,5 раза больше хлопьев — и доведи до кипения.")
                s.append("Вари на слабом огне 4–5 минут, помешивая, и добавь щепотку соли.")
                if let b = f["but"] { s.append("Положи в готовую кашу \(Say.acc(b)).") }
                if let x = fruitStep(f["fr"]) { s.append(x) }
                if let n = f["n"] { s.append("Посыпь \(Say.ins(n)).") }
                if let x = sweetStep(f["sw"]) { s.append(x) }
                if f.spices.contains(where: { $0.isKind("c:cinnamon") }) { s.append("Посыпь корицей.") }
                return s
            },
            tip: { _ in "Можно сварить в микроволновке: 2 минуты на полной мощности, перемешать и ещё минуту." }))

        t.append(T("cottage_bowl", [.breakfast, .snack, .evening], minutes: 3,
            slots: [S("y", [.cottage, .yogurt], range: 150...350, main: true),
                    S("fr", [.fruit, .berries], req: false),
                    S("n", [.nuts], req: false, range: 10...25)],
            extras: [X("sw", ["c:honey", "c:jam"], 5...15)], sweet: true, weight: 1.3,
            title: { f in
                guard let y = f["y"] else { return "Творог" }
                var add: [String] = []
                if let fr = f["fr"] { add.append(Say.ins(fr)) }
                if let n = f["n"] { add.append(Say.ins(n)) }
                if add.isEmpty, let sw = f["sw"] { add.append(Say.ins(sw)) }
                return Say.ttl(y) + (add.isEmpty ? "" : " " + Say.with(Say.list(add)))
            },
            steps: { f in
                guard let y = f["y"] else { return [] }
                var s = ["Выложи \(Say.acc(y)) в миску."]
                if let x = fruitStep(f["fr"]) { s.append(x) }
                if let n = f["n"] { s.append("Посыпь \(Say.ins(n)).") }
                if let x = sweetStep(f["sw"]) { s.append(x) }
                return s
            },
            tip: { f in f["y"]?.role == .cottage ? "Если творог суховат, добавь пару ложек молока и взбей вилкой." : "" }))

        t.append(T("syrniki", [.breakfast], minutes: 25,
            slots: [S("y", [.cottage], no: ["grainy"], range: 180...300, main: true),
                    S("e", [.eggs], no: ["whites"], range: 50...100),
                    S("fr", [.berries, .fruit], req: false, no: ["dried"]),
                    S("sc", [.sauce, .yogurt], req: false, tags: ["dairy", "greek"], range: 30...80)],
            extras: [X("fl", ["c:flour"], 20...40, req: true), X("su", ["c:sugar", "c:honey"], 5...15), X("fat", fat, 6...12)],
            spices: ["c:salt"], sweet: true,
            title: { f in
                if let sc = f["sc"] { return "Сырники " + Say.with(Say.ins(sc)) }
                if let fr = f["fr"] { return "Сырники " + Say.with(Say.ins(fr)) }
                return "Сырники"
            },
            steps: { f in
                guard let y = f["y"] else { return [] }
                var s: [String] = []
                s.append("Разомни \(Say.acc(y)) вилкой и добавь яйца, муку и щепотку соли\(f["su"].map { " — и \(Say.acc($0))" } ?? "").")
                s.append("Сформируй мокрыми руками 6–8 небольших сырников и обваляй их в муке.")
                s.append("Обжарь на масле на среднем огне по 3–4 минуты с каждой стороны, потом накрой крышкой ещё на 2 минуты.")
                if let sc = f["sc"] { s.append("Подавай \(Say.with(Say.ins(sc))).") }
                if let fr = f["fr"] { s.append(fr.role == .berries ? "Добавь \(Say.acc(fr))." : "Нарежь \(Say.acc(fr)) и подай рядом.") }
                return s
            },
            tip: { _ in "Если творог влажный, добавь ещё ложку муки — сырники не будут растекаться." }))

        t.append(T("eggs_toast", [.breakfast], minutes: 10,
            slots: [S("e", [.eggs], no: ["whites"], range: 100...200, main: true),
                    S("b", [.bread], tags: ["slice", "bun", "crisp"], range: 30...100),
                    S("s", [.sausage], req: false, tags: ["deli", "sliced"], range: 30...80),
                    S("c", [.cheese], req: false, range: 15...40),
                    S("v", [.vegetable], req: false, tags: ["salad", "raw"])],
            extras: [X("fat", fat, 4...8)], spices: ["c:salt", "c:pepper"], onePan: true,
            title: { f in
                let add = ["тостами"] + f.all(["s", "c", "v"]).map { $0.words.ins }
                return "Яичница " + Say.with(Say.list(add))
            },
            steps: { f in
                guard let b = f["b"] else { return [] }
                var s = ["Разогрей сковороду с маслом, разбей яйца и посоли.",
                         "Жарь 3–4 минуты на среднем огне — под крышкой, если любишь плотный желток.",
                         "Подсуши \(Say.acc(b)) в тостере или на сухой сковороде."]
                if let x = f["s"] { s.append("Обжарь \(Say.acc(x)) рядом с яйцами 1–2 минуты.") }
                if let c = f["c"] { s.append("Положи \(Say.acc(c)) на горячие тосты.") }
                if let v = f["v"] { s += Say.vegPrep([v]); s.append("Подавай \(Say.with(Say.ins(v))).") }
                return s
            }))

        t.append(T("breakfast_wrap", [.breakfast, .main], minutes: 12,
            slots: [S("b", [.bread], tags: ["wrap"], range: 45...90),
                    S("e", [.eggs], range: 100...200, main: true),
                    S("c", [.cheese], req: false, no: ["spread"], range: 15...40),
                    S("s", [.sausage, .meat], req: false, cooks: [.sausage, .bacon, .noCook, .cookedMeat], range: 30...90),
                    S("v", [.vegetable, .greens], req: false, no: ["fatty", "herb"])],
            extras: [X("sc", ["c:salsa", "c:ketchup", "c:sour_cream"], 10...30), X("fat", fat, 3...6)],
            spices: ["c:salt", "c:pepper"], portable: true, onePan: true,
            title: { f in
                let add = ["яйцом"] + f.all(["s", "c"]).map { $0.words.ins }
                return "Ролл " + Say.with(Say.list(add))
            },
            steps: { f in
                guard let b = f["b"] else { return [] }
                var s: [String] = []
                if let v = f["v"] { s += Say.vegPrep([v]) }
                s.append("Разогрей сковороду с маслом.")
                if let x = f["s"], Say.needsHeat(x) { s.append(Say.pan(x)) }
                if let v = f["v"], Say.cook(v) != .leafy || v.has("cookable") { s.append("Добавь \(Say.acc(v)) и жарь 2 минуты.") }
                s.append("Влей взбитые яйца и помешивай 2–3 минуты до мягкой болтуньи.")
                s.append("Разогрей \(Say.acc(b)) на сухой сковороде по 20 секунд с каждой стороны.")
                var fillers: [String] = []
                if let c = f["c"] { fillers.append("посыпь \(Say.ins(c))") }
                if let sc = f["sc"] { fillers.append("добавь \(Say.acc(sc))") }
                s.append("Выложи начинку\(fillers.isEmpty ? "" : ", " + fillers.joined(separator: ", ")) и плотно сверни.")
                return s
            },
            tip: { _ in "Заверни в фольгу — удобно есть в дороге." }))

        t.append(T("yogurt_bowl", [.breakfast, .snack, .evening], minutes: 3,
            slots: [S("y", [.yogurt], range: 150...300, main: true),
                    S("o", [.oats], req: false, no: ["semolina", "bran"], range: 20...60),
                    S("fr", [.berries, .fruit], req: false),
                    S("n", [.nuts], req: false, range: 10...20)],
            extras: [X("sw", ["c:honey", "c:jam"], 5...15)], sweet: true,
            title: { f in
                guard let y = f["y"] else { return "Йогурт" }
                let add = f.all(["o", "fr"]).map { $0.words.ins }
                return Say.ttl(y) + (add.isEmpty ? "" : " " + Say.with(Say.list(add)))
            },
            steps: { f in
                guard let y = f["y"] else { return [] }
                var s = ["Выложи \(Say.acc(y)) в миску или банку."]
                if let o = f["o"] { s.append("Добавь \(Say.acc(o)).") }
                if let x = fruitStep(f["fr"]) { s.append(x) }
                if let n = f["n"] { s.append("Посыпь \(Say.ins(n)).") }
                if let x = sweetStep(f["sw"]) { s.append(x) }
                return s
            },
            tip: { _ in "Собери с вечера в банке — утром останется только взять." }))

        t.append(T("shake", [.breakfast, .snack, .evening], minutes: 3,
            slots: [S("pr", [.protein], range: 25...50, main: true),
                    S("m", [.milk], req: false, range: 200...350),
                    S("fr", [.fruit, .berries], req: false, no: ["dried"], range: 80...150),
                    S("o", [.oats], req: false, tags: ["oats"], range: 20...50),
                    S("n", [.nuts], req: false, tags: ["spread"], range: 10...20)],
            weight: 1.2,
            title: { f in "Протеиновый коктейль" + (f["fr"].map { " " + Say.with(Say.ins($0)) } ?? "") },
            steps: { f in
                let items = f.all(["pr", "m", "fr", "o", "n"]).map { $0.words.acc }
                var s = ["Положи в блендер \(Say.list(items))\(f["m"] == nil ? " и залей 300 мл холодной воды" : "")."]
                s.append("Взбей 30–40 секунд до однородности.")
                if f["fr"] == nil && f["o"] == nil { s.append("Без блендера просто встряхни в шейкере 20 секунд.") }
                return s
            }))

        t.append(T("smoothie", [.breakfast, .snack], minutes: 5,
            slots: [S("m", [.milk, .yogurt], range: 200...350, main: true),
                    S("fr", [.fruit, .berries], no: ["dried"], range: 100...200),
                    S("o", [.oats], req: false, tags: ["oats"], range: 20...40),
                    S("n", [.nuts], req: false, range: 10...20)],
            extras: [X("sw", ["c:honey"], 5...12)], sweet: true,
            title: { f in "Смузи " + Say.with(f["fr"].map { Say.ins($0) } ?? "фруктами") },
            steps: { f in
                let items = f.all(["m", "fr", "o", "n", "sw"]).map { $0.words.acc }
                return ["Положи в блендер \(Say.list(items)).", "Взбей до однородности 40–60 секунд."]
            },
            tip: { f in f["fr"]?.has("frozen") == true ? "С замороженными ягодами смузи сразу получится холодным." : "" }))

        t.append(T("sandwich", [.breakfast, .snack], minutes: 5,
            slots: [S("b", [.bread], tags: ["slice", "bun", "crisp", "pocket"], range: 50...120),
                    S("s", [.sausage, .cheese, .fish, .meat], no: ["spread"], cooks: [.noCook, .cannedFish, .cookedMeat], range: 30...120, main: true),
                    S("c", [.cheese], req: false, range: 15...40),
                    S("v", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf"], no: ["herb"])],
            extras: [X("sc", ["c:mustard", "c:mayo", "c:cream_cheese"], 5...15)],
            portable: true,
            title: { f in "Бутерброды " + Say.with(Say.list(f.all(["s", "c", "v"]).map { $0.words.ins })) },
            steps: { f in
                guard let b = f["b"], let x = f["s"] else { return [] }
                var s: [String] = b.has("crisp") ? [] : ["Подсуши \(Say.acc(b)) в тостере или на сухой сковороде."]
                if let sc = f["sc"] { s.append("Смажь \(Say.ins(sc)).") }
                if let pr = Say.prep(x) { s.append(pr) }
                if let v = f["v"] { s += Say.vegPrep([v]) }
                s.append("Выложи сверху \(Say.list(f.all(["s", "c", "v"]).map { $0.words.acc })).")
                return s
            }))

        t.append(T("grain_egg", [.breakfast, .main], minutes: 20,
            slots: [S("s", [.grain, .pasta, .potato], noCooks: [.fries, .barley], range: 40...100),
                    S("e", [.eggs], no: ["whites"], range: 50...150, main: true),
                    S("v", [.vegetable], req: false, tags: ["salad", "raw", "tomato"]),
                    S("c", [.cheese], req: false, range: 10...30)],
            extras: [X("but", ["c:butter", "c:sunflower_oil"], 4...8)], spices: ["c:salt", "c:pepper"],
            title: { f in
                guard let s = f["s"] else { return "Гарнир с яйцом" }
                return Say.ttl(s) + " " + Say.with(Say.list(["яйцом"] + f.all(["v"]).map { $0.words.ins }))
            },
            steps: { f in
                guard let side = f["s"] else { return [] }
                var s = [Say.side(side), boiledEggs(true)]
                if let b = f["but"] { s.append("Положи в горячий гарнир \(Say.acc(b)).") }
                if let c = f["c"] { s.append("Посыпь \(Say.ins(c)).") }
                if let v = f["v"] { s += Say.vegPrep([v]); s.append("Подавай \(Say.with(Say.ins(v))).") }
                return s
            }))

        // ───────────── Обед и ужин ─────────────

        t.append(T("pan_side", [.main], minutes: 30,
            slots: [S("p", [.meat, .fish, .legumes, .sausage], noCooks: [.cannedLegumes, .lentils, .dryBeans, .noCook, .cannedFish], main: true),
                    S("s", [.grain, .pasta, .potato], noCooks: [.fries]),
                    S("v", [.vegetable], req: false, no: ["fatty", "raw"]),
                    S("v2", [.vegetable], req: false, no: ["fatty", "raw"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("fat", fat, 6...12), X("sc", ["c:soy_sauce", "c:sour_cream", "c:bbq_sauce"], 10...30)],
            spices: meatSpice, portable: true, weight: 1.6,
            title: { f in
                guard let p = f["p"], let s = f["s"] else { return "Горячее" }
                let add = [p.words.ins] + f.all(["v"]).map { $0.words.ins }
                return Say.ttl(s) + " " + Say.with(Say.list(add))
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = [Say.side(side)]
                if let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append("Разогрей масло в сковороде.")
                s.append(Say.pan(p))
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь ещё 5–6 минут, помешивая.") }
                var add = f.spices.filter { !$0.isKind("c:salt") && !$0.isKind("c:pepper") }.prefix(3).map { $0.words.acc }
                if let sc = f["sc"] { add.append(sc.words.acc) }
                s.append("Посоли, поперчи\(add.isEmpty ? "" : " и добавь " + Say.list(add)).")
                if let h = f["h"] { s.append("Посыпь \(Say.ins(h)).") }
                s.append("Подавай \(Say.with(Say.ins(side))).")
                return s
            },
            tip: { _ in "Разложи по контейнерам — хорошо едется и тёплым, и холодным." }))

        t.append(T("oven_tray", [.main], minutes: 45,
            slots: [S("p", [.meat, .fish, .sausage], noCooks: [.groundMeat, .cannedFish, .cookedMeat, .liver, .noCook, .bacon], main: true),
                    S("s", [.potato]),
                    S("v", [.vegetable], req: false, tags: ["stew", "pepper", "onion", "carrot", "green", "mushroom", "tomato"], no: ["raw", "fatty"]),
                    S("v2", [.vegetable], req: false, tags: ["stew", "pepper", "onion", "carrot", "green", "mushroom", "tomato"], no: ["raw", "fatty"])],
            extras: [X("fat", ["c:olive_oil", "c:sunflower_oil"], 8...15)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:garlic_dry", "c:italian_herbs"], oven: true, onePan: true, weight: 1.2,
            title: { f in
                guard let p = f["p"], let s = f["s"] else { return "Ужин из духовки" }
                return Say.ttl(p) + " " + Say.with(Say.ins(s)) + " в духовке"
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = ["Разогрей духовку до 200 °C."]
                s.append(Say.roast(side, with: f.all(["v", "v2"])))
                if let pr = Say.prep(p) { s.append(pr) }
                let late: [Cook] = [.fishFillet, .salmon, .shrimp, .sausage]
                if late.contains(Say.cook(p)) {
                    s.append("Запекай гарнир 20 минут.")
                    s.append(Say.oven(p))
                } else {
                    s.append("Выложи \(Say.acc(p)) на противень рядом с гарниром.")
                    s.append(Say.oven(p))
                    s.append("В середине перемешай гарнир.")
                }
                s.append("Проверь готовность: \(Say.acc(side)) должен легко протыкаться вилкой.")
                return s
            },
            tip: { _ in "Застели противень пергаментом — мыть почти ничего не придётся." }))

        t.append(T("bolognese", [.main], minutes: 30,
            slots: [S("p", [.meat], tags: ["ground"], main: true),
                    S("s", [.pasta]),
                    S("v", [.vegetable], req: false, tags: ["onion", "carrot", "pepper", "mushroom", "stew"]),
                    S("c", [.cheese], req: false, range: 10...30)],
            extras: [XA("t", tomato, req: true), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:oregano", "c:basil", "c:garlic_dry", "c:italian_herbs"], portable: true, weight: 1.3,
            title: { f in "Паста " + Say.with(f["p"].map { Say.ins($0) } ?? "фаршем") + " в томатном соусе" },
            steps: { f in
                guard let p = f["p"], let side = f["s"], let tm = f["t"] else { return [] }
                var s = [Say.side(side)]
                if let v = f["v"] {
                    s += Say.vegPrep([v])
                    s.append("Разогрей масло и обжарь \(Say.acc(v)) 3–4 минуты.")
                } else { s.append("Разогрей масло в сковороде.") }
                s.append(Say.pan(p))
                let sp = Say.spices(f.spices)
                if tm.isKind("c:tomato_paste") {
                    s.append("Добавь \(Say.acc(tm)), 100 мл воды\(sp.isEmpty ? "" : " и \(sp)") и туши под крышкой 8–10 минут.")
                } else {
                    s.append("Влей \(Say.acc(tm))\(sp.isEmpty ? "" : ", добавь \(sp)") и туши под крышкой 8–10 минут.")
                }
                s.append("Смешай соус \(Say.with(Say.ins(side))) прямо в сковороде.")
                if let c = f["c"] { s.append("Посыпь \(Say.ins(c)) при подаче.") }
                return s
            }))

        t.append(T("tuna_pasta", [.main], minutes: 20,
            slots: [S("p", [.fish], tags: ["canned"], main: true),
                    S("s", [.pasta]),
                    S("v", [.vegetable], req: false, tags: ["tomato", "onion", "corn", "peas", "pepper"]),
                    S("c", [.cheese], req: false, range: 10...30)],
            extras: [XA("t", [("c:marinara", 60...120), ("c:tomato_paste", 15...30)]), X("fat", ["c:olive_oil", "c:sunflower_oil"], 5...10)],
            spices: ["c:salt", "c:pepper", "c:oregano", "c:garlic_dry", "c:basil"], portable: true,
            title: { f in
                guard let p = f["p"] else { return "Паста с рыбой" }
                return "Паста " + Say.with(Say.list([p.words.ins] + f.all(["v"]).map { $0.words.ins }))
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = [Say.side(side)]
                if let pr = Say.prep(p) { s.append(pr) }
                if let v = f["v"] {
                    s += Say.vegPrep([v])
                    s.append("Разогрей масло и обжарь \(Say.acc(v)) 3–4 минуты.")
                } else {
                    s.append("Разогрей масло в сковороде.")
                }
                if let tm = f["t"] { s.append("Добавь \(Say.acc(tm))\(tm.isKind("c:tomato_paste") ? " и немного воды из-под макарон" : "") и прогрей 3 минуты.") }
                s.append("Добавь \(Say.list([p.words.acc] + Say.spiceList(f.spices))), перемешай \(Say.with(Say.ins(side))) и прогрей минуту.")
                if let c = f["c"] { s.append("Посыпь \(Say.ins(c)).") }
                return s
            }))

        t.append(T("buckwheat_merchant", [.main], minutes: 35,
            slots: [S("s", [.grain], tags: ["buckwheat"], range: 50...110),
                    S("p", [.meat], no: ["bone", "cooked"], noCooks: [.liver], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion", "carrot"]),
                    S("v2", [.vegetable], req: false, tags: ["onion", "carrot", "pepper", "mushroom"])],
            extras: [X("t", ["c:tomato_paste"], 10...25), X("fat", fat, 6...12)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:bay_leaf"], portable: true, onePan: true, weight: 1.3,
            title: { f in "Гречка по-купечески " + Say.with(f["p"].map { Say.ins($0) } ?? "мясом") },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s: [String] = []
                if let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append("Разогрей масло в глубокой сковороде или кастрюле.")
                s.append(Say.pan(p))
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь ещё 3–4 минуты.") }
                s.append("Всыпь промытую \(Say.acc(side))\(f["t"].map { ", добавь \(Say.acc($0))" } ?? ""), залей водой в 2 раза больше крупы и посоли.")
                s.append("Накрой крышкой и туши на слабом огне 20 минут, пока вода не впитается.")
                s.append("Дай постоять 5 минут и перемешай.")
                return s
            }))

        t.append(T("plov", [.main], minutes: 50,
            slots: [S("s", [.grain], tags: ["rice", "bulgur"], range: 60...110),
                    S("p", [.meat], no: ["bone", "cooked", "ground"], noCooks: [.liver], main: true),
                    S("v", [.vegetable], req: false, tags: ["carrot"]),
                    S("v2", [.vegetable], req: false, tags: ["onion"])],
            extras: [X("fat", fat, 8...15)],
            spices: ["c:salt", "c:cumin", "c:turmeric", "c:paprika", "c:garlic"], portable: true, onePan: true,
            title: { f in "Плов " + Say.with(f["p"].map { Say.ins($0) } ?? "мясом") },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s: [String] = []
                if let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "v2"])
                if !veg.isEmpty { s.append("Нарежь \(Say.list(veg.map { $0.words.acc })) соломкой.") }
                s.append("Разогрей масло в казане или толстостенной кастрюле и обжарь \(Say.acc(p)) 6–7 минут.")
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь 5 минут до мягкости.") }
                let sp = Say.spices(f.spices)
                s.append("Посоли\(sp.isEmpty ? "" : ", добавь \(sp)"), залей водой вровень с мясом и туши 15 минут.")
                s.append("Всыпь промытый \(Say.acc(side)) ровным слоем и долей воды на 1,5 см выше крупы.")
                s.append("Вари без крышки, пока вода не впитается, затем накрой и держи на минимальном огне 15–20 минут.")
                s.append("Перемешай перед подачей.")
                return s
            }))

        t.append(T("bowl", [.main], minutes: 25,
            slots: [S("s", [.grain, .pasta, .potato], noCooks: [.fries, .barley], range: 50...120),
                    S("p", [.meat, .fish, .eggs, .legumes, .sausage], noCooks: [.liver, .bacon], main: true),
                    S("v", [.vegetable], req: false, tags: ["salad", "raw", "corn"]),
                    S("v2", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf", "fatty", "corn"], no: ["herb"])],
            extras: [X("sc", ["c:soy_sauce", "c:sour_cream", "c:salsa", "c:mayo"], 10...30), X("fat", ["c:olive_oil", "c:sunflower_oil"], 5...10, when: heatsProtein)],
            spices: ["c:salt", "c:pepper", "c:paprika"], portable: true, weight: 1.2,
            title: { f in
                guard let p = f["p"], let s = f["s"] else { return "Боул" }
                return "Боул " + Say.with(p.words.ins) + " и " + s.words.ins
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = [Say.side(side)]
                if p.role == .eggs { s.append(boiledEggs(false)) }
                else { s += proteinSteps(p) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append("Собери в миске: \(Say.list(([side, p] + veg).map { $0.words.acc })).")
                if let sc = f["sc"] { s.append("Полей \(Say.ins(sc)) и посыпь перцем.") }
                return s
            }))

        t.append(T("salad", [.main], minutes: 20,
            slots: [S("g", [.greens, .vegetable], tags: ["leaf", "salad", "raw"], no: ["herb", "fatty"], range: 80...200),
                    S("v", [.vegetable], req: false, tags: ["salad", "raw", "corn"]),
                    S("p", [.meat, .fish, .eggs, .legumes, .cheese], no: ["spread"], noCooks: [.liver, .bacon, .groundMeat], main: true),
                    S("c", [.cheese], req: false, tags: ["salad"], range: 20...50),
                    S("b", [.bread], req: false, tags: ["crisp", "pocket", "slice"], range: 20...60)],
            extras: [XA("dr", [("c:olive_oil", 8...15), ("c:sunflower_oil", 8...15), ("c:sour_cream", 20...40), ("c:mayo", 10...20)], req: true),
                     X("fat", fat, 4...8, when: heatsProtein)],
            spices: ["c:salt", "c:pepper", "c:lemon_juice"], portable: true,
            title: { f in
                guard let p = f["p"] else { return "Салат" }
                return "Салат " + Say.with(Say.list([p.words.ins] + f.all(["c"]).map { $0.words.ins }))
            },
            steps: { f in
                guard let p = f["p"], let g = f["g"], let dr = f["dr"] else { return [] }
                var s: [String] = []
                if p.role == .eggs { s.append(boiledEggs(false)) }
                else if Say.cook(p) == .lentils || Say.cook(p) == .dryBeans { s.append(Say.side(p)) }
                else if Say.needsHeat(p) {
                    s += proteinSteps(p)
                    s.append("Дай немного остыть и нарежь.")
                } else if let pr = Say.prep(p) { s.append(pr) }
                s += Say.vegPrep(f.all(["g", "v"]))
                s.append("Смешай в миске \(Say.list(f.all(["g", "v", "p", "c"]).map { $0.words.acc })).")
                let lemon = f.spices.contains { $0.isKind("c:lemon_juice") }
                s.append("Заправь \(Say.ins(dr)), посоли и поперчи\(lemon ? ", сбрызни лимонным соком" : "").")
                if let b = f["b"] { s.append("Подавай \(Say.with(Say.ins(b))).") }
                _ = g
                return s
            },
            tip: { _ in "С собой бери заправку отдельно — салат не потечёт." }))

        t.append(T("soup", [.main], minutes: 45,
            slots: [S("p", [.meat, .sausage, .legumes], no: ["cooked"], noCooks: [.liver, .bacon, .tofu, .groundMeat], main: true),
                    S("s", [.potato, .pasta, .grain], noCooks: [.fries, .barley, .couscous], range: 40...250),
                    S("v", [.vegetable], req: false, tags: ["carrot", "onion"]),
                    S("v2", [.vegetable], req: false, no: ["raw", "fatty"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:garlic_dry"], weight: 0.9,
            title: { f in
                guard let p = f["p"], let s = f["s"] else { return "Суп" }
                return "Суп " + Say.with(p.words.ins) + " и " + s.words.ins
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s: [String] = []
                switch Say.cook(p) {
                case .beef:
                    s.append("Залей \(Say.acc(p)) 1,5 литрами холодной воды, доведи до кипения, сними пену и вари 50–60 минут.")
                    s.append("Достань мясо, нарежь кусочками и верни в кастрюлю.")
                case .chicken, .pork:
                    s.append("Залей \(Say.acc(p)) 1,5 литрами холодной воды, доведи до кипения, сними пену и вари 20 минут.")
                    s.append("Достань мясо, нарежь кусочками и верни в кастрюлю.")
                case .lentils:
                    s.append("Промой \(Say.acc(p)), залей 1,5 литрами воды и вари 15 минут.")
                default:
                    s.append("Доведи до кипения 1,5 литра воды.")
                }
                switch side.role {
                case .potato: s.append("Почисть \(Say.acc(side)), нарежь кубиками и опусти в кастрюлю.")
                case .pasta: s.append("Отложи \(Say.acc(side)) — их нужно добавить за 7 минут до конца.")
                default: s.append("Промой \(Say.acc(side)) и опусти в кастрюлю.")
                }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) в кастрюлю.") }
                if p.role == .sausage { s.append("Нарежь \(Say.acc(p)) и добавь в суп.") }
                if p.role == .legumes && Say.cook(p) == .cannedLegumes { s.append("Откинь \(Say.acc(p)) на дуршлаг и добавь в суп.") }
                let sp = Say.spices(f.spices)
                s.append("Посоли\(sp.isEmpty ? "" : ", добавь \(sp)") и вари ещё 15 минут, пока всё не станет мягким.")
                if side.role == .pasta { s.append("Добавь \(Say.acc(side)) и вари до готовности.") }
                if let h = f["h"] { s.append("Посыпь \(Say.ins(h)) перед подачей.") }
                return s
            },
            tip: { _ in "Суп хранится в холодильнике до 3 дней, а на второй день он даже вкуснее." }))

        t.append(T("wrap", [.main], minutes: 20,
            slots: [S("b", [.bread], tags: ["wrap", "pocket"], range: 45...120),
                    S("p", [.meat, .fish, .legumes, .sausage], noCooks: [.liver, .lentils, .dryBeans], main: true),
                    S("v", [.vegetable], req: false, tags: ["tomato", "salad", "raw", "pepper"]),
                    S("v2", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf"], no: ["herb"]),
                    S("c", [.cheese], req: false, no: ["spread"], range: 15...40)],
            extras: [X("sc", ["c:mayo", "c:sour_cream", "c:ketchup", "c:salsa", "c:bbq_sauce"], 10...30), X("fat", fat, 4...8, when: heatsProtein)],
            spices: meatSpice, portable: true, weight: 1.2,
            title: { f in
                guard let b = f["b"], let p = f["p"] else { return "Ролл" }
                let head = (b.isKind("c:lavash") || b.isKind("c:pita")) ? "Шаурма" : "Ролл"
                return head + " " + Say.with(p.words.ins)
            },
            steps: { f in
                guard let b = f["b"], let p = f["p"] else { return [] }
                var s = proteinSteps(p)
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                if let sc = f["sc"] { s.append("Смажь \(Say.acc(b)) \(Say.ins(sc)).") }
                s.append("Выложи \(Say.list(f.all(["p", "v", "v2", "c"]).map { $0.words.acc })) и плотно сверни.")
                s.append("Обжарь на сухой сковороде по 1–2 минуты с каждой стороны.")
                return s
            },
            tip: { _ in "Заверни в фольгу — удобно есть в дороге." }))

        t.append(T("quesadilla", [.main, .snack], minutes: 15,
            slots: [S("b", [.bread], tags: ["wrap"], range: 45...100),
                    S("c", [.cheese], no: ["spread"], range: 30...70),
                    S("p", [.meat, .legumes, .sausage, .fish], req: false, noCooks: [.liver, .lentils, .dryBeans], main: true),
                    S("v", [.vegetable], req: false, tags: ["pepper", "onion", "corn", "tomato", "mushroom"])],
            extras: [X("sc", ["c:salsa", "c:sour_cream", "c:ketchup"], 15...40), X("fat", fat, 3...6, when: heatsProtein)],
            spices: ["c:salt", "c:paprika", "c:cumin"], portable: true,
            title: { f in "Кесадилья " + Say.with(Say.list(f.all(["p", "c"]).map { $0.words.ins })) },
            steps: { f in
                guard let b = f["b"], let c = f["c"] else { return [] }
                var s: [String] = []
                if let p = f["p"] { s += proteinSteps(p) }
                if let v = f["v"] { s += Say.vegPrep([v]) }
                s.append("Выложи на половину \(b.isKind("c:lavash") ? "лаваша" : "тортильи") \(Say.list(f.all(["c", "p", "v"]).map { $0.words.acc })) и накрой второй половиной.")
                s.append("Обжарь на сухой сковороде по 2–3 минуты с каждой стороны, пока \(Say.low(c) == "сыр" ? "сыр" : Say.acc(c)) не расплавится.")
                if let sc = f["sc"] { s.append("Разрежь на треугольники и подавай \(Say.with(Say.ins(sc))).") }
                return s
            }))

        t.append(T("cutlets", [.main], minutes: 35,
            slots: [S("p", [.meat], tags: ["ground"], range: 150...300, main: true),
                    S("e", [.eggs], req: false, no: ["whites"], range: 50...50),
                    S("v", [.vegetable], req: false, tags: ["onion"], range: 40...80),
                    S("s", [.grain, .pasta, .potato], noCooks: [.fries]),
                    S("v2", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf"], no: ["herb"])],
            extras: [X("fat", fat, 6...12), X("fl", ["c:flour"], 10...20)],
            spices: ["c:salt", "c:pepper", "c:garlic_dry", "c:paprika"], portable: true,
            title: { f in
                guard let s = f["s"] else { return "Котлеты" }
                return "Котлеты " + Say.with(Say.list([s.words.ins] + f.all(["v2"]).map { $0.words.ins }))
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = [Say.side(side)]
                if let v = f["v"] { s.append("Мелко натри или порежь \(Say.acc(v)).") }
                var mix: [String] = []
                if f["e"] != nil { mix.append("яйцом") }
                if let v = f["v"] { mix.append(v.words.ins) }
                mix += ["солью", "перцем"]
                s.append("Смешай \(Say.acc(p)) \(Say.with(Say.list(mix))).")
                s.append("Сформируй мокрыми руками 4–6 котлет\(f["fl"] != nil ? " и обваляй их в муке" : "").")
                s.append("Обжарь на масле на среднем огне по 4–5 минут с каждой стороны, потом накрой крышкой ещё на 5–7 минут.")
                if let v2 = f["v2"] { s += Say.vegPrep([v2]) }
                s.append("Подавай \(Say.with(Say.list(f.all(["s", "v2"]).map { $0.words.ins }))).")
                return s
            }))

        t.append(T("fish_side", [.main], minutes: 25,
            slots: [S("p", [.fish], noCooks: [.cannedFish, .noCook], main: true),
                    S("s", [.grain, .potato, .pasta], noCooks: [.fries]),
                    S("v", [.vegetable], req: false, no: ["fatty", "raw"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:lemon_juice", "c:paprika", "c:italian_herbs"], portable: true,
            title: { f in
                guard let p = f["p"], let s = f["s"] else { return "Рыба с гарниром" }
                return Say.ttl(p) + " " + Say.with(Say.list([s.words.ins] + f.all(["v"]).map { $0.words.ins }))
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = [Say.side(side)]
                if let pr = Say.prep(p) { s.append(pr) }
                if let v = f["v"] { s += Say.vegPrep([v]) }
                s.append("Разогрей масло в сковороде.")
                s.append(Say.pan(p))
                if let v = f["v"] { s.append("На той же сковороде обжарь \(Say.acc(v)) 4–5 минут.") }
                if f.spices.contains(where: { $0.isKind("c:lemon_juice") }) { s.append("Сбрызни рыбу лимонным соком.") }
                if let h = f["h"] { s.append("Посыпь \(Say.ins(h)).") }
                return s
            }))

        t.append(T("asian", [.main], minutes: 25,
            slots: [S("p", [.meat, .fish, .legumes], noCooks: [.cannedFish, .cannedLegumes, .lentils, .dryBeans, .noCook, .liver, .groundMeat, .cookedMeat], main: true),
                    S("s", [.pasta, .grain], tags: ["noodles", "rice"]),
                    S("v", [.vegetable], req: false, no: ["raw", "fatty"]),
                    S("v2", [.vegetable], req: false, no: ["raw", "fatty"])],
            extras: [X("soy", ["c:soy_sauce"], 15...30, req: true), X("fat", fat, 6...12)],
            spices: ["c:garlic", "c:garlic_dry", "c:chili", "c:pepper"], portable: true, onePan: true, weight: 1.2,
            title: { f in
                guard let p = f["p"], let s = f["s"] else { return "Стир-фрай" }
                return Say.ttl(s) + " по-азиатски " + Say.with(p.words.ins)
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = [Say.side(side)]
                if let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append("Разогрей сковороду с маслом до сильного жара.")
                s.append(Say.pan(p))
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь 3–4 минуты на сильном огне, постоянно помешивая.") }
                s.append("Добавь \(Say.list([side.words.acc, "соевый соус"] + Say.spiceList(f.spices))), перемешай и прогрей 1–2 минуты.")
                return s
            }))

        t.append(T("fried_potato", [.main], minutes: 30,
            slots: [S("s", [.potato], cooks: [.potato, .sweetPotato], range: 200...400),
                    S("p", [.meat, .sausage, .eggs], no: ["bone", "whites"], noCooks: [.liver], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion", "mushroom"]),
                    S("v2", [.vegetable, .greens], req: false, tags: ["salad", "raw"], no: ["herb", "fatty"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("fat", fat, 10...18), X("sc", ["c:sour_cream", "c:ketchup"], 15...30)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:garlic_dry"], onePan: true,
            title: { f in
                guard let s = f["s"], let p = f["p"] else { return "Жареная картошка" }
                let head = s.isKind("c:sweet_potato") ? "Жареный батат" : "Жареная картошка"
                return head + " " + Say.with(p.role == .eggs ? "яйцом" : p.words.ins)
            },
            steps: { f in
                guard let side = f["s"], let p = f["p"] else { return [] }
                var s = ["Почисть \(Say.acc(side)) и нарежь брусочками."]
                if p.role != .eggs, let pr = Say.prep(p) { s.append(pr) }
                s.append("Разогрей масло и жарь картофель 10 минут не помешивая, чтобы появилась корочка.")
                if let v = f["v"] { s += Say.vegPrep([v]); s.append("Переверни и добавь \(Say.acc(v)).") }
                if p.role == .eggs {
                    s.append("Через 8 минут сделай в картошке углубления, разбей в них яйца и держи под крышкой 3–4 минуты.")
                } else if Say.needsHeat(p) {
                    s.append("Добавь \(Say.acc(p)) и жарь ещё 8–10 минут до готовности, иногда переворачивая.")
                } else {
                    s.append("Через 8 минут добавь \(Say.acc(p)) и обжарь вместе ещё 3–4 минуты.")
                }
                s.append("Посоли и поперчи в самом конце.")
                if let h = f["h"] { s.append("Посыпь \(Say.ins(h)).") }
                if let v2 = f["v2"] { s += Say.vegPrep([v2]); s.append("Подавай \(Say.with(Say.ins(v2))).") }
                if let sc = f["sc"] { s.append("Рядом — \(Say.acc(sc)).") }
                return s
            }))

        t.append(T("dumplings", [.main], minutes: 12,
            slots: [S("r", [.ready], tags: ["dumplings"], range: 200...350, main: true),
                    S("v", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf"], no: ["herb"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...10)],
            extras: [X("sc", ["c:sour_cream", "c:butter", "c:ketchup"], 10...30)],
            spices: ["c:salt", "c:bay_leaf", "c:pepper"], onePan: true,
            title: { f in
                guard let r = f["r"] else { return "Пельмени" }
                return Say.ttl(r) + (f["sc"].map { " " + Say.with(Say.ins($0)) } ?? "")
            },
            steps: { f in
                guard let r = f["r"] else { return [] }
                var s = ["Доведи до кипения 2 литра воды, посоли и брось лавровый лист.", Say.side(r)]
                if let sc = f["sc"] { s.append("Достань шумовкой и подавай \(Say.with(Say.ins(sc))).") }
                if let h = f["h"] { s.append("Посыпь \(Say.ins(h)).") }
                if let v = f["v"] { s += Say.vegPrep([v]); s.append("Свежие овощи подай рядом.") }
                return s
            }))

        t.append(T("ready_meal", [.main], minutes: 10,
            slots: [S("r", [.ready], no: ["dumplings"], main: true),
                    S("v", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf"], no: ["herb"]),
                    S("v2", [.vegetable], req: false, tags: ["salad", "raw"])],
            weight: 0.7,
            title: { f in
                guard let r = f["r"] else { return "Готовое блюдо" }
                let name = r.source == .catalog ? r.words.title : r.name
                return name + (f["v"] != nil ? " и свежие овощи" : "")
            },
            steps: { f in
                guard let r = f["r"] else { return [] }
                var s = [Say.side(r)]
                let veg = f.all(["v", "v2"])
                if !veg.isEmpty { s += Say.vegPrep(veg); s.append("Подавай с овощами — так сытнее и больше клетчатки.") }
                return s
            }))

        t.append(T("sausage_side", [.main], minutes: 20,
            slots: [S("p", [.sausage], cooks: [.sausage], range: 90...200, main: true),
                    S("s", [.pasta, .grain, .potato], noCooks: [.barley]),
                    S("v", [.vegetable], req: false, tags: ["peas", "corn", "salad", "raw", "frozen"])],
            extras: [X("sc", ["c:ketchup", "c:mustard"], 10...25)],
            portable: true, weight: 0.8,
            title: { f in
                guard let p = f["p"], let s = f["s"] else { return "Сосиски с гарниром" }
                return Say.ttl(p) + " " + Say.with(Say.list([s.words.ins] + f.all(["v"]).map { $0.words.ins }))
            },
            steps: { f in
                guard let p = f["p"], let side = f["s"] else { return [] }
                var s = [Say.side(side), "Отвари \(Say.acc(p)) 3–5 минут или обжарь на сухой сковороде до румяности."]
                if let v = f["v"] {
                    if Say.cook(v) == .frozenVeg || Say.cook(v) == .cannedVeg { s.append("Прогрей \(Say.acc(v)) 3 минуты в кипятке.") }
                    else { s += Say.vegPrep([v]) }
                }
                if let sc = f["sc"] { s.append("Подавай \(Say.with(Say.ins(sc))).") }
                return s
            }))

        t.append(T("chili", [.main], minutes: 35,
            slots: [S("l", [.legumes], tags: ["beans"], cooks: [.cannedLegumes], range: 120...260),
                    S("p", [.meat], req: false, tags: ["ground"], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion", "pepper", "corn", "tomato"]),
                    S("v2", [.vegetable], req: false, tags: ["onion", "pepper", "corn", "tomato"]),
                    S("s", [.grain, .bread], req: false, tags: ["rice", "wrap"], range: 40...90)],
            extras: [XA("t", tomato, req: true), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:cumin", "c:paprika", "c:chili", "c:garlic_dry"], portable: true, onePan: true,
            title: { f in
                if let p = f["p"] { return "Чили " + Say.with(p.words.ins) + " и фасолью" }
                return "Овощное чили с фасолью"
            },
            steps: { f in
                guard let l = f["l"], let tm = f["t"] else { return [] }
                var s: [String] = []
                if let side = f["s"], side.role == .grain { s.append(Say.side(side)) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append(veg.isEmpty ? "Разогрей масло в кастрюле." : "Разогрей масло в кастрюле и обжарь \(Say.list(veg.map { $0.words.acc })) 3–4 минуты.")
                if let p = f["p"] { s.append(Say.pan(p)) }
                s.append("Откинь \(Say.acc(l)) на дуршлаг.")
                s.append("Добавь \(Say.list([l.words.acc, tm.words.acc] + Say.spiceList(f.spices) + ["стакан воды"])).")
                s.append("Туши под крышкой 15 минут, иногда помешивая.")
                if let side = f["s"] { s.append("Подавай \(Say.with(Say.ins(side))).") }
                return s
            }))

        t.append(T("shakshuka", [.breakfast, .main], minutes: 20,
            slots: [S("e", [.eggs], no: ["whites"], range: 100...200, main: true),
                    S("v", [.vegetable], req: false, tags: ["tomato"]),
                    S("v2", [.vegetable], req: false, tags: ["pepper", "onion"]),
                    S("c", [.cheese], req: false, tags: ["salad"], range: 20...40),
                    S("b", [.bread], req: false, tags: ["slice", "pocket"], range: 30...80)],
            extras: [XA("t", [("c:marinara", 80...150), ("c:tomato_paste", 15...30)]), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:cumin", "c:chili"], onePan: true,
            check: { f in f["v"] != nil || f["t"] != nil },
            title: { f in "Шакшука" + (f["c"].map { " " + Say.with(Say.ins($0)) } ?? "") },
            steps: { f in
                var s: [String] = []
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append(veg.isEmpty ? "Разогрей масло в сковороде." : "Разогрей масло и обжарь \(Say.list(veg.map { $0.words.acc })) 5–6 минут.")
                let sp = Say.spices(f.spices)
                if let tm = f["t"] {
                    let add = [tm.words.acc] + (tm.isKind("c:tomato_paste") ? ["100 мл воды"] : []) + Say.spiceList(f.spices)
                    s.append("Добавь \(Say.list(add)) и туши 5 минут.")
                } else if !sp.isEmpty { s.append("Добавь \(sp) и туши 5 минут.") }
                s.append("Сделай ложкой углубления, разбей в них яйца и посоли.")
                s.append("Накрой крышкой и готовь 5–7 минут, пока белок не схватится.")
                if let c = f["c"] { s.append("Раскроши сверху \(Say.acc(c)).") }
                if let b = f["b"] { s.append("Подавай \(Say.with(Say.ins(b))).") }
                return s
            }))

        t.append(T("stew", [.main], minutes: 40,
            slots: [S("p", [.meat, .sausage, .legumes], no: ["cooked"], noCooks: [.liver, .bacon], main: true),
                    S("v", [.vegetable], tags: ["stew", "green", "mix"], no: ["raw", "fatty"]),
                    S("v2", [.vegetable], req: false, tags: ["onion", "carrot", "pepper", "tomato"]),
                    S("s", [.potato, .bread], req: false, noCooks: [.fries])],
            extras: [X("t", ["c:tomato_paste"], 10...25), X("fat", fat, 6...12)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:bay_leaf", "c:italian_herbs"], onePan: true,
            title: { f in "Овощное рагу " + Say.with(f["p"].map { Say.ins($0) } ?? "мясом") },
            steps: { f in
                guard let p = f["p"] else { return [] }
                var s: [String] = []
                if let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                let potato = f["s"].flatMap { $0.role == .potato ? $0 : nil }
                if let pt = potato { s.append("Почисть \(Say.acc(pt)) и нарежь кубиками.") }
                s.append("Разогрей масло в глубокой сковороде.")
                if Say.needsHeat(p) { s.append(Say.pan(p)) }
                var add = veg.map { $0.words.acc }
                if let pt = potato { add.append(pt.words.acc) }
                if let tm = f["t"] { add.append(tm.words.acc) }
                s.append("Добавь \(Say.list(add + ["100 мл воды"] + Say.spiceList(f.spices))).")
                if p.role == .legumes && Say.cook(p) == .cannedLegumes { s.append("Откинь \(Say.acc(p)) на дуршлаг и добавь в сковороду.") }
                s.append("Туши под крышкой на слабом огне 20–25 минут, пока овощи не станут мягкими.")
                if let b = f["s"], b.role == .bread { s.append("Подавай \(Say.with(Say.ins(b))).") }
                return s
            }))

        // ───────────── Перекусы ─────────────

        t.append(T("fruit_nuts", [.snack], minutes: 1,
            slots: [S("fr", [.fruit, .berries], range: 100...250, main: true),
                    S("n", [.nuts], req: false, no: ["spread"], range: 10...30)],
            sweet: true,
            title: { f in
                guard let fr = f["fr"] else { return "Фрукты" }
                return Say.ttl(fr) + (f["n"].map { " и " + Say.low($0) } ?? "")
            },
            steps: { f in
                guard let fr = f["fr"] else { return [] }
                return ["Возьми \(Say.acc(fr))\(f["n"].map { " и \(Say.acc($0))" } ?? "") — это вся порция на перекус."]
            },
            tip: { _ in "Удобно взять с собой в машину." }))

        t.append(T("snack_ready", [.snack], minutes: 0,
            slots: [S("sn", [.snack], range: 30...80, main: true)],
            weight: 0.6,
            title: { f in
                guard let x = f["sn"] else { return "Перекус" }
                return x.source == .catalog ? x.words.title : x.name
            },
            steps: { _ in ["Ничего готовить не нужно — просто съешь и запей водой."] }))

        t.append(T("boiled_eggs", [.snack, .breakfast, .evening], minutes: 12,
            slots: [S("e", [.eggs], no: ["whites"], range: 100...150, main: true),
                    S("v", [.vegetable], req: false, tags: ["salad", "raw"], no: ["fatty"]),
                    S("b", [.bread], req: false, tags: ["crisp"], range: 10...30)],
            spices: ["c:salt", "c:pepper"],
            title: { f in "Варёные яйца" + (f["v"].map { " " + Say.with(Say.ins($0)) } ?? "") },
            steps: { f in
                var s = ["Опусти яйца в кипящую воду и вари 9 минут.", "Переложи в холодную воду на пару минут — так легче чистить."]
                if let v = f["v"] { s += Say.vegPrep([v]) }
                if let b = f["b"] { s.append("Подавай \(Say.with(Say.ins(b))).") }
                return s
            },
            tip: { _ in "Свари сразу несколько штук — в холодильнике они хранятся до 5 дней." }))

        t.append(T("kefir_fruit", [.snack, .evening], minutes: 2,
            slots: [S("m", [.milk], range: 200...350, main: true),
                    S("fr", [.fruit, .berries], req: false, no: ["dried"], range: 80...150)],
            sweet: true,
            title: { f in
                guard let m = f["m"] else { return "Кефир" }
                return Say.ttl(m) + (f["fr"].map { " " + Say.with(Say.ins($0)) } ?? "")
            },
            steps: { f in
                guard let m = f["m"] else { return [] }
                var s = ["Налей \(Say.acc(m)) в стакан."]
                if let fr = f["fr"] {
                    s.append(fr.role == .berries ? "Добавь \(Say.acc(fr)) прямо в стакан или ешь вприкуску." : "Нарежь \(Say.acc(fr)) и ешь вприкуску.")
                }
                return s
            }))

        t.append(T("crisp_topping", [.snack], minutes: 3,
            slots: [S("b", [.bread], tags: ["crisp", "slice"], range: 20...60),
                    S("c", [.cheese, .cottage, .sausage], cooks: [.noCook], range: 20...60, main: true),
                    S("v", [.vegetable], req: false, tags: ["salad", "raw"], no: ["fatty"])],
            portable: true,
            title: { f in
                guard let b = f["b"], let c = f["c"] else { return "Бутерброд" }
                return Say.ttl(b) + " " + Say.with(Say.list([c.words.ins] + f.all(["v"]).map { $0.words.ins }))
            },
            steps: { f in
                guard let b = f["b"] else { return [] }
                var s: [String] = []
                if let v = f["v"] { s += Say.vegPrep([v]) }
                s.append("Выложи на \(Say.acc(b)) \(Say.list(f.all(["c", "v"]).map { $0.words.acc })).")
                return s
            }))

        t.append(T("dip_veg", [.snack], minutes: 5,
            slots: [S("h", [.snack, .sauce], tags: ["dip"], range: 40...90, main: true),
                    S("v", [.vegetable], tags: ["salad", "raw"], no: ["fatty"], range: 100...200),
                    S("b", [.bread], req: false, tags: ["pocket", "crisp"], range: 20...60)],
            portable: true,
            title: { f in
                guard let h = f["h"], let v = f["v"] else { return "Овощи с соусом" }
                return Say.ttl(h) + " " + Say.with(v.words.ins)
            },
            steps: { f in
                guard let h = f["h"], let v = f["v"] else { return [] }
                return ["Нарежь \(Say.acc(v)) брусочками.", "Макай овощи\(f["b"].map { " и \(Say.acc($0))" } ?? "") в \(Say.acc(h))."]
            }))

        t += desserts()
        t += breakfasts()
        t += mains()
        return t
    }
}
