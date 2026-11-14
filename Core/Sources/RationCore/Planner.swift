import Foundation

// MARK: - Случайные числа с зерном (чтобы «Пересобрать» давал другой день, а тесты — один и тот же)

public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Вход

public struct PlannerInput {
    public var pantry: [PantryItem]
    /// Включённые продукты «всегда есть дома» (специи, соусы, масла).
    public var staples: [Food]
    public var target: Macros
    public var options: PlanOptions
    public var seed: UInt64

    public init(pantry: [PantryItem], staples: [Food], target: Macros, options: PlanOptions, seed: UInt64) {
        self.pantry = pantry; self.staples = staples; self.target = target; self.options = options; self.seed = seed
    }
}

// MARK: - Внутренние заготовки

struct Avail {
    let food: Food
    let limit: Double?
}

struct Part {
    var key: String
    var food: Food
    var grams: Double
    var lo: Double
    var hi: Double
    var typical: Double
    var piece: Double?
    var locked: Bool
}

struct Draft {
    var slot: MealSlot
    var tpl: DishTemplate?
    var fill: Fill
    var parts: [Part]
    /// Уже готовый приём (при замене одного блюда остальные не трогаем).
    var fixed: Meal?
}

// MARK: - Подбор рациона

public enum Planner {

    /// Составить рацион на день.
    public static func generate(_ input: PlannerInput, attempts: Int = 350) -> DayPlan {
        var rng = SplitMix64(seed: input.seed)
        let pool = makePool(input)
        let slots = Schedule.slots(count: input.options.mealCount, firstMeal: input.options.firstMeal)
        let T = input.target

        var best: [Draft] = []
        var bestScore = Double.infinity
        for attempt in 0..<attempts {
            var drafts: [Draft] = []
            var usedMain: [String: Int] = [:]
            var usedTpl: [String: Int] = [:]
            var missing = 0
            for slot in slots {
                let isLunch = slot.kind == .main && !drafts.contains { $0.slot.kind == .main }
                if let d = draftMeal(slot: slot, pool: pool, opt: input.options, usedMain: usedMain,
                                     usedTpl: usedTpl, isLunch: isLunch, rng: &rng) {
                    drafts.append(d)
                    if let tpl = d.tpl { usedTpl[tpl.id, default: 0] += 1 }
                    for p in d.parts where isMain(p, d) { usedMain[p.food.id, default: 0] += 1 }
                } else {
                    missing += 1
                }
            }
            if drafts.isEmpty { continue }
            applyLimits(&drafts, pool: pool, opt: input.options)
            let fit = solve(&drafts, target: T)
            let score = fit + Double(missing) * 0.35 + repeatPenalty(drafts)
            if score < bestScore {
                bestScore = score
                best = drafts
            }
            if attempt > 80 && bestScore < 0.002 { break }
        }
        return assemble(best, slots: slots, input: input)
    }

    /// Заменить одно блюдо, не трогая остальные.
    public static func replace(meal index: Int, in plan: DayPlan, input: PlannerInput, attempts: Int = 220) -> DayPlan {
        guard plan.meals.indices.contains(index) else { return plan }
        var rng = SplitMix64(seed: input.seed)
        let pool = makePool(input)
        let old = plan.meals[index]
        let T = input.target

        var usedMain: [String: Int] = [:]
        var usedTpl: [String: Int] = [old.templateID: 3]
        for (i, m) in plan.meals.enumerated() where i != index {
            usedTpl[m.templateID, default: 0] += 1
            if let first = m.ingredients.first { usedMain[first.food.id, default: 0] += 1 }
        }
        let oldMain = old.ingredients.first?.food.id
        if let om = oldMain { usedMain[om, default: 0] += 2 }

        var bestDraft: Draft?
        var bestScore = Double.infinity
        let isLunch = old.slot.kind == .main && !plan.meals.prefix(index).contains { $0.slot.kind == .main }
        for _ in 0..<attempts {
            guard let d = draftMeal(slot: old.slot, pool: pool, opt: input.options, usedMain: usedMain,
                                    usedTpl: usedTpl, isLunch: isLunch, rng: &rng) else { continue }
            if d.tpl?.id == old.templateID && plan.meals.count > 1 && Double.random(in: 0..<1, using: &rng) < 0.85 { continue }
            var drafts: [Draft] = plan.meals.enumerated().map { i, m in
                i == index ? d : lockedDraft(m)
            }
            applyLimits(&drafts, pool: pool, opt: input.options)
            let fit = solve(&drafts, target: T)
            if fit < bestScore {
                bestScore = fit
                bestDraft = drafts[index]
            }
        }
        guard let nd = bestDraft, let meal = makeMeal(nd, input: input) else { return plan }
        var out = plan
        out.meals[index] = meal
        out.note = note(for: out.macros, target: T, missingSlots: [])
        out.buy = buy(for: out.macros, target: T, input: input)
        return out
    }

