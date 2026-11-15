import XCTest
@testable import RationCore

final class TargetTests: XCTestCase {
    func testDefaultCut() {
        let t = Profile().computedTarget
        XCTAssertEqual(t.kcal, 2370)
        XCTAssertEqual(t.p, 195)
        XCTAssertEqual(t.f, 71)
        XCTAssertEqual(t.c, 238)
    }

    func testSchedule() {
        let s = Schedule.slots(count: 4, firstMeal: "07:00")
        XCTAssertEqual(s.map { $0.time }, ["07:00", "11:00", "15:00", "19:00"])
        XCTAssertEqual(s.map { $0.name }, ["Завтрак", "Обед", "Перекус", "Ужин"])
        let night = Schedule.slots(count: 5, firstMeal: "03:30")
        XCTAssertEqual(night.first?.time, "03:30")
    }
}

final class LabelTests: XCTestCase {
    func testUSLabel() {
        let text = """
        Nutrition Facts
        8 servings per container
        Serving size 2/3 cup (55g)
        Amount per serving
        Calories 230
        Total Fat 8g 10%
        Saturated Fat 1g 5%
        Trans Fat Og
        Cholesterol 0mg 0%
        Sodium 160mg 7%
        Total Carbohydrate 37g 13%
        Dietary Fiber 4g 14%
        Total Sugars 12g
        Protein 3g
        """
        let r = LabelParser.parse(text)
        XCTAssertEqual(r.servingGrams, 55)
        XCTAssertEqual(r.perServing?.kcal, 230)
        XCTAssertEqual(r.perServing?.f, 8)
        XCTAssertEqual(r.perServing?.c, 37)
        XCTAssertEqual(r.perServing?.p, 3)
        XCTAssertEqual(r.per100?.kcal ?? 0, 418.2, accuracy: 0.5)
        XCTAssertEqual(r.per100?.p ?? 0, 5.45, accuracy: 0.05)
    }

    func testRussianLabel() {
        let text = "Пищевая ценность на 100 г продукта: белки 3,2 г, жиры 2,5 г, углеводы 4,7 г. Энергетическая ценность 218 кДж/52 ккал."
        let r = LabelParser.parse(text)
        XCTAssertEqual(r.per100?.kcal, 52)
        XCTAssertEqual(r.per100?.p, 3.2)
        XCTAssertEqual(r.per100?.f, 2.5)
        XCTAssertEqual(r.per100?.c, 4.7)
    }

    func testEULabel() {
        let text = "Nutrition information per 100g Energy 1046kJ/250kcal Fat 9.0g of which saturates 1.2g Carbohydrate 30g of which sugars 2g Protein 12g Salt 1.1g"
        let r = LabelParser.parse(text)
        XCTAssertEqual(r.per100?.kcal, 250)
        XCTAssertEqual(r.per100?.f, 9)
        XCTAssertEqual(r.per100?.c, 30)
        XCTAssertEqual(r.per100?.p, 12)
    }

    func testBarcodeVariants() {
        XCTAssertEqual(Barcode.variants("737628064502"), ["737628064502", "0737628064502"])
        XCTAssertEqual(Barcode.variants("0737628064502"), ["0737628064502", "737628064502"])
    }
}

final class RoleMapTests: XCTestCase {
    func testRulesLoad() {
        XCTAssertGreaterThan(RoleMap.rules.count, 100)
        for r in RoleMap.rules {
            if let k = r.kind { XCTAssertNotNil(Catalog.food(k), "нет вида \(k) в каталоге") }
        }
    }

    func testClassify() {
        XCTAssertEqual(RoleMap.classify(categories: [], name: "Lay's Classic Potato Chips").0, .snack)
        XCTAssertEqual(RoleMap.classify(categories: ["en:greek-style-yogurts"], name: "Chobani").1, "c:greek_yogurt_0")
        XCTAssertEqual(RoleMap.classify(categories: [], name: "Perdue chicken breast strips").1, "c:chicken_breast")
        XCTAssertEqual(RoleMap.classify(categories: [], name: "Tropicana orange juice").0, .drink)
    }
}

