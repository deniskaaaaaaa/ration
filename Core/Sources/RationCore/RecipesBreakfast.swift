import Foundation

// Завтраки и перекусы: каши, тосты, ленивые вареники, закуски.

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

extension Templates {
    static func breakfasts() -> [DishTemplate] {
        var t: [DishTemplate] = []

        t.append(T("avocado_toast", [.breakfast, .snack], minutes: 10,
            slots: [S("b", [.bread], tags: ["slice", "bun"], range: 30...80),
                    S("av", [.vegetable], tags: ["avocado"], range: 50...100),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...120, main: true),
                    S("t", [.vegetable], req: false, tags: ["tomato"]),
                    S("fi", [.fish, .cheese], req: false, tags: ["salted", "salad"], no: ["herring"], cooks: [.noCook], range: 30...70)],
            extras: [X("fat", Templates.fat, 3...5)],
            spices: ["c:salt", "c:pepper", "c:chili", "c:lemon_juice"], onePan: true,
            title: { f in "Тост с авокадо " + Say.with(Say.list(["яйцом"] + RK.I([f["fi"]]))) },
            steps: { f in
                guard let b = f["b"], let av = f["av"] else { return [] }
                let lemon = RK.on(f, "c:lemon_juice")
                var s = ["Подсуши \(b.words.acc) в тостере или на сухой сковороде.",
                         "Разомни \(av.words.acc) вилкой с солью\(lemon ? ", перцем и лимонным соком" : " и перцем").",
                         "Пожарь яйца на капле масла 3 минуты или свари всмятку."]
                if let tm = f["t"] { s.append("Нарежь \(tm.words.acc) кружочками.") }
                let top = ["яйца"] + RK.A([f["t"], f["fi"]])
                s.append("Намажь авокадо на тосты, сверху выложи \(Say.list(top)).")
                if RK.on(f, "c:chili") { s.append("Посыпь щепоткой чили.") }
                return s
            }))

        t.append(T("overnight_oats", [.breakfast, .snack], minutes: 5,
            slots: [S("o", [.oats], tags: ["oats"], range: 40...80, main: true),
                    S("m", [.milk, .yogurt], no: ["dessert_ready"], range: 150...250),
                    S("pr", [.protein], req: false, no: ["gainer"], range: 15...30),
                    S("ch", [.nuts], req: false, tags: ["chia"], range: 5...15),
                    S("fr", [.fruit, .berries], req: false, no: ["dried"])],
            extras: [X("sw", RK.syrup, 5...15)],
            portable: true, sweet: true,
            title: { f in "Ленивая овсянка в банке" + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                var s = ["Смешай в банке \(Say.list(RK.A([f["o"], f["m"], f["pr"], f["ch"], f["sw"]]))).",
                         "Закрой крышкой и убери в холодильник на ночь."]
                if let x = RK.top(f["fr"]) { s.append(x) }
                return s
            },
            tip: { _ in "Ешь холодной прямо из банки или разогрей 1 минуту в микроволновке." }))

        t.append(T("buckwheat_milk", [.breakfast], minutes: 25,
            slots: [S("g", [.grain], tags: ["buckwheat"], range: 40...80, main: true),
                    S("m", [.milk], no: ["rtd"], range: 150...250)],
            extras: [X("but", ["c:butter"], 3...8), X("sw", ["c:honey", "c:sugar", "c:sweetener"], 5...12)],
            spices: ["c:salt"], sweet: true,
            title: { f in "Гречка " + Say.with(f["m"].map { $0.words.ins } ?? "молоком") },
            steps: { f in
                guard let g = f["g"], let m = f["m"] else { return [] }
                var s = [Say.side(g), "Залей горячую гречку \(m.words.ins) прямо в тарелке — тёплым или холодным, как любишь."]
                if let b = f["but"] { s.append("Добавь \(b.words.acc).") }
                if let x = RK.sweeten(f["sw"]) { s.append(x) }
                return s
            }))