    // MARK: Пул продуктов

    static func makePool(_ input: PlannerInput) -> [Avail] {
        var seen = Set<String>()
        var out: [Avail] = []
        for item in input.pantry where item.food.role != .drink {
            guard !seen.contains(item.food.id) else { continue }
            seen.insert(item.food.id)
            out.append(Avail(food: item.food, limit: item.grams))
        }
        for s in input.staples where !seen.contains(s.id) {
            seen.insert(s.id)
            out.append(Avail(food: s, limit: nil))
        }
        return out
    }

    static func allowed(_ f: Food, _ o: PlanOptions) -> Bool {
        if o.noFish && f.role == .fish { return false }
        if o.noPork && f.has("pork") { return false }
        if o.vegetarian && ([.meat, .fish, .sausage].contains(f.role) || f.has("chicken")) { return false }
        if o.noOven && f.has("oven") { return false }
        return true
    }

    static func matches(_ f: Food, _ s: SlotSpec, _ o: PlanOptions) -> Bool {
        guard s.roles.contains(f.role) else { return false }
        if !s.anyTags.isEmpty && !s.anyTags.contains(where: { f.has($0) }) { return false }
        if s.noTags.contains(where: { f.has($0) }) { return false }
        let c = Say.cook(f)
        if let cs = s.cooks, !cs.contains(c) { return false }
        if s.noCooks.contains(c) { return false }
        return allowed(f, o)
    }

    static func isMain(_ p: Part, _ d: Draft) -> Bool {
        guard let tpl = d.tpl else { return false }
        return tpl.slots.first(where: { $0.key == p.key })?.main ?? false
    }

    static func pick<T>(_ items: [(T, Double)], _ rng: inout SplitMix64) -> T? {
        let total = items.reduce(0.0) { $0 + max(0, $1.1) }
        guard total > 0 else { return items.first?.0 }
        var r = Double.random(in: 0..<total, using: &rng)
        for (it, w) in items {
            r -= max(0, w)
            if r < 0 { return it }
        }
        return items.last?.0
    }

    // MARK: Черновик одного приёма

    static func draftMeal(slot: MealSlot, pool: [Avail], opt: PlanOptions, usedMain: [String: Int],
                          usedTpl: [String: Int], isLunch: Bool, rng: inout SplitMix64) -> Draft? {
        var kinds: [MealKind] = [slot.kind]
        if slot.kind == .evening { kinds.append(.snack) }
        var tpls = Templates.all.filter { t in
            guard kinds.contains(where: { t.kinds.contains($0) }) else { return false }
            if opt.noOven && t.oven { return false }
            if let mx = opt.maxMinutes, slot.kind != .snack, t.minutes > mx { return false }
            if isLunch && opt.portableLunch && !t.portable { return false }
            return true
        }
        if slot.kind == .evening {
            let ev = tpls.filter { $0.kinds.contains(.evening) }
            if !ev.isEmpty { tpls = ev }
        }
        var weighted: [(DishTemplate, Double)] = tpls.map { t in
            var w = t.weight
            if let n = usedTpl[t.id] { w *= pow(0.12, Double(n)) }
            if opt.fewDishes && t.onePan { w *= 2 }
            if opt.sweetSnack && slot.kind == .snack { w *= t.sweet ? 4 : 0.5 }
            return (t, w)
        }
        for _ in 0..<12 {
            guard !weighted.isEmpty, let t = pick(weighted, &rng) else { return nil }
            if let d = fill(template: t, slot: slot, pool: pool, opt: opt, usedMain: usedMain, rng: &rng) { return d }
            weighted.removeAll { $0.0.id == t.id }
        }
        return nil
    }

