import Foundation

// Протеиновые десерты: творог, манка, протеин, яйца, йогурт.

private func S(_ key: String, _ roles: [Role], req: Bool = true, tags: [String] = [], no: [String] = [],
               cooks: [Cook]? = nil, noCooks: [Cook] = [], range: ClosedRange<Double>? = nil, main: Bool = false) -> SlotSpec {
    SlotSpec(key: key, roles: Set(roles), required: req, anyTags: tags, noTags: no,
             cooks: cooks.map { Set($0) }, noCooks: Set(noCooks), range: range, main: main)
}

private func X(_ key: String, _ kinds: [String], _ range: ClosedRange<Double>, req: Bool = false,
               when: ((Fill) -> Bool)? = nil) -> ExtraSpec {
    ExtraSpec(key: key, alts: kinds.map { ($0, range) }, required: req, when: when)
}

private func T(_ id: String, _ kinds: [MealKind], minutes: Int, slots: [SlotSpec], extras: [ExtraSpec] = [],
               spices: [String] = [], oven: Bool = false, portable: Bool = false, onePan: Bool = false,
               sweet: Bool = true, dessert: Bool = true, weight: Double = 1,
               check: @escaping (Fill) -> Bool = { _ in true },
               title: @escaping (Fill) -> String,
               steps: @escaping (Fill) -> [String],
               tip: @escaping (Fill) -> String = { _ in "" }) -> DishTemplate {
    DishTemplate(id: id, kinds: Set(kinds), slots: slots, extras: extras, spices: spices, minutes: minutes,
                 oven: oven, portable: portable, onePan: onePan, sweet: sweet || dessert, dessert: dessert, weight: weight,
                 check: check, title: title, steps: steps, tip: tip)
}

/// Протеин в десертах: без гейнера.
private func PR(_ range: ClosedRange<Double>, req: Bool = false, main: Bool = false) -> SlotSpec {
    S("pr", [.protein], req: req, no: ["gainer"], range: range, main: main)
}