        t.append(T("millet_porridge", [.breakfast], minutes: 30,
            slots: [S("g", [.grain], tags: ["millet"], range: 40...80, main: true),
                    S("m", [.milk], no: ["rtd", "kefir"], range: 200...350),
                    S("v", [.vegetable], req: false, tags: ["pumpkin"], range: 100...200)],
            extras: [X("but", ["c:butter"], 3...8), X("sw", ["c:honey", "c:sugar", "c:sweetener"], 5...15)],
            spices: ["c:salt"], sweet: true,
            title: { f in "Пшённая каша" + (f["v"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let g = f["g"], let m = f["m"] else { return [] }
                var s = ["Промой \(g.words.acc) горячей водой 2–3 раза."]
                if let v = f["v"] { s.append("Почисть \(v.words.acc) и нарежь мелкими кубиками.") }
                s.append("Залей крупу\(f["v"] != nil ? " вместе с тыквой" : "") \(m.words.ins), добавь щепотку соли и доведи до кипения.")
                s.append("Вари на слабом огне 20–25 минут, помешивая, пока пшено не разварится.")
                if let b = f["but"] { s.append("Положи в готовую кашу \(b.words.acc).") }
                if let x = RK.sweeten(f["sw"]) { s.append(x) }
                return s
            }))

        t.append(T("french_toast", [.breakfast], minutes: 15,
            slots: [S("b", [.bread], tags: ["slice", "bun"], range: 50...120),
                    S("e", [.eggs], no: ["quail"], range: 50...120, main: true),
                    S("m", [.milk], req: false, no: ["rtd", "kefir"], range: 50...100),
                    S("fr", [.berries, .fruit], req: false, no: ["dried"]),
                    S("y", [.yogurt, .cottage], req: false, no: ["dessert_ready"], range: 50...120)],
            extras: [X("fat", Templates.fat, 4...8), X("sw", ["c:maple_syrup", "c:honey", "c:jam"], 10...20)],
            spices: ["c:cinnamon", "c:vanilla", "c:salt"], onePan: true, sweet: true,
            title: { f in "Французские тосты" + (f["y"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let b = f["b"] else { return [] }
                let cin = RK.on(f, "c:cinnamon")
                var s = ["Взбей \(Say.list(RK.A([f["e"], f["m"]]))) с щепоткой соли\(cin ? " и корицей" : "").",
                         "Обмакни \(b.words.acc) в смесь с двух сторон.",
                         "Обжарь на масле по 2 минуты с каждой стороны до румяной корочки."]
                if let y = f["y"] { s.append("Подавай \(Say.with(y.words.ins)).") }
                if let x = RK.top(f["fr"]) { s.append(x) }
                if let x = RK.sweeten(f["sw"]) { s.append(x) }
                return s
            }))

        t.append(T("egg_muffins", [.breakfast, .snack], minutes: 25,
            slots: [S("e", [.eggs], range: 150...300, main: true),
                    S("v", [.vegetable, .greens], req: false, no: ["fatty", "raw", "herb", "hot"]),
                    S("s", [.sausage, .meat], req: false, cooks: [.noCook, .cookedMeat, .sausage, .bacon], range: 30...80),
                    S("c", [.cheese], req: false, tags: ["melt", "salad", "grate"], no: ["stick"], range: 20...50)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:italian_herbs"], oven: true, portable: true,
            title: { f in "Яичные маффины" + (f.all(["s", "c"]).isEmpty ? "" : " " + Say.with(Say.list(RK.I([f["s"], f["c"]])))) },
            steps: { f in
                var s = ["Разогрей духовку до 180 °C."]
                if let v = f["v"] { s += Say.vegPrep([v]) }
                if let x = f["s"] { s.append("Мелко нарежь \(x.words.acc).") }
                if let c = f["c"] { s.append("Натри \(c.words.acc).") }
                s.append("Взбей яйца с солью и перцем.")
                let fill = RK.A([f["v"], f["s"], f["c"]])
                if fill.isEmpty { s.append("Разлей яйца по формочкам для маффинов на две трети.") }
                else { s.append("Разложи \(Say.list(fill)) по формочкам для маффинов и залей яйцами на две трети.") }
                s.append("Запекай 18–20 минут, пока яйца не схватятся.")
                return s
            },
            tip: { _ in "Храни в холодильнике до 4 дней и разогревай 30 секунд в микроволновке." }))

        t.append(T("lazy_vareniki", [.breakfast, .main, .snack], minutes: 25,
            slots: [S("y", [.cottage], no: ["grainy"], range: 200...350, main: true),
                    S("e", [.eggs], no: ["quail"], range: 50...60),
                    S("sc", [.sauce, .yogurt], req: false, tags: ["dairy", "greek"], no: ["cream"], range: 30...80),
                    S("fr", [.berries], req: false)],
            extras: [X("fl", ["c:flour", "c:rice_flour", "c:oat_flour"], 40...70, req: true),
                     X("sw", ["c:sugar", "c:sweetener", "c:honey"], 5...15)],
            spices: ["c:salt", "c:vanilla"], sweet: true,
            title: { f in "Ленивые вареники" + (f["sc"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let y = f["y"], let fl = f["fl"] else { return [] }
                var mix = ["яйцом"] + RK.I([f["sw"]])
                mix.append("щепоткой соли")
                var s = ["Разомни \(y.words.acc) вилкой \(Say.with(Say.list(mix))).",
                         "Добавь \(fl.words.acc) и замеси мягкое липкое тесто.",
                         "Раскатай тесто колбаской толщиной 2 см на присыпанном мукой столе и нарежь кусочками.",
                         "Опусти в кипящую подсоленную воду и вари 2–3 минуты после всплытия."]
                if let sc = f["sc"] { s.append("Подавай \(Say.with(sc.words.ins)).") }
                if let fr = f["fr"] { s.append("Добавь \(fr.words.acc).") }
                return s
            },
            tip: { _ in "Налепи сразу двойную порцию и заморозь на доске — потом вари прямо из морозилки." }))

        t.append(T("blini_cottage", [.breakfast, .snack], minutes: 35,
            slots: [S("m", [.milk], no: ["rtd"], range: 200...300),
                    S("e", [.eggs], no: ["quail"], range: 50...100),
                    S("y", [.cottage], range: 150...300, main: true),
                    S("fr", [.berries, .fruit], req: false, range: 20...100),
                    S("sc", [.sauce, .yogurt], req: false, tags: ["dairy", "greek"], no: ["cream"], range: 30...60)],
            extras: [X("fl", ["c:flour", "c:oat_flour", "c:rice_flour"], 80...130, req: true),
                     X("sw", ["c:sugar", "c:sweetener", "c:honey"], 5...20), X("fat", Templates.fat, 5...10)],
            spices: ["c:salt", "c:vanilla"], sweet: true,
            title: { f in "Блинчики с творогом" + (f["sc"].map { " и " + $0.words.ins } ?? "") },
            steps: { f in
                guard let m = f["m"], let e = f["e"], let y = f["y"], let fl = f["fl"] else { return [] }
                var whisk = [m.words.ins] + RK.I([f["sw"]])
                whisk.append("щепоткой соли")
                var s = ["Взбей \(e.words.acc) \(Say.with(Say.list(whisk)))."]
                s.append("Постепенно всыпь \(fl.words.acc) и размешай до жидкого теста без комков, добавь ложку масла.")
                s.append("Разогрей сковороду и жарь тонкие блины по минуте с каждой стороны.")
                if let fr = f["fr"] {
                    if fr.role != .berries && !fr.has("dried") { s.append("Нарежь \(fr.words.acc) мелкими кубиками.") }
                    s.append("Смешай \(y.words.acc) \(Say.with(fr.words.ins)).")
                } else {
                    s.append("Разомни \(y.words.acc) вилкой.")
                }
                s.append("Положи на каждый блин ложку творога и сверни конвертом.")
                if let sc = f["sc"] { s.append("Подавай \(Say.with(sc.words.ins)).") }
                return s
            },
            tip: { _ in "Свёрнутые блинчики можно заморозить и разогревать на сковороде." }))

        t.append(T("cottage_herbs", [.snack, .evening, .breakfast], minutes: 5,
            slots: [S("y", [.cottage], range: 150...300, main: true),
                    S("h", [.greens], tags: ["herb"], range: 5...15),
                    S("v", [.vegetable], req: false, tags: ["raw", "tomato"], no: ["fatty", "pickled"]),
                    S("b", [.bread], req: false, tags: ["crisp", "slice"], range: 20...60)],
            extras: [X("sc", ["c:sour_cream_10", "c:sour_cream"], 15...30)],
            spices: ["c:salt", "c:pepper", "c:garlic"], portable: true,
            title: { f in RK.on(f, "c:garlic") ? "Творог с зеленью и чесноком" : "Творог с зеленью" },
            steps: { f in
                guard let y = f["y"], let h = f["h"] else { return [] }
                var s = ["Мелко порежь \(h.words.acc)."]
                if RK.on(f, "c:garlic") { s.append("Выдави зубчик чеснока.") }
                let mix = [h.words.ins] + RK.I([f["sc"]])
                s.append("Смешай \(y.words.acc) \(Say.with(Say.list(mix))), посоли и поперчи.")
                if let v = f["v"] { s += Say.vegPrep([v]) }
                if let x = RK.serve([f["v"], f["b"]]) { s.append(x) }
                return s
            }))

        t.append(T("stuffed_eggs", [.snack, .evening], minutes: 20,
            slots: [S("e", [.eggs], no: ["whites", "quail"], range: 150...250, main: true),
                    S("fi", [.fish], req: false, tags: ["canned", "salted", "crab"], no: ["herring"], range: 40...100),
                    S("c", [.cheese, .cottage], req: false, no: ["dessert", "stick", "grill"], range: 20...60),
                    S("h", [.greens], req: false, tags: ["herb"], range: 3...10)],
            extras: [X("sc", ["c:sour_cream", "c:mayo_light", "c:mayo"], 15...30, req: true)],
            spices: ["c:salt", "c:pepper", "c:garlic_dry", "c:paprika"], portable: true,
            title: { f in "Фаршированные яйца" + (RK.I([f["fi"], f["c"]]).isEmpty ? "" : " " + Say.with(Say.list(RK.I([f["fi"], f["c"]])))) },
            steps: { f in
                guard let sc = f["sc"] else { return [] }
                var s = [RK.boiled(false), "Разрежь яйца пополам и достань желтки."]
                if let fi = f["fi"], let pr = Say.prep(fi) { s.append(pr) }
                if let h = f["h"] { s.append("Мелко порежь \(h.words.acc).") }
                let mix = RK.I([f["fi"], f["c"], sc, f["h"]])
                s.append("Разомни желтки вилкой \(Say.with(Say.list(mix))), посоли и поперчи.")
                s.append("Наполни белки начинкой горкой.")
                if RK.on(f, "c:paprika") { s.append("Посыпь паприкой.") }
                return s
            }))

        t.append(T("greek_salad", [.main, .snack], minutes: 10,
            slots: [S("c", [.cheese], tags: ["salad"], range: 50...100, main: true),
                    S("v", [.vegetable], tags: ["cucumber"]),
                    S("t", [.vegetable], tags: ["tomato"]),
                    S("v2", [.vegetable], req: false, tags: ["pepper"], no: ["hot"]),
                    S("ol", [.vegetable], req: false, tags: ["fatty"], no: ["avocado"], range: 20...50),
                    S("b", [.bread], req: false, tags: ["pocket", "slice"], range: 30...70)],
            extras: [X("dr", ["c:olive_oil", "c:sunflower_oil"], 8...15, req: true)],
            spices: ["c:salt", "c:oregano", "c:pepper", "c:lemon_juice"], portable: true, weight: 0.6,
            title: { _ in "Греческий салат" },
            steps: { f in
                guard let c = f["c"], let dr = f["dr"] else { return [] }
                var s = ["Нарежь крупными кусками \(Say.list(RK.A([f["v"], f["t"], f["v2"]])))."]
                if let ol = f["ol"] { s.append("Добавь \(ol.words.acc).") }
                var add: [String] = []
                if RK.on(f, "c:oregano") { add.append("посыпь орегано") }
                if RK.on(f, "c:lemon_juice") { add.append("сбрызни лимонным соком") }
                s.append("Заправь \(dr.words.ins)\(add.isEmpty ? "" : ", " + add.joined(separator: ", ")) и посоли.")
                s.append("Выложи сверху \(c.words.acc) крупными кубиками.")
                if let b = f["b"] { s.append("Подавай \(Say.with(b.words.ins)).") }
                return s
            }))

        return t
    }
}