    static func fill(template t: DishTemplate, slot: MealSlot, pool: [Avail], opt: PlanOptions,
                     usedMain: [String: Int], rng: inout SplitMix64) -> Draft? {
        var f = Fill()
        var parts: [Part] = []
        var used = Set<String>()
        for s in t.slots {
            let cands = pool.filter { !used.contains($0.food.id) && matches($0.food, s, opt) }
            if cands.isEmpty {
                if s.required { return nil }
                continue
            }
            if !s.required && Double.random(in: 0..<1, using: &rng) > 0.62 { continue }
            let range = s.range ?? cands[0].food.role.portion
            let w: [(Avail, Double)] = cands.map { a in
                var x = 1.0
                if s.main, let n = usedMain[a.food.id] { x *= pow(0.15, Double(n)) }
                if let l = a.limit { x *= l >= range.lowerBound ? 1 : 0.05 }
                if a.food.source != .catalog { x *= 1.1 }
                return (a, x)
            }
            guard let a = pick(w, &rng) else { continue }
            used.insert(a.food.id)
            f.foods[s.key] = a.food
            parts.append(makePart(key: s.key, food: a.food, range: s.range ?? a.food.role.portion))
        }
        for x in t.extras {
            if let cond = x.when, !cond(f) { continue }
            var found: (Food, ClosedRange<Double>)?
            for (k, r) in x.alts {
                if let a = pool.first(where: { $0.food.isKind(k) && !used.contains($0.food.id) && allowed($0.food, opt) }) {
                    found = (a.food, r)
                    break
                }
            }
            guard let hit = found else {
                if x.required { return nil }
                continue
            }
            let food = hit.0, r = hit.1
            if !x.required && x.key != "fat" && Double.random(in: 0..<1, using: &rng) < 0.3 { continue }
            used.insert(food.id)
            f.foods[x.key] = food
            parts.append(makePart(key: x.key, food: food, range: r))
        }
        for sid in t.spices where f.spices.count < 5 {
            if let a = pool.first(where: { $0.food.isKind(sid) && $0.food.role == .spice && !used.contains($0.food.id) }) {
                used.insert(a.food.id)
                f.spices.append(a.food)
                parts.append(Part(key: "spice", food: a.food, grams: 0, lo: 0, hi: 0, typical: 0, piece: nil, locked: true))
            }
        }
        if !t.check(f) { return nil }
        // Блюдо без единого калорийного продукта не годится.
        if !parts.contains(where: { $0.food.per100.kcal > 30 && !$0.locked }) { return nil }
        return Draft(slot: slot, tpl: t, fill: f, parts: parts, fixed: nil)
    }

    static func makePart(key: String, food: Food, range: ClosedRange<Double>) -> Part {
        var lo = range.lowerBound, hi = range.upperBound
        var typical = min(max(food.role.typical, lo), hi)
        if food.role == .spice { return Part(key: key, food: food, grams: 0, lo: 0, hi: 0, typical: 0, piece: nil, locked: true) }
        var piece = food.pieceGrams
        if let pg = piece, pg > 0 {
            if pg > hi * 1.05 {
                // Одна штука больше обычной порции (большая банка, целый баклажан) — считаем граммами.
                piece = nil
            } else {
                lo = max(pg, (lo / pg).rounded(.down) * pg)
                hi = max(lo, (hi / pg).rounded(.down) * pg)
                typical = min(max((typical / pg).rounded() * pg, lo), hi)
            }
        }
        return Part(key: key, food: food, grams: typical, lo: lo, hi: hi, typical: max(typical, 1), piece: piece, locked: false)
    }