final class CatalogTests: XCTestCase {
    func testCatalogSane() {
        var ids = Set<String>()
        for f in Catalog.all {
            XCTAssertTrue(ids.insert(f.id).inserted, "повтор \(f.id)")
            XCTAssertFalse(f.name.isEmpty)
            if f.role != .spice {
                let calc = f.per100.kcalFromMacros
                // Калории согласуются с БЖУ (клетчатка и округления дают разницу).
                XCTAssertLessThan(abs(calc - f.per100.kcal), max(45, f.per100.kcal * 0.2), "\(f.name): \(f.per100.kcal) против \(calc)")
            }
        }
        for id in Catalog.defaultStapleIDs { XCTAssertNotNil(Catalog.food(id), id) }
        XCTAssertEqual(Catalog.search("куриное").first?.role, .meat)
        XCTAssertNotNil(Catalog.matchVisionLabel("banana"))
    }

    func testWith() {
        XCTAssertEqual(Say.with("сметаной"), "со сметаной")
        XCTAssertEqual(Say.with("сыром"), "с сыром")
        XCTAssertEqual(Say.with("шпинатом"), "со шпинатом")
        XCTAssertEqual(Say.with("курицей"), "с курицей")
    }
}

final class PlannerTests: XCTestCase {
    func item(_ id: String, _ grams: Double? = nil, _ place: Place = .fridge) -> PantryItem {
        PantryItem(food: Catalog.food(id)!, grams: grams, place: place)
    }

    var staples: [Food] { Catalog.defaultStapleIDs.compactMap { Catalog.food($0) } }

    var pantry: [PantryItem] {
        [item("c:chicken_breast", 1500, .freezer), item("c:ground_beef_90", 900), item("c:egg", 600),
         item("c:rice_white", 2000, .cupboard), item("c:buckwheat", 900, .cupboard), item("c:pasta", 900, .cupboard),
         item("c:oats", 1000, .cupboard), item("c:cottage_5", 500), item("c:greek_yogurt_0", 900),
         item("c:milk_2", 2000), item("c:banana", 600, .table), item("c:apple", 800), item("c:broccoli_frozen", 900, .freezer),
         item("c:onion", 500), item("c:carrot", 500), item("c:tomato", 500), item("c:cucumber", 450),
         item("c:hard_cheese", 300), item("c:bread_whole", 600, .cupboard), item("c:almonds", 300, .cupboard),
         item("c:tuna_water", 420, .cupboard), item("c:potato", 2000, .cupboard)]
    }

    func testPlanHitsTarget() {
        let target = Profile().computedTarget
        var worst = 0.0
        for seed in 1...8 {
            let input = PlannerInput(pantry: pantry, staples: staples, target: target, options: PlanOptions(mealCount: 4), seed: UInt64(seed))
            let plan = Planner.generate(input)
            XCTAssertEqual(plan.meals.count, 4)
            let t = plan.macros
            let dk = abs(t.kcal - target.kcal) / target.kcal
            worst = max(worst, dk)
            XCTAssertLessThan(dk, 0.05, "калории \(t.kcal) при цели \(target.kcal), seed \(seed)")
            XCTAssertGreaterThan(t.p, target.p - 12, "белок \(t.p), seed \(seed)")
            for m in plan.meals {
                XCTAssertFalse(m.title.isEmpty)
                XCTAssertFalse(m.steps.isEmpty, m.title)
                for s in m.steps { XCTAssertFalse(s.contains("  "), s); XCTAssertFalse(s.contains(" ."), s) }
            }
        }
        print("Худшее отклонение калорий: \(Int(worst * 1000) / 10)%")
    }

    func testLimitsRespected() {
        let target = Macros(kcal: 2600, p: 200, f: 80, c: 260)
        let small = [item("c:chicken_breast", 300), item("c:rice_white", 150), item("c:egg", 200),
                     item("c:oats", 500), item("c:milk_2", 1000), item("c:banana", 240), item("c:greek_yogurt_0", 500)]
        let input = PlannerInput(pantry: small, staples: staples, target: target, options: PlanOptions(mealCount: 4), seed: 7)
        let plan = Planner.generate(input)
        var used: [String: Double] = [:]
        for m in plan.meals { for i in m.ingredients { used[i.food.id, default: 0] += i.grams } }
        for p in small {
            XCTAssertLessThanOrEqual(used[p.food.id] ?? 0, (p.grams ?? .infinity) + 0.5, p.food.name)
        }
        XCTAssertFalse(plan.buy.isEmpty, "при нехватке белка должен быть список покупок")
    }