extension Templates {
    static func desserts() -> [DishTemplate] {
        var t: [DishTemplate] = []

        t.append(T("cheesecake_pro", [.snack, .evening, .breakfast], minutes: 70,
            slots: [S("y", [.cottage], range: 200...400, main: true),
                    S("y2", [.cheese, .yogurt], req: false, tags: ["soft", "spread", "greek"], no: ["fatty"], range: 50...150),
                    S("e", [.eggs], range: 50...120),
                    PR(15...35),
                    S("cb", [.snack], req: false, tags: ["biscuit"], range: 20...50),
                    S("fr", [.berries, .fruit], req: false, tags: ["bake"], range: 50...120)],
            extras: [X("st", ["c:starch", "c:semolina", "c:flour"], 10...20), X("sw", RK.sweet, 5...25)],
            spices: ["c:vanilla"], oven: true,
            title: { f in "Протеиновый чизкейк" + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let y = f["y"] else { return [] }
                var s = ["Разогрей духовку до 160 °C."]
                if let cb = f["cb"] { s.append("Измельчи \(cb.words.acc) в крошку и утрамбуй на дно небольшой формы.") }
                var mix = [y.words.acc] + RK.A([f["y2"], f["e"], f["pr"], f["st"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:vanilla"])
                s.append("Пробей блендером до гладкости \(Say.list(mix)).")
                s.append(f["cb"] == nil ? "Вылей массу в форму." : "Вылей массу в форму поверх основы.")
                if let fr = f["fr"] {
                    s.append(fr.role == .berries ? "Разложи сверху \(fr.words.acc)." : "Нарежь \(fr.words.acc) тонкими дольками и разложи сверху.")
                }
                s.append("Запекай 40–45 минут: края схватятся, а центр должен чуть дрожать.")
                s.append("Оставь чизкейк в выключенной духовке на 20 минут, потом убери в холодильник минимум на 2 часа.")
                return s
            },
            tip: { _ in "Испеки с вечера — за ночь в холодильнике чизкейк станет плотным." }))

        t.append(T("mannik_pro", [.breakfast, .snack], minutes: 60,
            slots: [S("sm", [.oats], tags: ["semolina"], range: 50...100, main: true),
                    S("liq", [.milk, .yogurt], no: ["rtd", "dessert_ready"], range: 120...250),
                    S("e", [.eggs], no: ["quail"], range: 50...100),
                    PR(15...35),
                    S("fr", [.berries, .fruit], req: false, tags: ["bake"], range: 50...150)],
            extras: [X("sw", RK.sweet, 10...30)],
            spices: ["c:baking_powder", "c:vanilla", "c:salt"], oven: true,
            title: { f in
                let base = f["pr"] != nil ? "Протеиновый манник" : "Манник"
                return base + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let sm = f["sm"], let liq = f["liq"] else { return [] }
                var s = ["Смешай \(sm.words.acc) \(Say.with(liq.words.ins)) и оставь на 20–30 минут, чтобы манка набухла.",
                         "Разогрей духовку до 180 °C."]
                var add = RK.A([f["e"], f["pr"], f["sw"]])
                add += RK.spiceAcc(f, ["c:baking_powder", "c:vanilla"])
                s.append("Добавь \(Say.list(add)) и перемешай до однородности.")
                if let x = RK.into(f["fr"]) { s.append(x) }
                s.append("Вылей тесто в форму, застеленную пергаментом, и выпекай 30–35 минут, пока верх не зарумянится.")
                s.append("Дай остыть 10 минут и только потом нарезай.")
                return s
            },
            tip: { _ in "Без духовки: в микроволновке 6–7 минут на полной мощности в широкой миске." }))

        t.append(T("zapekanka", [.breakfast, .snack, .evening], minutes: 50,
            slots: [S("y", [.cottage], range: 200...450, main: true),
                    S("e", [.eggs], no: ["quail"], range: 50...120),
                    S("fr", [.berries, .fruit], req: false, tags: ["bake", "dried"], range: 40...150),
                    PR(15...30),
                    S("sc", [.sauce, .yogurt], req: false, tags: ["dairy", "greek"], no: ["cream"], range: 30...80)],
            extras: [X("sm", ["c:semolina", "c:oats", "c:oat_flour", "c:flour"], 20...45, req: true), X("sw", RK.sweet, 10...25)],
            spices: ["c:vanilla", "c:salt"], oven: true,
            title: { f in
                if let fr = f["fr"] { return "Творожная запеканка " + Say.with(fr.words.ins) }
                return f["sm"]?.isKind("c:semolina") == true ? "Творожная запеканка с манкой" : "Творожная запеканка"
            },
            steps: { f in
                guard let y = f["y"], let sm = f["sm"] else { return [] }
                var mix = ["яйцами", sm.words.ins] + RK.I([f["pr"], f["sw"]])
                if RK.on(f, "c:vanilla") { mix.append("ванилином") }
                var s = ["Смешай \(y.words.acc) \(Say.with(Say.list(mix)))."]
                if sm.isKind("c:semolina") { s.append("Оставь на 15 минут, чтобы манка набухла.") }
                if sm.isKind("c:oats") { s.append("Оставь на 15 минут, чтобы хлопья набухли.") }
                s.append("Разогрей духовку до 180 °C.")
                if let x = RK.into(f["fr"]) { s.append(x) }
                s.append("Выложи массу в форму и выпекай 35–40 минут до золотистой корочки.")
                if let sc = f["sc"] { s.append("Подавай тёплой или холодной \(Say.with(sc.words.ins)).") }
                return s
            },
            tip: { _ in "Нарежь на порции — в холодильнике запеканка хранится до 3 дней." }))

        t.append(T("semolina_porridge", [.breakfast, .evening], minutes: 10,
            slots: [S("sm", [.oats], tags: ["semolina"], range: 40...80, main: true),
                    S("m", [.milk], no: ["rtd", "kefir"], range: 200...350),
                    PR(15...30),
                    S("fr", [.berries, .fruit], req: false),
                    S("n", [.nuts], req: false, no: ["spread"], range: 10...20)],
            extras: [X("but", ["c:butter"], 3...8), X("sw", ["c:honey", "c:jam", "c:sugar", "c:sweetener"], 5...15)],
            spices: ["c:salt"], dessert: false,
            title: { f in
                var add: [String] = []
                if f["pr"] != nil { add.append("протеином") }
                if let fr = f["fr"] { add.append(fr.words.ins) }
                return "Манная каша" + (add.isEmpty ? "" : " " + Say.with(Say.list(add)))
            },
            steps: { f in
                guard let sm = f["sm"], let m = f["m"] else { return [] }
                var s = ["Доведи \(m.words.acc) до кипения и добавь щепотку соли.",
                         "Всыпай \(sm.words.acc) тонкой струйкой, всё время помешивая, чтобы не было комков.",
                         "Вари на слабом огне 3–4 минуты, помешивая."]
                if let pr = f["pr"] { s.append("Сними с огня, дай остыть 2–3 минуты и вмешай \(pr.words.acc) — в кипящей каше протеин свернётся.") }
                if let b = f["but"] { s.append("Добавь \(b.words.acc).") }
                if let x = RK.top(f["fr"]) { s.append(x) }
                if let n = f["n"] { s.append("Посыпь \(n.words.ins).") }
                if let x = RK.sweeten(f["sw"]) { s.append(x) }
                return s
            },
            tip: { _ in "Две ложки манки на стакан молока — жидкая каша, три — густая." }))

        t.append(T("mug_cake", [.snack, .evening, .breakfast], minutes: 5,
            slots: [PR(25...40, req: true, main: true),
                    S("e", [.eggs], no: ["quail"], range: 50...60),
                    S("o", [.oats], req: false, tags: ["oats"], range: 20...30),
                    S("liq", [.milk, .yogurt], req: false, no: ["rtd", "dessert_ready"], range: 30...60),
                    S("fr", [.fruit, .berries], req: false, tags: ["bake"], range: 40...100),
                    S("n", [.nuts], req: false, tags: ["spread"], range: 10...15)],
            extras: [X("cc", ["c:cocoa"], 5...10), X("sw", RK.sweet, 5...15)],
            spices: ["c:baking_powder", "c:vanilla"], portable: true,
            title: { f in f["cc"] != nil ? "Шоколадный протеиновый кекс в кружке" : "Протеиновый кекс в кружке" },
            steps: { f in
                var mix = RK.A([f["e"], f["pr"], f["o"], f["liq"], f["cc"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:baking_powder", "c:vanilla"])
                var s = ["В большой кружке смешай вилкой \(Say.list(mix))."]
                if let x = RK.into(f["fr"]) { s.append(x) }
                if let n = f["n"] { s.append("Положи в центр \(n.words.acc) — внутри будет тягучая начинка.") }
                s.append("Готовь в микроволновке 60–90 секунд на 800 Вт: кекс поднимется и станет упругим.")
                s.append("Дай постоять минуту — так он не осядет.")
                return s
            },
            tip: { _ in "Если кекс вышел резиновым, в следующий раз держи на 15 секунд меньше." }))

        t.append(T("souffle", [.snack, .evening], minutes: 8,
            slots: [S("y", [.cottage, .yogurt], no: ["dessert_ready"], range: 150...250, main: true),
                    S("e", [.eggs], no: ["quail"], range: 50...100),
                    PR(10...25),
                    S("fr", [.berries], req: false, range: 40...100)],
            extras: [X("st", ["c:starch", "c:semolina"], 5...15), X("sw", RK.sweet, 5...15)],
            spices: ["c:vanilla"],
            title: { f in
                let base = f["y"]?.role == .cottage ? "Творожное суфле" : "Йогуртовое суфле"
                return base + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                var mix = RK.A([f["y"], f["e"], f["pr"], f["st"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:vanilla"])
                var s = ["Пробей блендером \(Say.list(mix)) до гладкой пышной массы.",
                         "Разложи по кружкам или силиконовым формочкам на две трети высоты."]
                if let fr = f["fr"] { s.append("Добавь сверху \(fr.words.acc).") }
                s.append("Готовь в микроволновке 3–4 минуты на 800 Вт: суфле поднимется, а потом немного осядет.")
                s.append("Дай остыть 5 минут — можно есть тёплым или из холодильника.")
                return s
            }))

        t.append(T("protein_pancakes", [.breakfast, .snack], minutes: 20,
            slots: [S("o", [.oats], tags: ["oats"], range: 40...80),
                    S("e", [.eggs], range: 50...150),
                    PR(15...35, main: true),
                    S("liq", [.milk, .yogurt, .cottage], no: ["rtd", "dessert_ready"], range: 80...200),
                    S("fr", [.fruit, .berries], req: false, no: ["dried"], range: 50...150),
                    S("top", [.yogurt], req: false, tags: ["greek"], range: 40...100)],
            extras: [X("sw", RK.syrup, 10...25), X("fat", Templates.fat, 3...5)],
            spices: ["c:baking_powder", "c:cinnamon", "c:salt"], onePan: true,
            title: { f in
                let base = f["pr"] != nil ? "Протеиновые панкейки" : "Овсяные панкейки"
                return base + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let o = f["o"] else { return [] }
                var s = ["Смели \(o.words.acc) в блендере в муку."]
                var add = RK.A([f["liq"], f["e"], f["pr"]])
                add += RK.spiceAcc(f, ["c:baking_powder", "c:cinnamon"])
                s.append("Добавь \(Say.list(add)) и взбей до однородного теста. Дай постоять 5 минут.")
                s.append("Разогрей сковороду с каплей масла на среднем огне.")
                s.append("Выкладывай тесто ложкой небольшими кружками и жарь по 1–2 минуты с каждой стороны, пока не появятся пузырьки и румяный цвет.")
                if let top = f["top"] { s.append("Подавай \(Say.with(top.words.ins)).") }
                if let x = RK.top(f["fr"]) { s.append(x) }
                if let x = RK.sweeten(f["sw"]) { s.append(x) }
                return s
            },
            tip: { _ in "Тесто можно замешать с вечера и держать в холодильнике в банке." }))

        t.append(T("syrniki_oven", [.breakfast, .snack], minutes: 30,
            slots: [S("y", [.cottage], no: ["grainy"], range: 200...350, main: true),
                    S("e", [.eggs], no: ["quail"], range: 50...100),
                    PR(10...25),
                    S("fr", [.berries, .fruit], req: false, no: ["dried"]),
                    S("sc", [.sauce, .yogurt], req: false, tags: ["dairy", "greek"], no: ["cream"], range: 30...80)],
            extras: [X("fl", ["c:semolina", "c:oat_flour", "c:rice_flour", "c:flour"], 25...45, req: true), X("sw", RK.sweet, 5...15)],
            spices: ["c:vanilla", "c:salt"], oven: true,
            title: { f in
                if let sc = f["sc"] { return "Сырники в духовке " + Say.with(sc.words.ins) }
                if let fr = f["fr"] { return "Сырники в духовке " + Say.with(fr.words.ins) }
                return "Сырники в духовке"
            },
            steps: { f in
                guard let y = f["y"], let fl = f["fl"] else { return [] }
                var s = ["Разогрей духовку до 190 °C и застели противень пергаментом."]
                var mix = ["яйцами", fl.words.ins]
                mix += RK.I([f["pr"], f["sw"]])
                s.append("Разомни \(y.words.acc) вилкой и смешай \(Say.with(Say.list(mix))).")
                if fl.isKind("c:semolina") { s.append("Оставь массу на 10 минут, чтобы манка набухла.") }
                s.append("Сформируй мокрыми руками 6–8 сырников и выложи на противень.")
                s.append("Запекай 20 минут, перевернув в середине.")
                if let sc = f["sc"] { s.append("Подавай \(Say.with(sc.words.ins)).") }
                if let fr = f["fr"] { s.append(fr.role == .berries ? "Добавь \(fr.words.acc)." : "Нарежь \(fr.words.acc) и подай рядом.") }
                return s
            },
            tip: { _ in "Без масла сырники выходят легче — а корочка всё равно румяная." }))

        t.append(T("brownie_pro", [.snack, .evening], minutes: 30,
            slots: [PR(30...60, req: true, main: true),
                    S("e", [.eggs], no: ["quail"], range: 50...120),
                    S("b", [.yogurt, .cottage], req: false, no: ["dessert_ready"], range: 80...180),
                    S("fr", [.fruit], req: false, tags: ["banana"], range: 100...130),
                    S("o", [.oats], req: false, tags: ["oats"], range: 20...40),
                    S("n", [.nuts], req: false, no: ["spread", "seeds", "topping"], range: 10...25),
                    S("ch", [.sweet], req: false, tags: ["chocolate"], range: 10...25)],
            extras: [X("cc", ["c:cocoa"], 10...20, req: true), X("sw", RK.sweet, 10...25)],
            spices: ["c:baking_powder", "c:vanilla", "c:salt"], oven: true, portable: true,
            check: { f in f["b"] != nil || f["fr"] != nil },
            title: { f in "Протеиновый брауни" + (f["n"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                var s = ["Разогрей духовку до 180 °C."]
                if let fr = f["fr"] { s.append("Разомни \(fr.words.acc) вилкой в пюре.") }
                var mix = RK.A([f["b"], f["e"], f["pr"], f["cc"], f["o"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:baking_powder", "c:vanilla"])
                s.append("Смешай \(Say.list(mix)) до однородного густого теста.")
                if let n = f["n"] { s.append("Поруби \(n.words.acc) и вмешай в тесто.") }
                if let ch = f["ch"] { s.append("Поломай \(ch.words.acc) на кусочки и вмешай.") }
                s.append("Выложи тесто в небольшую форму слоем 2–3 см и выпекай 18–20 минут — внутри брауни должен остаться влажным.")
                s.append("Остуди и нарежь на квадраты.")
                return s
            },
            tip: { _ in "Холодный брауни из холодильника ещё вкуснее и плотнее." }))

        t.append(T("choco_mousse", [.snack, .evening], minutes: 5,
            slots: [S("y", [.yogurt, .cottage], no: ["dessert_ready"], range: 150...300, main: true),
                    PR(15...30),
                    S("fr", [.berries, .fruit], req: false, no: ["dried"], range: 40...120),
                    S("n", [.nuts], req: false, range: 5...15)],
            extras: [X("cc", ["c:cocoa"], 8...15, req: true), X("sw", RK.sweet, 5...15)],
            spices: ["c:vanilla"],
            title: { f in "Шоколадный протеиновый мусс" + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let y = f["y"] else { return [] }
                var mix = RK.A([f["y"], f["pr"], f["cc"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:vanilla"])
                var s = ["Пробей блендером \(Say.list(mix)) до гладкого крема."]
                if y.role == .cottage { s.append("Если масса слишком густая, добавь 2–3 ложки молока или воды.") }
                s.append("Разложи по стаканам и охлади 15 минут в холодильнике.")
                if let fr = f["fr"] { s.append(fr.role == .berries ? "Укрась \(fr.words.ins)." : "Нарежь \(fr.words.acc) и выложи сверху.") }
                if let n = f["n"] { s.append("Посыпь \(n.words.ins).") }
                return s
            }))

        t.append(T("protein_balls", [.snack], minutes: 15,
            slots: [PR(20...40, req: true, main: true),
                    S("n", [.nuts], tags: ["spread"], range: 20...40),
                    S("o", [.oats], tags: ["oats"], range: 20...50),
                    S("fr", [.fruit], req: false, tags: ["dried"], range: 20...40),
                    S("t", [.nuts], req: false, tags: ["topping", "seeds"], range: 5...10)],
            extras: [X("sw", ["c:honey", "c:maple_syrup", "c:sweetener"], 10...20)],
            portable: true,
            title: { f in "Протеиновые шарики" + (f["n"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                var s: [String] = []
                if let fr = f["fr"] { s.append("Мелко порежь \(fr.words.acc).") }
                s.append("Смешай \(Say.list(RK.A([f["pr"], f["n"], f["o"], f["fr"], f["sw"]]))) — масса должна легко лепиться. Если сухо, добавь ложку воды.")
                s.append("Скатай мокрыми руками 6–8 шариков.")
                if let tp = f["t"] { s.append("Посыпь шарики \(tp.words.ins).") }
                s.append("Убери в холодильник на 20 минут, чтобы схватились.")
                return s
            },
            tip: { _ in "Храни в контейнере в холодильнике до 5 дней — удобно брать с собой." }))

        t.append(T("rice_pudding", [.snack, .evening, .breakfast], minutes: 35,
            slots: [S("r", [.grain], tags: ["rice"], range: 40...70, main: true),
                    S("m", [.milk], no: ["rtd", "kefir"], range: 250...400),
                    PR(15...30),
                    S("fr", [.fruit, .berries], req: false)],
            extras: [X("sw", RK.sweet, 5...20)],
            spices: ["c:cinnamon", "c:vanilla", "c:salt"],
            title: { f in
                let base = f["pr"] != nil ? "Протеиновый рисовый пудинг" : "Рисовый пудинг"
                return base + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let r = f["r"], let m = f["m"] else { return [] }
                var s = ["Промой \(r.words.acc), залей \(m.words.ins) и доведи до кипения.",
                         "Вари на слабом огне 25–30 минут, часто помешивая, пока рис не станет мягким и кремовым."]
                if let pr = f["pr"] { s.append("Сними с огня, дай остыть 5 минут и вмешай \(pr.words.acc).") }
                if let x = RK.sweeten(f["sw"]) { s.append(x) }
                if RK.on(f, "c:cinnamon") { s.append("Посыпь корицей.") }
                if let x = RK.top(f["fr"]) { s.append(x) }
                return s
            },
            tip: { _ in "Холодный пудинг на следующий день — готовый десерт." }))

        t.append(T("chia_pudding", [.breakfast, .snack, .evening], minutes: 5,
            slots: [S("ch", [.nuts], tags: ["chia"], range: 20...35),
                    S("m", [.milk, .yogurt], no: ["dessert_ready"], range: 150...250, main: true),
                    PR(15...30),
                    S("fr", [.fruit, .berries], req: false, no: ["dried"])],
            extras: [X("sw", ["c:honey", "c:maple_syrup", "c:sweetener", "c:jam"], 5...15)],
            spices: ["c:vanilla"], portable: true,
            title: { f in
                var add: [String] = []
                if f["pr"] != nil { add.append("протеином") }
                if let fr = f["fr"] { add.append(fr.words.ins) }
                return "Чиа-пудинг" + (add.isEmpty ? "" : " " + Say.with(Say.list(add)))
            },
            steps: { f in
                var mix = RK.A([f["m"], f["pr"], f["ch"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:vanilla"])
                var s = ["Смешай в банке \(Say.list(mix)).",
                         "Через 5 минут перемешай ещё раз, чтобы семена не слиплись, и убери в холодильник минимум на 3 часа или на ночь."]
                if let x = RK.top(f["fr"]) { s.append(x) }
                return s
            },
            tip: { _ in "Собери с вечера — утром завтрак уже готов." }))

        t.append(T("panna_cotta_pro", [.snack, .evening], minutes: 15,
            slots: [S("y", [.yogurt, .milk, .cottage], no: ["dessert_ready"], range: 200...350, main: true),
                    PR(15...30),
                    S("fr", [.berries, .fruit], req: false, no: ["dried"], range: 40...120)],
            extras: [X("gl", ["c:gelatin"], 8...12, req: true), X("sw", RK.sweet, 5...15)],
            spices: ["c:vanilla"],
            title: { f in "Протеиновая панна-котта" + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let y = f["y"], let gl = f["gl"] else { return [] }
                var s = ["Замочи \(gl.words.acc) в 50 мл холодной воды на 10 минут.",
                         "Прогрей набухший желатин на слабом огне или 20 секунд в микроволновке, пока он не растворится, — не кипяти."]
                var mix = RK.A([f["y"], f["pr"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:vanilla"])
                if y.role == .cottage { s.append("Пробей блендером \(Say.list(mix)) до гладкости.") }
                else { s.append("Смешай \(Say.list(mix)) до гладкости.") }
                s.append("Влей тёплый желатин тонкой струйкой, всё время помешивая.")
                if let fr = f["fr"] {
                    s.append(fr.role == .berries ? "Разложи \(fr.words.acc) по формочкам или стаканам." : "Нарежь \(fr.words.acc) и разложи по формочкам или стаканам.")
                }
                s.append("Разлей массу и убери в холодильник на 2–3 часа, пока не застынет.")
                return s
            }))

        t.append(T("tiramisu_pro", [.snack, .evening], minutes: 20,
            slots: [S("y", [.cottage, .yogurt], no: ["dessert_ready"], range: 200...350, main: true),
                    S("y2", [.cheese], req: false, tags: ["dessert", "spread"], range: 30...80),
                    S("cb", [.snack], tags: ["biscuit"], range: 40...80),
                    PR(15...30)],
            extras: [X("cc", ["c:cocoa"], 3...6, req: true), X("sw", RK.sweet, 5...15)],
            spices: ["c:coffee", "c:vanilla"],
            title: { _ in "Протеиновый тирамису" },
            steps: { f in
                guard let cb = f["cb"], let cc = f["cc"] else { return [] }
                var mix = RK.A([f["y"], f["y2"], f["pr"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:vanilla"])
                return ["Завари 100 мл крепкого кофе и остуди.",
                        "Взбей блендером \(Say.list(mix)) в густой крем.",
                        "Быстро обмакивай \(cb.words.acc) в кофе и выкладывай слоями с кремом в контейнер или стаканы.",
                        "Посыпь верх \(cc.words.ins) через ситечко.",
                        "Убери в холодильник на 2 часа, чтобы печенье пропиталось."]
            },
            tip: { _ in "Чем дольше тирамису стоит в холодильнике, тем он нежнее." }))

        t.append(T("baked_apples", [.snack, .evening, .breakfast], minutes: 30,
            slots: [S("fr", [.fruit], tags: ["apple", "pear"], range: 180...360),
                    S("y", [.cottage], range: 80...180, main: true),
                    S("n", [.nuts], req: false, no: ["spread", "seeds", "topping"], range: 10...20),
                    S("dr", [.fruit], req: false, tags: ["dried"], range: 10...25)],
            extras: [X("sw", ["c:honey", "c:maple_syrup", "c:sweetener", "c:sugar"], 5...15)],
            spices: ["c:cinnamon", "c:vanilla"], oven: true,
            title: { f in f["fr"]?.has("pear") == true ? "Печёные груши с творогом" : "Печёные яблоки с творогом" },
            steps: { f in
                guard let y = f["y"] else { return [] }
                var s = ["Разогрей духовку до 180 °C.",
                         "Срежь у фруктов верхушки и вырежь сердцевину ложкой, оставив донышко."]
                let mix = RK.I([f["dr"], f["n"], f["sw"]])
                if mix.isEmpty { s.append("Разомни \(y.words.acc) вилкой.") }
                else { s.append("Смешай \(y.words.acc) \(Say.with(Say.list(mix))).") }
                s.append(RK.on(f, "c:cinnamon") ? "Наполни фрукты начинкой и посыпь корицей." : "Наполни фрукты начинкой.")
                s.append("Запекай 20–25 минут, пока фрукты не станут мягкими.")
                return s
            },
            tip: { _ in "Без духовки: 5–6 минут в микроволновке под крышкой." }))

        t.append(T("banana_ice_cream", [.snack, .evening], minutes: 5,
            slots: [S("fr", [.fruit], tags: ["banana"], range: 120...240),
                    PR(15...30, req: true, main: true),
                    S("m", [.milk, .yogurt], req: false, no: ["dessert_ready"], range: 30...80),
                    S("n", [.nuts], req: false, tags: ["spread"], range: 10...15),
                    S("b", [.berries], req: false, range: 40...100)],
            extras: [X("cc", ["c:cocoa"], 5...10)],
            title: { f in f["cc"] != nil ? "Шоколадное протеиновое мороженое из банана" : "Протеиновое мороженое из банана" },
            steps: { f in
                guard let fr = f["fr"] else { return [] }
                let add = RK.I([f["pr"], f["m"], f["n"], f["b"], f["cc"]])
                return ["Нарежь \(fr.words.acc) кружочками и заморозь минимум на 3 часа — удобно держать запас в морозилке.",
                        "Пробей замороженный банан в блендере \(Say.with(Say.list(add))) до консистенции мороженого.",
                        "Ешь сразу или убери в морозилку на 30 минут, чтобы стало плотнее."]
            }))

        t.append(T("oat_cookies_pro", [.snack], minutes: 25,
            slots: [S("o", [.oats], tags: ["oats"], range: 40...80),
                    PR(20...40, req: true, main: true),
                    S("fr", [.fruit], req: false, tags: ["banana"], range: 100...130),
                    S("e", [.eggs], req: false, no: ["quail"], range: 50...60),
                    S("n", [.nuts], req: false, no: ["spread", "topping"], range: 10...20),
                    S("dr", [.fruit, .sweet], req: false, tags: ["dried", "chocolate"], range: 10...25)],
            extras: [X("sw", RK.sweet, 5...15)],
            spices: ["c:baking_powder", "c:cinnamon"], oven: true, portable: true,
            check: { f in f["fr"] != nil || f["e"] != nil },
            title: { f in "Протеиновое овсяное печенье" + (f["dr"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                var s = ["Разогрей духовку до 180 °C."]
                if let fr = f["fr"] { s.append("Разомни \(fr.words.acc) вилкой.") }
                var mix = RK.A([f["fr"], f["e"], f["o"], f["pr"], f["sw"]])
                mix += RK.spiceAcc(f, ["c:baking_powder", "c:cinnamon"])
                s.append("Смешай \(Say.list(mix)).")
                let add = RK.A([f["n"], f["dr"]])
                if !add.isEmpty { s.append("Добавь \(Say.list(add)).") }
                s.append("Выложи ложкой 6–8 печенек на пергамент и прижми ладонью.")
                s.append("Выпекай 12–14 минут — печенье дойдёт, пока остывает.")
                return s
            },
            tip: { _ in "Храни в банке до 4 дней — хороший перекус в дорогу." }))

        t.append(T("muffins_pro", [.breakfast, .snack], minutes: 30,
            slots: [S("o", [.oats], tags: ["oats"], range: 40...80),
                    S("e", [.eggs], no: ["quail"], range: 50...150),
                    S("y", [.yogurt, .cottage], no: ["dessert_ready"], range: 100...200),
                    PR(20...40, main: true),
                    S("fr", [.berries, .fruit], req: false, tags: ["bake"], range: 50...120)],
            extras: [X("sw", RK.sweet, 10...20)],
            spices: ["c:baking_powder", "c:vanilla", "c:salt"], oven: true, portable: true,
            title: { f in
                let base = f["pr"] != nil ? "Протеиновые маффины" : "Овсяные маффины"
                return base + (f["fr"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let o = f["o"] else { return [] }
                var s = ["Разогрей духовку до 180 °C.", "Смели \(o.words.acc) в блендере в муку."]
                var mix = ["яйцами"] + RK.I([f["y"], f["pr"], f["sw"]])
                if RK.on(f, "c:baking_powder") { mix.append("разрыхлителем") }
                s.append("Смешай молотые хлопья \(Say.with(Say.list(mix))).")
                if let x = RK.into(f["fr"]) { s.append(x) }
                s.append("Разложи тесто по формочкам для маффинов на три четверти и выпекай 20–22 минуты.")
                s.append("Проверь шпажкой: она должна выходить сухой.")
                return s
            },
            tip: { _ in "Маффины хранятся в холодильнике 3–4 дня, их можно заморозить." }))

        t.append(T("semolina_mousse", [.snack, .evening, .breakfast], minutes: 20,
            slots: [S("sm", [.oats], tags: ["semolina"], range: 30...50),
                    S("b", [.berries], range: 100...200, main: true),
                    PR(15...25),
                    S("y", [.yogurt], req: false, tags: ["greek"], range: 50...120)],
            extras: [X("sw", RK.sweet, 10...25)],
            title: { f in "Манный мусс " + Say.with(f["b"].map { $0.words.ins } ?? "ягодами") },
            steps: { f in
                guard let sm = f["sm"], let b = f["b"] else { return [] }
                var s = ["Залей \(b.words.acc) 300 мл воды, доведи до кипения и пробей блендером или протри через сито.",
                         "Всыпь \(sm.words.acc) тонкой струйкой и вари 5 минут, помешивая."]
                if let sw = f["sw"] { s.append(sw.role == .spice ? "Подсласти \(sw.words.ins) по вкусу." : "Добавь \(sw.words.acc).") }
                s.append("Остуди до тёплого и взбей миксером 5–7 минут — масса посветлеет и станет пышной.")
                if let pr = f["pr"] { s.append("В конце взбивания добавь \(pr.words.acc).") }
                s.append("Разложи по стаканам и охлади.")
                if let y = f["y"] { s.append("Подавай \(Say.with(y.words.ins)).") }
                return s
            }))

        t.append(T("frozen_yogurt_bark", [.snack, .evening], minutes: 10,
            slots: [S("y", [.yogurt], tags: ["greek"], range: 150...300, main: true),
                    PR(15...30),
                    S("b", [.berries, .fruit], no: ["dried"], range: 50...150),
                    S("n", [.nuts], req: false, range: 10...20),
                    S("ch", [.sweet], req: false, tags: ["chocolate"], range: 10...20)],
            extras: [X("sw", ["c:honey", "c:sweetener", "c:maple_syrup"], 5...15)],
            title: { f in "Замороженный йогурт " + Say.with(f["b"].map { $0.words.ins } ?? "ягодами") },
            steps: { f in
                guard let b = f["b"] else { return [] }
                var s = ["Смешай \(Say.list(RK.A([f["y"], f["pr"], f["sw"]]))).",
                         "Распредели массу слоем 1 см на пергаменте."]
                if b.role != .berries { s.append("Нарежь \(b.words.acc) мелкими кусочками.") }
                s.append("Разложи сверху \(Say.list(RK.A([f["b"], f["n"], f["ch"]]))).")
                s.append("Заморозь на 2 часа и разломай на кусочки.")
                return s
            },
            tip: { _ in "Храни в морозилке в контейнере — достаёшь пару кусочков, когда хочется сладкого." }))

        return t
    }
}