    static func lockedDraft(_ m: Meal) -> Draft {
        let parts = m.ingredients.map {
            Part(key: "fixed", food: $0.food, grams: $0.grams, lo: $0.grams, hi: $0.grams, typical: max($0.grams, 1), piece: nil, locked: true)
        }
        return Draft(slot: m.slot, tpl: nil, fill: Fill(), parts: parts, fixed: m)
    }

    /// Не тратить больше продукта, чем есть дома (с учётом всех блюд дня).
    static func applyLimits(_ drafts: inout [Draft], pool: [Avail], opt: PlanOptions) {
        var limits: [String: Double] = [:]
        for a in pool { if let l = a.limit { limits[a.food.id] = l } }
        guard !limits.isEmpty else { return }
        var uses: [String: Double] = [:]
        var fixedUse: [String: Double] = [:]
        for d in drafts {
            let k = (opt.cookForTwoDays && d.slot.kind == .main) ? 2.0 : 1.0
            for p in d.parts where limits[p.food.id] != nil {
                if p.locked { fixedUse[p.food.id, default: 0] += p.grams * k }
                else { uses[p.food.id, default: 0] += k }
            }
        }
        for i in drafts.indices {
            let k = (opt.cookForTwoDays && drafts[i].slot.kind == .main) ? 2.0 : 1.0
            for j in drafts[i].parts.indices where !drafts[i].parts[j].locked {
                let id = drafts[i].parts[j].food.id
                guard let l = limits[id], let n = uses[id], n > 0 else { continue }
                let share = max(0, l - (fixedUse[id] ?? 0)) / n / k
                var p = drafts[i].parts[j]
                if share < p.hi {
                    p.hi = max(0, share)
                    if let pg = p.piece, pg > 0 { p.hi = (p.hi / pg).rounded(.down) * pg }
                    p.lo = min(p.lo, p.hi)
                    p.grams = min(max(p.grams, p.lo), p.hi)
                    p.typical = max(min(p.typical, max(p.hi, 1)), 1)
                }
                drafts[i].parts[j] = p
            }
        }
    }

    // MARK: Подгонка граммов

    static let wK = 3.0, wP = 3.0, wF = 1.2, wC = 1.0, wMeal = 0.6, wReg = 0.03