    func testReplaceMeal() {
        let target = Profile().computedTarget
        let input = PlannerInput(pantry: pantry, staples: staples, target: target, options: PlanOptions(mealCount: 4), seed: 3)
        let plan = Planner.generate(input)
        var next = input; next.seed = 99
        let changed = Planner.replace(meal: 1, in: plan, input: next)
        XCTAssertEqual(changed.meals.count, plan.meals.count)
        XCTAssertEqual(changed.meals[0], plan.meals[0])
        XCTAssertNotEqual(changed.meals[1].title, plan.meals[1].title)
        let dk = abs(changed.macros.kcal - target.kcal) / target.kcal
        XCTAssertLessThan(dk, 0.08)
    }

    /// Прогон по случайным запасам: ни один шаблон не должен падать или давать пустой текст.
    /// Примеры дней записываются в файл — их читает человек, проверяя русский текст рецептов.
    func testRandomPantriesAndSamples() throws {
        var rng = SplitMix64(seed: 2026)
        let foods = Catalog.all.filter { ![.spice, .sauce, .fat, .drink].contains($0.role) && $0.id != "c:flour" && $0.id != "c:sugar" }
        var report = ""
        let options = [PlanOptions(mealCount: 3), PlanOptions(mealCount: 4, portableLunch: true),
                       PlanOptions(mealCount: 5, maxMinutes: 30), PlanOptions(mealCount: 6, noOven: true, sweetSnack: true),
                       PlanOptions(mealCount: 5, proteinDessert: true), PlanOptions(mealCount: 4, fewDishes: true, proteinDessert: true)]
        var templateUse: [String: Int] = [:]
        for run in 0..<90 {
            let n = Int.random(in: 8...26, using: &rng)
            let chosen = foods.shuffled(using: &rng).prefix(n)
            let pantry = chosen.map { PantryItem(food: $0, grams: Bool.random(using: &rng) ? nil : Double(Int.random(in: 2...20, using: &rng) * 100)) }
            let target = Macros(kcal: Double(Int.random(in: 18...32, using: &rng) * 100), p: Double(Int.random(in: 12...22, using: &rng) * 10),
                                f: Double(Int.random(in: 5...9, using: &rng) * 10), c: Double(Int.random(in: 15...30, using: &rng) * 10))
            let opt = options[run % options.count]
            let input = PlannerInput(pantry: Array(pantry), staples: staples, target: target, options: opt, seed: UInt64(run))
            let plan = Planner.generate(input, attempts: 200)
            for m in plan.meals {
                templateUse[m.templateID, default: 0] += 1
                XCTAssertFalse(m.title.isEmpty)
                XCTAssertFalse(m.title.contains("  "), m.title)
                XCTAssertFalse(m.steps.isEmpty, m.templateID)
                for s in m.steps { XCTAssertFalse(s.contains("  ") || s.contains(" ,") || s.contains(",,"), "\(m.templateID): \(s)") }
            }
            if run < 24 {
                report += describe(plan, title: "Запуск \(run): \(n) продуктов, \(opt.mealCount) приёмов")
            }
        }
        report += "\nИспользование шаблонов: " + templateUse.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ") + "\n"
        let unused = Templates.all.map { $0.id }.filter { templateUse[$0] == nil }
        report += "Ни разу не выбраны: \(unused.joined(separator: ", "))\n"
        let dir = ProcessInfo.processInfo.environment["REPORT_DIR"] ?? FileManager.default.temporaryDirectory.path
        try report.write(toFile: dir + "/sample_plans.txt", atomically: true, encoding: .utf8)
    }