    /// Подбирает граммы всех продуктов дня так, чтобы сумма попала в цель. Возвращает ошибку (0 — идеально).
    @discardableResult
    static func solve(_ drafts: inout [Draft], target T: Macros, sweeps: Int = 70) -> Double {
        // Плоские массивы переменных.
        var x: [Double] = [], lo: [Double] = [], hi: [Double] = [], typ: [Double] = []
        var a: [Macros] = [], meal: [Int] = [], piece: [Double?] = [], ref: [(Int, Int)] = []
        for (i, d) in drafts.enumerated() {
            for (j, p) in d.parts.enumerated() {
                x.append(p.grams); lo.append(p.lo); hi.append(p.hi); typ.append(p.typical)
                a.append(p.food.per100 * 0.01); meal.append(i); piece.append(p.locked ? nil : p.piece); ref.append((i, j))
            }
        }
        let shareSum = max(drafts.reduce(0) { $0 + $1.slot.share }, 0.01)
        let shares = drafts.map { $0.slot.share / shareSum }
        let Tk = max(T.kcal, 1), Tp = max(T.p, 1), Tf = max(T.f, 1), Tc = max(T.c, 1)
        let mealCount = drafts.count

        func objective(_ x: [Double]) -> Double {
            var S = Macros.zero
            var mk = [Double](repeating: 0, count: mealCount)
            for i in x.indices {
                S.kcal += a[i].kcal * x[i]; S.p += a[i].p * x[i]; S.f += a[i].f * x[i]; S.c += a[i].c * x[i]
                mk[meal[i]] += a[i].kcal * x[i]
            }
            var e = wK * sq((S.kcal - T.kcal) / Tk)
            e += wP * sq((S.p - T.p) / Tp)
            e += wF * sq((S.f - T.f) / Tf)
            e += wC * sq((S.c - T.c) / Tc)
            for j in mk.indices { e += wMeal * sq((mk[j] - shares[j] * T.kcal) / Tk) }
            for i in x.indices where hi[i] > lo[i] { e += wReg * sq((x[i] - typ[i]) / typ[i]) }
            return e
        }

        // Непрерывная подгонка: покоординатный метод Ньютона (задача квадратичная).
        var S = Macros.zero
        var mk = [Double](repeating: 0, count: mealCount)
        for i in x.indices {
            x[i] = min(max(x[i], lo[i]), hi[i])
            S = S + a[i] * x[i]
            mk[meal[i]] += a[i].kcal * x[i]
        }
        for _ in 0..<sweeps {
            var moved = 0.0
            for i in x.indices where hi[i] > lo[i] {
                let ai = a[i]
                let mj = meal[i]
                let tk2 = Tk * Tk, tp2 = Tp * Tp, tf2 = Tf * Tf, tc2 = Tc * Tc
                let ty2 = typ[i] * typ[i]
                var g: Double = wK * ai.kcal * (S.kcal - T.kcal) / tk2
                g += wP * ai.p * (S.p - T.p) / tp2
                g += wF * ai.f * (S.f - T.f) / tf2
                g += wC * ai.c * (S.c - T.c) / tc2
                g += wMeal * ai.kcal * (mk[mj] - shares[mj] * T.kcal) / tk2
                g += wReg * (x[i] - typ[i]) / ty2
                var h: Double = wK * ai.kcal * ai.kcal / tk2
                h += wP * ai.p * ai.p / tp2
                h += wF * ai.f * ai.f / tf2
                h += wC * ai.c * ai.c / tc2
                h += wMeal * ai.kcal * ai.kcal / tk2
                h += wReg / ty2
                guard h > 0 else { continue }
                let nx = min(max(x[i] - g / h, lo[i]), hi[i])
                let dx = nx - x[i]
                if dx != 0 {
                    x[i] = nx
                    S = S + ai * dx
                    mk[mj] += ai.kcal * dx
                    moved += abs(dx)
                }
            }
            if moved < 0.5 { break }
        }

        // Округление: штуки — до целых, остальное — до 5 г (мелочь — до 1 г).
        for i in x.indices where hi[i] > lo[i] {
            if let pg = piece[i], pg > 0 {
                let k = min(max((x[i] / pg).rounded(), (lo[i] / pg).rounded(.up)), (hi[i] / pg).rounded(.down))
                x[i] = max(k, 0) * pg
            } else {
                let step = hi[i] <= 40 ? 1.0 : 5.0
                x[i] = min(max((x[i] / step).rounded() * step, lo[i]), hi[i])
            }
        }
        // Небольшая доводка после округления.
        var best = objective(x)
        for _ in 0..<3 {
            var improved = false
            for i in x.indices where hi[i] > lo[i] {
                let step = piece[i] ?? (hi[i] <= 40 ? 1.0 : 5.0)
                for dir in [1.0, -1.0] {
                    let nx = x[i] + dir * step
                    guard nx >= lo[i] - 1e-9, nx <= hi[i] + 1e-9 else { continue }
                    let old = x[i]
                    x[i] = nx
                    let e = objective(x)
                    if e < best - 1e-9 { best = e; improved = true; break }
                    x[i] = old
                }
            }
            if !improved { break }
        }
        for (k, r) in ref.enumerated() { drafts[r.0].parts[r.1].grams = x[k] }
        return best
    }

    static func sq(_ v: Double) -> Double { v * v }

    static func repeatPenalty(_ drafts: [Draft]) -> Double {
        var seenTpl: [String: Int] = [:]
        var seenMain: [String: Int] = [:]
        var pen = 0.0
        for d in drafts {
            if let t = d.tpl { seenTpl[t.id, default: 0] += 1 }
            for p in d.parts where isMain(p, d) { seenMain[p.food.id, default: 0] += 1 }
        }
        for (_, n) in seenTpl where n > 1 { pen += 0.03 * Double(n - 1) }
        for (_, n) in seenMain where n > 1 { pen += 0.015 * Double(n - 1) }
        return pen
    }

    // MARK: Сборка результата

    static func makeMeal(_ d: Draft, input: PlannerInput) -> Meal? {
        if let m = d.fixed { return m }
        guard let t = d.tpl else { return nil }
        var f = d.fill
        // Слова в шагах — по реально выбранным продуктам (после подгонки граммов состав не меняется).
        f.foods = f.foods.filter { kv in d.parts.contains { $0.food.id == kv.value.id && ($0.grams > 0 || $0.locked) } }
        let ings = d.parts.filter { $0.grams > 0 || $0.locked }.map {
            Ingredient(food: $0.food, grams: $0.grams, locked: $0.locked)
        }
        var tip = t.tip(f)
        if input.options.cookForTwoDays && d.slot.kind == .main {
            tip = (tip.isEmpty ? "" : tip + " ") + "Готовь сразу двойную порцию — вторая пойдёт на завтра."
        }
        return Meal(slot: d.slot, templateID: t.id, title: t.title(f), minutes: t.minutes,
                    ingredients: ings, steps: t.steps(f), tip: tip)
    }

    static func assemble(_ drafts: [Draft], slots: [MealSlot], input: PlannerInput) -> DayPlan {
        let meals = drafts.compactMap { makeMeal($0, input: input) }
        let present = Set(meals.map { $0.slot.time + $0.slot.name })
        let missing = slots.filter { !present.contains($0.time + $0.name) }.map { $0.name }
        let total = meals.reduce(Macros.zero) { $0 + $1.macros }
        return DayPlan(target: input.target, meals: meals,
                       note: note(for: total, target: input.target, missingSlots: missing),
                       buy: buy(for: total, target: input.target, input: input))
    }

    static func note(for t: Macros, target T: Macros, missingSlots: [String]) -> String {
        var parts: [String] = []
        if !missingSlots.isEmpty {
            parts.append("Для приёма «\(missingSlots.joined(separator: "», «"))» не хватило продуктов — добавь, например, йогурт, фрукты или яйца.")
        }
        let dp = T.p - t.p
        let dk = (T.kcal - t.kcal) / max(T.kcal, 1)
        if dp > 10 {
            parts.append("Белка не хватает \(Int(dp.rounded())) г: дома мало белковых продуктов.")
        }
        if dk > 0.06 {
            parts.append("До цели не хватает \(Int((T.kcal - t.kcal).rounded())) ккал — продуктов дома маловато.")
        } else if dk < -0.06 {
            parts.append("Калорий выходит больше цели: в запасах много жирного. Можно убрать часть соусов или сыра.")
        }
        if parts.isEmpty {
            parts.append("Граммы подобраны под твою цель. Крупы, макароны и мясо взвешивай в сыром виде.")
        }
        return parts.joined(separator: " ")
    }

    static func buy(for t: Macros, target T: Macros, input: PlannerInput) -> [String] {
        let have = Set(input.pantry.compactMap { $0.food.kind ?? $0.food.id })
        var out: [String] = []
        if T.p - t.p > 10 {
            for k in ["c:chicken_breast", "c:greek_yogurt_0", "c:cottage_5", "c:egg", "c:tuna_water", "c:turkey_breast", "c:whey"]
            where !have.contains(k) && out.count < 3 {
                if let f = Catalog.food(k) { out.append(f.name) }
            }
        }
        if (T.kcal - t.kcal) / max(T.kcal, 1) > 0.06 {
            var n = 0
            for k in ["c:rice_white", "c:oats", "c:pasta", "c:banana", "c:bread_whole", "c:potato"] where !have.contains(k) && n < 2 {
                if let f = Catalog.food(k) { out.append(f.name); n += 1 }
            }
        }
        return out
    }
}