    /// Каждый шаблон на «полном холодильнике»: текст всех рецептов в файл для проверки человеком.
    func testEveryTemplateText() throws {
        let everything = Catalog.all.filter { $0.role != .spice && $0.role != .drink }.map { PantryItem(food: $0, grams: nil) }
        let input = PlannerInput(pantry: everything, staples: staples, target: Profile().computedTarget, options: PlanOptions(), seed: 1)
        let pool = Planner.makePool(input)
        var rng = SplitMix64(seed: 77)
        var report = ""
        for t in Templates.all {
            var made = 0
            for _ in 0..<40 where made < 3 {
                let slot = MealSlot(name: "Проба", kind: t.kinds.first ?? .main, time: "12:00", share: 0.3)
                guard var d = Planner.fill(template: t, slot: slot, pool: pool, opt: input.options, usedMain: [:], rng: &rng) else { continue }
                var ds = [d]
                Planner.solve(&ds, target: Macros(kcal: 700, p: 50, f: 25, c: 70))
                d = ds[0]
                guard let m = Planner.makeMeal(d, input: input) else { continue }
                made += 1
                XCTAssertFalse(m.title.isEmpty, t.id)
                XCTAssertFalse(m.title.contains("  "), "\(t.id): \(m.title)")
                for s in m.steps {
                    XCTAssertFalse(s.contains("  ") || s.contains(" ,") || s.contains(",,") || s.contains(" .") || s.contains(".."), "\(t.id): \(s)")
                }
                report += "\n[\(t.id)] \(m.title)\n"
                for i in m.ingredients where !i.locked { report += "   • \(i.food.name) — \(Int(i.grams)) г\n" }
                let sp = m.ingredients.filter { $0.locked }.map { $0.food.name }
                if !sp.isEmpty { report += "   • по вкусу: \(sp.joined(separator: ", "))\n" }
                for (k, st) in m.steps.enumerated() { report += "   \(k + 1). \(st)\n" }
            }
            XCTAssertGreaterThan(made, 0, "шаблон \(t.id) не собрался даже из всего каталога")
        }
        let dir = ProcessInfo.processInfo.environment["REPORT_DIR"] ?? FileManager.default.temporaryDirectory.path
        try report.write(toFile: dir + "/all_templates.txt", atomically: true, encoding: .utf8)
    }

    func testProteinDessert() {
        let home = [item("c:cottage_5", 1000), item("c:egg", 600), item("c:whey", 500), item("c:chicken_breast", 1000),
                    item("c:rice_white", 1000), item("c:semolina", 500), item("c:oats", 500), item("c:milk_2", 1000),
                    item("c:banana", 500), item("c:broccoli", 500), item("c:greek_yogurt_0", 500)]
        let target = Profile().computedTarget
        for (i, count) in [3, 4, 5, 6].enumerated() {
            let input = PlannerInput(pantry: home, staples: staples, target: target,
                                     options: PlanOptions(mealCount: count, proteinDessert: true), seed: UInt64(10 + i))
            let plan = Planner.generate(input, attempts: 150)
            XCTAssertTrue(plan.meals.contains { Templates.byID($0.templateID)?.dessert == true },
                          "нет десерта при \(count) приёмах: \(plan.meals.map { $0.templateID })")
            let dk = abs(plan.macros.kcal - target.kcal) / target.kcal
            XCTAssertLessThan(dk, 0.06, "калории \(plan.macros.kcal) при \(count) приёмах")
        }
    }

    func testOldOptionsDecode() throws {
        let old = #"{"mealCount":5,"firstMeal":"06:30","portableLunch":true,"noOven":false,"fewDishes":false,"cookForTwoDays":false,"sweetSnack":true,"noFish":false,"noPork":false,"vegetarian":false}"#
        let o = try JSONDecoder().decode(PlanOptions.self, from: Data(old.utf8))
        XCTAssertEqual(o.mealCount, 5)
        XCTAssertTrue(o.portableLunch)
        XCTAssertFalse(o.proteinDessert)
    }

    func describe(_ plan: DayPlan, title: String) -> String {
        let t = plan.macros, T = plan.target
        var s = "\n══ \(title)\nЦель \(Int(T.kcal)) ккал Б\(Int(T.p)) Ж\(Int(T.f)) У\(Int(T.c)) → план \(Int(t.kcal)) ккал Б\(Int(t.p)) Ж\(Int(t.f)) У\(Int(t.c))\n\(plan.note)\n"
        if !plan.buy.isEmpty { s += "Докупить: \(plan.buy.joined(separator: ", "))\n" }
        for m in plan.meals {
            let mm = m.macros
            s += "\n\(m.slot.time) \(m.slot.name) — \(m.title) [\(m.templateID), \(m.minutes) мин] \(Int(mm.kcal)) ккал Б\(Int(mm.p)) Ж\(Int(mm.f)) У\(Int(mm.c))\n"
            for i in m.ingredients { s += "   • \(i.food.name) — \(i.locked ? "по вкусу" : "\(Int(i.grams)) г") \(i.measure)\n" }
            for (k, st) in m.steps.enumerated() { s += "   \(k + 1). \(st)\n" }
            if !m.tip.isEmpty { s += "   Совет: \(m.tip)\n" }
        }
        return s
    }
}
