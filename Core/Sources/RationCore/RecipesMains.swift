import Foundation

// Обеды и ужины: супы, вторые блюда, салаты.

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

/// Гарнир: крупа, макароны или картошка (не фри и не перловка).
private func SIDE(req: Bool = true, range: ClosedRange<Double>? = nil) -> SlotSpec {
    S("s", [.grain, .pasta, .potato], req: req, noCooks: [.fries, .barley], range: range)
}

/// Кусковое мясо или птица без костей (не фарш, не готовое, не консервы).
private let wholeMeatNo: [String] = ["ground", "cooked", "canned", "bone"]
private let wholeMeatNoCooks: [Cook] = [.liver, .cannedMeat, .cookedMeat, .bacon, .sausage]

private let fat = Templates.fat
private let tomato = Templates.tomato
private let mayoLike: [(String, ClosedRange<Double>)] = [("c:mayo_light", 20...40), ("c:mayo", 15...30), ("c:sour_cream", 25...50), ("c:greek_yogurt_0", 30...60)]

/// Зажарка из лука и моркови для супа.
private func fryBase(_ veg: [Food], paste: Food?) -> String? {
    guard !veg.isEmpty || paste != nil else { return nil }
    if veg.isEmpty, let tp = paste { return "Разведи \(tp.words.acc) ложкой воды из кастрюли." }
    var s = "Обжарь \(Say.list(veg.map { $0.words.acc })) на масле 4–5 минут"
    if let tp = paste { s += ", добавь \(tp.words.acc) и жарь ещё минуту" }
    return s + "."
}

extension Templates {
    static func mains() -> [DishTemplate] {
        var t: [DishTemplate] = []

        // ───────────── Супы ─────────────

        t.append(T("borscht", [.main], minutes: 70,
            slots: [S("bt", [.vegetable], tags: ["beet"], range: 80...200),
                    S("cb", [.vegetable], req: false, tags: ["cabbage"], range: 80...200),
                    S("s", [.potato], cooks: [.potato], range: 100...250),
                    S("p", [.meat], req: false, no: ["ground", "cooked"], noCooks: [.liver, .bacon], main: true),
                    S("v", [.vegetable], req: false, tags: ["carrot"]),
                    S("v2", [.vegetable], req: false, tags: ["onion"]),
                    S("l", [.legumes], req: false, tags: ["beans"], cooks: [.cannedLegumes], range: 80...150),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("tp", ["c:tomato_paste"], 15...30), X("sc", RK.sour, 20...40), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:garlic", "c:vinegar"], portable: true,
            check: { f in f["p"] != nil || f["l"] != nil },
            title: { f in
                if let p = f["p"] { return "Борщ " + Say.with(p.words.ins) }
                return "Борщ с фасолью"
            },
            steps: { f in
                guard let bt = f["bt"], let s0 = f["s"] else { return [] }
                var s: [String] = []
                if let p = f["p"], Say.cook(p) == .cannedMeat {
                    s.append("Доведи до кипения 1,5 литра воды.")
                } else if let p = f["p"], let m = RK.brothMinutes(p) {
                    s.append("Залей \(p.words.acc) 1,5 литрами холодной воды, доведи до кипения, сними пену и вари \(m).")
                    s.append("Достань мясо, нарежь кусочками и верни в кастрюлю.")
                } else {
                    s.append("Доведи до кипения 1,5 литра воды.")
                }
                s.append("Почисть \(s0.words.acc), нарежь кубиками и опусти в кастрюлю.")
                if let cb = f["cb"] { s.append("Нашинкуй \(cb.words.acc) и добавь в кастрюлю.") }
                let grate = [bt] + f.all(["v"])
                s.append("Натри на крупной тёрке \(Say.list(grate.map { $0.words.acc }))\(f["v2"].map { ", мелко нарежь \($0.words.acc)" } ?? "").")
                var fry = "Обжарь овощи на масле 5 минут"
                if let tp = f["tp"] { fry += ", добавь \(tp.words.acc)" }
                fry += " и туши ещё 5 минут"
                if RK.on(f, "c:vinegar") { fry += " — ложка уксуса сохранит яркий цвет" }
                s.append(fry + ".")
                if let l = f["l"] { s.append("Откинь \(l.words.acc) на дуршлаг и добавь в кастрюлю.") }
                if let p = f["p"], Say.cook(p) == .cannedMeat { s.append("Добавь \(p.words.acc).") }
                let sp = Say.spices(f.spices.filter { !$0.isKind("c:garlic") })
                s.append("Переложи зажарку в кастрюлю, посоли\(sp.isEmpty ? "" : ", добавь \(sp)") и вари 10 минут.")
                if RK.on(f, "c:garlic") { s.append("Выдави зубчик чеснока, выключи огонь и дай борщу настояться 15 минут под крышкой.") }
                if let x = RK.serve([f["sc"], f["h"]]) { s.append(x) }
                return s
            },
            tip: { _ in "Борщ вкуснее на второй день — вари сразу кастрюлю на 2–3 дня." }))

        t.append(T("shchi", [.main], minutes: 60,
            slots: [S("cb", [.vegetable], tags: ["cabbage", "kraut"], range: 100...250),
                    S("s", [.potato], req: false, cooks: [.potato], range: 100...200),
                    S("p", [.meat, .sausage], no: ["ground", "cooked", "sliced"], noCooks: [.liver, .bacon, .noCook], main: true),
                    S("v", [.vegetable], req: false, tags: ["carrot"]),
                    S("v2", [.vegetable], req: false, tags: ["onion"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("tp", ["c:tomato_paste"], 10...25), X("sc", RK.sour, 20...40), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:dill_dry"], portable: true,
            title: { f in
                let base = f["cb"]?.has("kraut") == true ? "Кислые щи" : "Щи из свежей капусты"
                return base + (f["p"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let cb = f["cb"], let p = f["p"] else { return [] }
                var s: [String] = []
                if let m = RK.brothMinutes(p) {
                    s.append("Залей \(p.words.acc) 1,5 литрами холодной воды, доведи до кипения, сними пену и вари \(m).")
                    s.append("Достань мясо, нарежь кусочками и верни в кастрюлю.")
                } else {
                    s.append("Доведи до кипения 1,5 литра воды.")
                }
                if let pt = f["s"] { s.append("Почисть \(pt.words.acc), нарежь кубиками и опусти в кастрюлю.") }
                if cb.has("kraut") { s.append("Промой \(cb.words.acc), если она очень кислая, отожми и добавь в кастрюлю.") }
                else { s.append("Нашинкуй \(cb.words.acc) и добавь в кастрюлю.") }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                if let x = fryBase(veg, paste: f["tp"]) { s.append(x); s.append("Переложи зажарку в кастрюлю.") }
                if p.role == .sausage { s.append("Нарежь \(p.words.acc) и добавь в щи.") }
                if Say.cook(p) == .cannedMeat { s.append("Добавь \(p.words.acc) и прогрей 5 минут.") }
                let sp = Say.spices(f.spices)
                s.append("Посоли\(sp.isEmpty ? "" : ", добавь \(sp)") и вари ещё \(cb.has("kraut") ? "20" : "15") минут.")
                if let x = RK.serve([f["sc"], f["h"]]) { s.append(x) }
                return s
            },
            tip: { _ in "Щи хранятся в холодильнике до 3 дней." }))

        t.append(T("pea_soup", [.main], minutes: 90,
            slots: [S("l", [.legumes], tags: ["peas_dry"], range: 60...100, main: true),
                    S("p", [.sausage, .meat], req: false, no: ["ground", "cooked"], noCooks: [.liver, .noCook]),
                    S("s", [.potato], req: false, cooks: [.potato], range: 100...200),
                    S("v", [.vegetable], req: false, tags: ["carrot"]),
                    S("v2", [.vegetable], req: false, tags: ["onion"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:smoked_paprika"],
            title: { f in "Гороховый суп" + (f["p"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let l = f["l"] else { return [] }
                var s = ["Замочи \(l.words.acc) на ночь или хотя бы на 2 часа, потом промой."]
                var boil: Food? = nil
                if let p = f["p"], RK.brothMinutes(p) != nil { boil = p }
                if let p = boil {
                    s.append("Залей горох и \(p.words.acc) 1,5 литрами воды и вари 40–50 минут, снимая пену, пока горох не начнёт развариваться.")
                    s.append("Достань мясо, нарежь и верни в кастрюлю.")
                } else {
                    s.append("Залей горох 1,5 литрами воды и вари 40–50 минут, снимая пену, пока он не начнёт развариваться.")
                }
                if let pt = f["s"] { s.append("Почисть \(pt.words.acc), нарежь кубиками и добавь в суп.") }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                var fryItems = veg.map { $0.words.acc }
                if boil == nil { fryItems += RK.A([f["p"]]) }
                if !fryItems.isEmpty { s.append("Обжарь \(Say.list(fryItems)) на масле 4–5 минут и переложи в суп.") }
                let sp = Say.spices(f.spices)
                s.append("Посоли\(sp.isEmpty ? "" : ", добавь \(sp)") и вари ещё 15 минут.")
                if let h = f["h"] { s.append("Посыпь \(h.words.ins) перед подачей.") }
                return s
            },
            tip: { _ in "Если горох не замачивал, вари его на 30 минут дольше." }))

        t.append(T("solyanka", [.main], minutes: 40,
            slots: [S("p", [.sausage], range: 60...150, main: true),
                    S("p2", [.sausage, .meat], req: false, cooks: [.noCook, .sausage, .cookedMeat], range: 40...100),
                    S("pk", [.vegetable], tags: ["pickled"], range: 60...120),
                    S("ol", [.vegetable], req: false, tags: ["fatty"], no: ["avocado"], range: 20...40),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("s", [.potato], req: false, cooks: [.potato], range: 80...150)],
            extras: [X("tp", ["c:tomato_paste"], 15...30, req: true), X("sc", RK.sour, 20...40), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:lemon_juice"],
            title: { _ in "Солянка сборная" },
            steps: { f in
                guard let p = f["p"], let pk = f["pk"], let tp = f["tp"] else { return [] }
                var s = ["Доведи до кипения 1,2 литра воды."]
                if let pt = f["s"] { s.append("Почисть \(pt.words.acc), нарежь кубиками и вари 10 минут.") }
                s.append("Нарежь соломкой \(Say.list(RK.A([p, f["p2"]]))), а \(pk.words.acc) — тонкими полосками.")
                if let v = f["v"] { s.append("Нарежь \(v.words.acc) и обжарь на масле 3 минуты.") }
                s.append("Добавь в сковороду колбасу, \(tp.words.acc) и жарь ещё 3 минуты.")
                s.append("Переложи всё в кастрюлю вместе \(Say.with(Say.list(RK.I([pk, f["ol"]])))) и вари 10 минут.")
                let sp = Say.spiceList(f.spices)
                if !sp.isEmpty { s.append("Добавь \(Say.list(sp)) и посоли по вкусу.") }
                var serve = "Подавай"
                if RK.on(f, "c:lemon_juice") { serve += ", сбрызнув лимонным соком" }
                if let sc = f["sc"] { serve += ", \(Say.with(sc.words.ins))" }
                if serve != "Подавай" { s.append(serve + ".") }
                return s
            }))

        t.append(T("okroshka", [.main], minutes: 30,
            slots: [S("m", [.milk], tags: ["kefir"], range: 300...500),
                    S("s", [.potato], cooks: [.potato], range: 100...200),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...150),
                    S("p", [.sausage, .meat], req: false, cooks: [.noCook, .cookedMeat], main: true),
                    S("v", [.vegetable], tags: ["cucumber"], range: 100...200),
                    S("v2", [.vegetable], req: false, tags: ["salad", "raw"], no: ["fatty", "pickled", "tomato", "cucumber"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 10...25)],
            extras: [X("sc", RK.sour, 20...40)],
            spices: ["c:salt", "c:pepper", "c:lemon_juice"], portable: true, weight: 0.7,
            title: { _ in "Окрошка на кефире" },
            steps: { f in
                guard let m = f["m"], let pt = f["s"] else { return [] }
                var s = ["Отвари \(pt.words.acc) в мундире 20 минут и остуди.", RK.boiled(false)]
                if let p = f["p"], let pr = Say.prep(p) { s.append(pr) }
                let cut = RK.A([pt, f["e"], f["p"], f["v"], f["v2"]])
                s.append("Нарежь мелкими кубиками \(Say.list(cut)).")
                if let h = f["h"] { s.append("Мелко порежь \(h.words.acc).") }
                s.append("Залей всё холодным \(m.words.ins)\(f["sc"].map { ", добавь \($0.words.acc)" } ?? ""), посоли и поперчи.")
                s.append("Охлади 15 минут перед подачей.")
                return s
            }))

        t.append(T("cream_soup", [.main], minutes: 35,
            slots: [S("v", [.vegetable], tags: ["cream"], range: 200...400, main: true),
                    S("s", [.potato], req: false, cooks: [.potato], range: 80...150),
                    S("v2", [.vegetable], req: false, tags: ["onion", "carrot"]),
                    S("p", [.meat, .fish, .legumes], req: false, no: ["ground", "canned", "salted"], noCooks: [.liver, .groundMeat, .cannedFish, .cannedMeat, .dryBeans, .noCook, .bacon]),
                    S("c", [.cheese], req: false, tags: ["melt"], no: ["stick", "slice"], range: 20...40),
                    S("b", [.bread], req: false, tags: ["slice"], range: 20...50),
                    S("ss", [.nuts], req: false, tags: ["seeds"], range: 5...10)],
            extras: [XA("cr", [("c:cream_10", 50...100), ("c:milk_2", 100...200), ("c:sour_cream_10", 30...60)]), X("fat", fat, 5...8)],
            spices: ["c:salt", "c:pepper", "c:nutmeg", "c:garlic"],
            title: { f in
                guard let v = f["v"] else { return "Крем-суп" }
                var base = "Овощной крем-суп"
                if v.has("pumpkin") { base = "Тыквенный крем-суп" }
                else if v.has("zucchini") { base = "Кабачковый крем-суп" }
                else if v.isKind("c:broccoli") || v.isKind("c:broccoli_frozen") { base = "Крем-суп из брокколи" }
                else if v.isKind("c:cauliflower") || v.isKind("c:cauliflower_frozen") { base = "Крем-суп из цветной капусты" }
                return base + (f["p"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let v = f["v"] else { return [] }
                var s: [String] = []
                let veg = [v] + f.all(["v2"])
                s += Say.vegPrep(veg)
                if let pt = f["s"] { s.append("Почисть \(pt.words.acc) и нарежь кубиками.") }
                if let v2 = f["v2"] { s.append("Обжарь \(v2.words.acc) в кастрюле на масле 3 минуты.") }
                let pot = RK.A([v, f["s"]])
                s.append("Добавь \(Say.list(pot)), залей горячей водой так, чтобы она едва покрывала овощи, и вари 15–20 минут до мягкости.")
                if let cr = f["cr"] { s.append("Пробей суп блендером до гладкости, влей \(cr.words.acc) и прогрей, не доводя до кипения.") }
                else { s.append("Пробей суп блендером до гладкости.") }
                s.append(RK.on(f, "c:nutmeg") ? "Посоли, поперчи и добавь щепотку мускатного ореха." : "Посоли и поперчи.")
                if let p = f["p"] {
                    s += RK.protein(p)
                    s.append("Выложи \(p.words.acc) в тарелки с супом.")
                }
                if let b = f["b"] { s.append("Нарежь \(b.words.acc) кубиками и подсуши на сухой сковороде — получатся сухарики.") }
                if let c = f["c"] { s.append("Посыпь \(c.words.ins) прямо в тарелке.") }
                if let ss = f["ss"] { s.append("Посыпь \(ss.words.ins).") }
                return s
            }))

        // ───────────── Мясо и птица ─────────────

        t.append(T("goulash", [.main], minutes: 60,
            slots: [S("p", [.meat], no: wholeMeatNo, noCooks: wholeMeatNoCooks, main: true),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("v2", [.vegetable], req: false, tags: ["pepper", "carrot"], no: ["hot"]),
                    SIDE()],
            extras: [XA("tp", [("c:tomato_paste", 15...30), ("c:marinara", 60...120)]), X("fl", ["c:flour", "c:starch"], 5...10), X("fat", fat, 6...12)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:smoked_paprika", "c:bay_leaf"], portable: true, weight: 1.2,
            title: { f in
                guard let p = f["p"], let sd = f["s"] else { return "Гуляш" }
                return "Гуляш " + Say.with(p.words.ins) + " и " + sd.words.ins
            },
            steps: { f in
                guard let p = f["p"], let sd = f["s"] else { return [] }
                var s = [Say.side(sd), "Нарежь \(p.words.acc) кубиками 2–3 см, посоли и поперчи."]
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append("Разогрей масло в кастрюле и обжарь мясо на сильном огне 5–7 минут.")
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь ещё 5 минут.") }
                if let fl = f["fl"] { s.append("Посыпь \(fl.words.ins) и перемешай.") }
                var add = RK.A([f["tp"]])
                add += Say.spiceList(f.spices)
                add.append("300 мл горячей воды")
                s.append("Добавь \(Say.list(add)).")
                let long = Say.cook(p) == .beef || Say.cook(p) == .pork
                s.append("Туши под крышкой на слабом огне \(long ? "45–50 минут" : "20–25 минут"), пока мясо не станет мягким.")
                s.append("Подавай \(Say.with(sd.words.ins)).")
                return s
            },
            tip: { _ in "Гуляш хорошо стоит в холодильнике 3 дня — свари на несколько обедов." }))

        t.append(T("stroganoff", [.main], minutes: 35,
            slots: [S("p", [.meat], no: ["ground", "cooked", "canned", "bone"], noCooks: [.cannedMeat, .cookedMeat, .bacon, .sausage], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("m", [.vegetable], req: false, tags: ["mushroom"]),
                    SIDE()],
            extras: [XA("sc", [("c:sour_cream", 40...80), ("c:sour_cream_10", 50...100), ("c:cream_10", 60...120), ("c:greek_yogurt_0", 60...120)], req: true),
                     X("fl", ["c:flour"], 5...10), X("fat", fat, 6...12)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:nutmeg"], portable: true,
            title: { f in
                guard let p = f["p"], let sd = f["s"] else { return "Бефстроганов" }
                let head: String
                if Say.cook(p) == .liver { head = "Печень по-строгановски" }
                else if Say.cook(p) == .beef { head = "Бефстроганов" }
                else { head = p.words.title + " по-строгановски" }
                return head + " " + Say.with(sd.words.ins)
            },
            steps: { f in
                guard let p = f["p"], let sd = f["s"], let sc = f["sc"] else { return [] }
                var s = [Say.side(sd)]
                if let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "m"])
                s += Say.vegPrep(veg)
                s.append("Разогрей масло в сковороде.")
                s.append(Say.pan(p))
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь 5 минут.") }
                if let fl = f["fl"] { s.append("Посыпь \(fl.words.ins) и перемешай.") }
                if sc.role == .yogurt {
                    s.append("Влей 50 мл воды, прогрей минуту, сними сковороду с огня и вмешай \(sc.words.acc) — на огне йогурт свернётся.")
                } else {
                    s.append("Добавь \(sc.words.acc) и 50 мл воды и туши на слабом огне 5 минут.")
                }
                s.append(RK.on(f, "c:paprika") ? "Посоли, поперчи и добавь паприку." : "Посоли и поперчи.")
                s.append("Подавай \(Say.with(sd.words.ins)).")
                return s
            }))

        t.append(T("meatballs_tomato", [.main], minutes: 50,
            slots: [S("p", [.meat], tags: ["ground"], range: 150...300, main: true),
                    S("r", [.grain], tags: ["rice"], range: 20...40),
                    S("e", [.eggs], req: false, no: ["whites", "quail"], range: 50...50),
                    S("v", [.vegetable], req: false, tags: ["onion"], range: 40...80),
                    S("v2", [.vegetable], req: false, tags: ["carrot"]),
                    S("s", [.pasta, .potato, .grain], req: false, noCooks: [.fries, .barley], range: 50...120)],
            extras: [XA("t", tomato, req: true), X("sc", ["c:sour_cream", "c:sour_cream_10"], 20...40), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:garlic_dry"], portable: true,
            title: { f in "Тефтели в томатном соусе" + (f["s"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let p = f["p"], let r = f["r"], let tm = f["t"] else { return [] }
                var s = ["Отвари \(r.words.acc) 8 минут до полуготовности и остуди."]
                if let sd = f["s"] { s.append(Say.side(sd)) }
                if let v = f["v"] { s.append("Мелко нарежь \(v.words.acc).") }
                var mix = [r.words.ins]
                if f["e"] != nil { mix.append("яйцом") }
                mix += RK.I([f["v"]])
                mix += ["солью", "перцем"]
                s.append("Смешай \(p.words.acc) \(Say.with(Say.list(mix))) и сформируй 10–12 шариков.")
                s.append("Обжарь тефтели на масле по 2 минуты с каждой стороны.")
                if let v2 = f["v2"] { s.append("Натри \(v2.words.acc) и добавь в сковороду.") }
                var pour = RK.tomatoPour(tm, water: 300)
                if let sc = f["sc"] { pour += ", добавь \(sc.words.acc)" }
                s.append(pour + " и залей тефтели.")
                s.append("Брось лавровый лист и туши под крышкой 20–25 минут.")
                if let sd = f["s"] { s.append("Подавай \(Say.with(sd.words.ins)).") }
                return s
            }))

        t.append(T("lazy_golubtsy", [.main], minutes: 55,
            slots: [S("p", [.meat], tags: ["ground"], main: true),
                    S("cb", [.vegetable], tags: ["cabbage"], range: 100...250),
                    S("r", [.grain], tags: ["rice"], range: 30...60),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("v2", [.vegetable], req: false, tags: ["carrot"]),
                    S("e", [.eggs], req: false, no: ["whites", "quail"], range: 50...50)],
            extras: [XA("t", tomato, req: true), X("sc", ["c:sour_cream", "c:sour_cream_10"], 20...40), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf"], portable: true, onePan: true,
            title: { _ in "Ленивые голубцы" },
            steps: { f in
                guard let p = f["p"], let cb = f["cb"], let r = f["r"], let tm = f["t"] else { return [] }
                var s = ["Отвари \(r.words.acc) 10 минут до полуготовности."]
                s.append("Мелко нашинкуй \(Say.list(RK.A([cb, f["v"]]))).")
                var mix = RK.I([cb, r, f["v"]])
                if f["e"] != nil { mix.append("яйцом") }
                mix += ["солью", "перцем"]
                s.append("Смешай \(p.words.acc) \(Say.with(Say.list(mix))).")
                s.append("Сформируй мокрыми руками овальные котлетки и обжарь на масле по 2–3 минуты с каждой стороны.")
                if let v2 = f["v2"] { s.append("Натри \(v2.words.acc) и обжарь рядом.") }
                s.append(RK.tomatoPour(tm, water: 400) + " и залей голубцы.")
                s.append("Туши под крышкой на слабом огне 25–30 минут.")
                if let sc = f["sc"] { s.append("Подавай \(Say.with(sc.words.ins)).") }
                return s
            }))

        t.append(T("stuffed_peppers", [.main], minutes: 60,
            slots: [S("v", [.vegetable], tags: ["stuff"], range: 300...500),
                    S("p", [.meat], tags: ["ground"], main: true),
                    S("r", [.grain], tags: ["rice", "bulgur"], range: 30...60),
                    S("v2", [.vegetable], req: false, tags: ["onion", "carrot"])],
            extras: [XA("t", tomato, req: true), X("sc", ["c:sour_cream", "c:sour_cream_10"], 20...40)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:bay_leaf"], portable: true, onePan: true,
            title: { _ in "Фаршированные перцы" },
            steps: { f in
                guard let v = f["v"], let p = f["p"], let r = f["r"], let tm = f["t"] else { return [] }
                var s = ["Отвари \(r.words.acc) 10 минут до полуготовности.",
                         "Срежь у перцев верхушки и удали семена."]
                if let v2 = f["v2"] { s.append("Мелко нарежь \(v2.words.acc).") }
                let mix = RK.I([r, f["v2"]]) + ["солью", "перцем"]
                s.append("Смешай \(p.words.acc) \(Say.with(Say.list(mix))).")
                s.append("Начини \(v.words.acc) фаршем и поставь вертикально в кастрюлю.")
                s.append(RK.tomatoPour(tm, water: 400) + " и залей перцы почти доверху.")
                s.append("Туши под крышкой на слабом огне 40 минут.")
                if let sc = f["sc"] { s.append("Подавай \(Say.with(sc.words.ins)).") }
                return s
            }))

        t.append(T("potato_stew", [.main], minutes: 50,
            slots: [S("s", [.potato], cooks: [.potato], range: 200...400),
                    S("p", [.meat, .sausage], no: ["ground", "cooked"], noCooks: [.liver, .bacon, .cookedMeat, .noCook], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("v2", [.vegetable], req: false, tags: ["carrot", "pepper", "mushroom"], no: ["hot"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("tp", ["c:tomato_paste"], 10...20), X("fat", fat, 6...12, when: RK.heats)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:paprika"], portable: true, onePan: true,
            title: { f in "Тушёная картошка " + Say.with(f["p"].map { $0.words.ins } ?? "мясом") },
            steps: { f in
                guard let pt = f["s"], let p = f["p"] else { return [] }
                var s: [String] = []
                let canned = Say.cook(p) == .cannedMeat
                if !canned, let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append("Почисть \(pt.words.acc) и нарежь крупными кубиками.")
                if canned {
                    var x = "Разогрей \(p.words.acc) в кастрюле — жир из банки заменит масло"
                    if !veg.isEmpty { x += ", и обжарь в нём \(Say.list(veg.map { $0.words.acc })) 3–4 минуты" }
                    s.append(x + ".")
                } else {
                    s.append("Разогрей масло в кастрюле.")
                    s.append(Say.pan(p))
                    if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь ещё 3–4 минуты.") }
                }
                var add = ["картофель"] + RK.A([f["tp"]])
                add += Say.spiceList(f.spices)
                s.append("Добавь \(Say.list(add)) и залей горячей водой почти вровень.")
                s.append("Посоли и туши под крышкой 25–30 минут, пока картошка не станет мягкой.")
                if let h = f["h"] { s.append("Посыпь \(h.words.ins) перед подачей.") }
                return s
            },
            tip: { _ in "Тушёнка — самый быстрый вариант: мясо уже готово, нужно только прогреть." }))

        t.append(T("chops", [.main], minutes: 30,
            slots: [S("p", [.meat], tags: ["lean", "chop"], no: wholeMeatNo, noCooks: wholeMeatNoCooks, main: true),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...60),
                    S("c", [.cheese], req: false, tags: ["melt", "grate"], no: ["stick", "slice"], range: 10...25),
                    SIDE(),
                    S("v", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf"], no: ["herb", "pickled", "fatty"])],
            extras: [X("fl", ["c:flour", "c:bread_crumbs"], 10...20), X("fat", fat, 8...14)],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:garlic_dry"], portable: true,
            title: { f in
                guard let sd = f["s"] else { return "Отбивные в кляре" }
                return (f["c"] != nil ? "Отбивные в сырном кляре " : "Отбивные в кляре ") + Say.with(sd.words.ins)
            },
            steps: { f in
                guard let p = f["p"], let sd = f["s"] else { return [] }
                var s = [Say.side(sd),
                         "Нарежь \(p.words.acc) пластами толщиной 1 см и отбей через плёнку, посоли и поперчи."]
                if let c = f["c"] { s.append("Натри \(c.words.acc) и взбей с яйцами.") }
                else { s.append("Взбей яйца с щепоткой соли.") }
                if let fl = f["fl"] { s.append("Обсыпь отбивные \(fl.words.ins), затем обмакни в яичную смесь.") }
                else { s.append("Обмакни отбивные в яичную смесь.") }
                s.append("Жарь на разогретом масле по 3–4 минуты с каждой стороны до румяной корочки.")
                if let v = f["v"] { s += Say.vegPrep([v]) }
                s.append("Подавай \(Say.with(Say.list(RK.I([sd, f["v"]])))).")
                return s
            }))

        t.append(T("french_meat", [.main], minutes: 50,
            slots: [S("p", [.meat], no: wholeMeatNo, noCooks: wholeMeatNoCooks, main: true),
                    S("s", [.potato], req: false, cooks: [.potato], range: 150...300),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("t", [.vegetable], req: false, tags: ["tomato"]),
                    S("m", [.vegetable], req: false, tags: ["mushroom"]),
                    S("c", [.cheese], tags: ["melt"], no: ["stick", "slice"], range: 20...50)],
            extras: [XA("sc", [("c:sour_cream_10", 25...50), ("c:sour_cream", 20...40), ("c:mayo_light", 15...30), ("c:mayo", 15...25)])],
            spices: ["c:salt", "c:pepper", "c:garlic_dry"], oven: true, portable: true, onePan: true,
            title: { f in
                guard let p = f["p"] else { return "Мясо по-французски" }
                let red = Say.cook(p) == .beef || Say.cook(p) == .pork
                let head = red ? "Мясо по-французски" : p.words.title + " по-французски"
                return head + (f["s"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let p = f["p"], let c = f["c"] else { return [] }
                var s = ["Разогрей духовку до 190 °C."]
                if let pt = f["s"] { s.append("Почисть \(pt.words.acc), нарежь тонкими кружочками, выложи в форму и посоли.") }
                s.append("Нарежь \(p.words.acc) пластами толщиной 1 см, слегка отбей, посоли и поперчи.")
                s.append(f["s"] != nil ? "Выложи мясо поверх картошки." : "Выложи мясо в форму.")
                let veg = RK.A([f["v"], f["m"], f["t"]])
                if !veg.isEmpty { s.append("Тонко нарежь и разложи сверху \(Say.list(veg)).") }
                if let sc = f["sc"] { s.append("Смажь \(sc.words.ins).") }
                s.append("Натри \(c.words.acc) и посыпь сверху.")
                s.append("Запекай \(f["s"] != nil ? "40–45 минут" : "30–35 минут") до румяной сырной корочки.")
                return s
            }))

        t.append(T("chakhokhbili", [.main], minutes: 50,
            slots: [S("p", [.meat], tags: ["chicken", "turkey"], no: ["ground", "cooked", "canned"], noCooks: [.liver, .cookedMeat, .cannedMeat], main: true),
                    S("v", [.vegetable], tags: ["onion"]),
                    S("t", [.vegetable], req: false, tags: ["tomato"]),
                    S("v2", [.vegetable], req: false, tags: ["pepper"], no: ["hot"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15),
                    S("s", [.grain, .potato, .bread], req: false, noCooks: [.fries, .barley])],
            extras: [XA("tp", [("c:tomato_paste", 15...30), ("c:marinara", 80...150)]), X("fat", fat, 6...10)],
            spices: ["c:salt", "c:pepper", "c:khmeli_suneli", "c:coriander", "c:garlic", "c:paprika"], portable: true, onePan: true,
            check: { f in f["t"] != nil || f["tp"] != nil },
            title: { f in "Чахохбили" + (f["s"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let p = f["p"], let v = f["v"] else { return [] }
                var s: [String] = []
                if let sd = f["s"], sd.role != .bread { s.append(Say.side(sd)) }
                if let pr = Say.prep(p) { s.append(pr) }
                s += Say.vegPrep([v] + f.all(["t", "v2"]))
                s.append("Обжарь \(p.words.acc) в кастрюле на масле до румяной корочки, 8–10 минут.")
                s.append("Добавь \(v.words.acc) и жарь ещё 5 минут.")
                var add = RK.A([f["t"], f["v2"], f["tp"]])
                add += Say.spiceList(f.spices.filter { !$0.isKind("c:garlic") })
                add.append("100 мл воды")
                s.append("Добавь \(Say.list(add)).")
                s.append("Туши под крышкой \(p.has("bone") ? "35–40 минут" : "20–25 минут").")
                var end: [String] = []
                if RK.on(f, "c:garlic") { end.append("выдавленный чеснок") }
                if let h = f["h"] { end.append(h.words.acc) }
                if !end.isEmpty { s.append("В конце добавь \(Say.list(end)).") }
                if let sd = f["s"] { s.append("Подавай \(Say.with(sd.words.ins)).") }
                return s
            }))

        t.append(T("burger", [.main], minutes: 20,
            slots: [S("b", [.bread], tags: ["bun"], range: 50...110),
                    S("p", [.meat], tags: ["ground"], range: 120...200, main: true),
                    S("c", [.cheese], req: false, tags: ["melt", "slice"], no: ["grate", "stick"], range: 15...30),
                    S("v", [.vegetable, .greens], req: false, tags: ["tomato", "leaf", "onion"], no: ["herb"]),
                    S("pk", [.vegetable], req: false, tags: ["pickled"])],
            extras: [XA("sc", [("c:ketchup", 15...25), ("c:mustard", 5...10), ("c:bbq_sauce", 15...25), ("c:mayo_light", 10...20)]), X("fat", fat, 3...6)],
            spices: ["c:salt", "c:pepper", "c:garlic_dry", "c:smoked_paprika"],
            title: { f in
                guard let p = f["p"] else { return "Бургер" }
                var head = "Бургер с говяжьей котлетой"
                if p.has("turkey") { head = "Бургер с котлетой из индейки" }
                else if p.has("chicken") { head = "Бургер с куриной котлетой" }
                else if p.has("pork") && !p.has("beef") { head = "Бургер со свиной котлетой" }
                return head + (f["c"] != nil ? " и сыром" : "")
            },
            steps: { f in
                guard let b = f["b"], let p = f["p"] else { return [] }
                let poultry = p.has("turkey") || p.has("chicken")
                var s = ["Посоли и поперчи \(p.words.acc) и сформируй плоские котлеты толщиной 1,5 см, чуть шире булочки.",
                         "Жарь на сильном огне на капле масла по 3–4 минуты с каждой стороны\(poultry ? " до полной готовности" : "")."]
                if let c = f["c"] { s.append("За минуту до конца положи на котлету \(c.words.acc) и накрой крышкой.") }
                s.append("Подрумянь \(b.words.acc) срезом вниз на сухой сковороде.")
                s += Say.vegPrep(f.all(["v", "pk"]))
                var layers = ["котлета"] + RK.A([f["v"], f["pk"]])
                if let sc = f["sc"] { layers.insert(sc.words.acc, at: 0) }
                s.append("Собери бургер: \(Say.list(layers)).")
                return s
            }))

        t.append(T("tacos", [.main], minutes: 25,
            slots: [S("b", [.bread], tags: ["wrap"], range: 50...120),
                    S("p", [.meat, .fish, .legumes], noCooks: [.liver, .lentils, .dryBeans, .bacon, .cannedMeat, .noCook], main: true),
                    S("v", [.vegetable, .greens], req: false, tags: ["tomato", "leaf", "corn", "onion", "pepper"], no: ["herb", "hot"]),
                    S("av", [.vegetable], req: false, tags: ["avocado"], range: 40...80),
                    S("c", [.cheese], req: false, tags: ["melt", "salad"], no: ["slice", "stick", "grate"], range: 15...30),
                    S("h", [.greens], req: false, tags: ["herb"], range: 3...10)],
            extras: [XA("sc", [("c:salsa", 30...60), ("c:sour_cream", 20...40), ("c:greek_yogurt_0", 30...60)]), X("fat", fat, 4...8, when: RK.heats)],
            spices: ["c:salt", "c:cumin", "c:paprika", "c:chili", "c:garlic_dry", "c:lemon_juice"], portable: true,
            title: { f in "Тако " + Say.with(f["p"].map { $0.words.ins } ?? "мясом") },
            steps: { f in
                guard let b = f["b"], let p = f["p"] else { return [] }
                var s = RK.protein(p)
                let sp = Say.spiceList(f.spices)
                if Say.cook(p) == .groundMeat, !sp.isEmpty { s.append("Добавь \(Say.list(sp)) и 2 ложки воды и потуши 2 минуты.") }
                s += Say.vegPrep(f.all(["v", "av", "h"]))
                s.append("Разогрей \(b.words.acc) на сухой сковороде по 20 секунд с каждой стороны.")
                let fill = RK.A([p, f["v"], f["av"], f["c"], f["h"]])
                s.append("Разложи начинку: \(Say.list(fill))\(f["sc"].map { ", сверху — \($0.words.acc)" } ?? "").")
                if RK.on(f, "c:lemon_juice") { s.append("Сбрызни лимонным соком, сложи пополам и ешь сразу.") }
                else { s.append("Сложи пополам и ешь сразу.") }
                return s
            }))

        t.append(T("nuggets_home", [.main], minutes: 30,
            slots: [S("p", [.meat], tags: ["chicken", "turkey"], no: wholeMeatNo, noCooks: wholeMeatNoCooks, main: true),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...60),
                    S("cr", [.oats], req: false, tags: ["cereal", "oats"], range: 30...60),
                    S("s", [.potato, .grain], req: false, noCooks: [.barley]),
                    S("v", [.vegetable, .greens], req: false, tags: ["salad", "raw", "leaf"], no: ["herb", "pickled", "fatty"])],
            extras: [X("cb", ["c:bread_crumbs", "c:flour"], 30...50, when: { f in f["cr"] == nil }),
                     XA("sc", [("c:ketchup", 15...30), ("c:bbq_sauce", 15...30), ("c:sweet_chili", 15...30), ("c:ranch", 15...25)])],
            spices: ["c:salt", "c:pepper", "c:paprika", "c:garlic_dry"], oven: true, portable: true,
            check: { f in f["cr"] != nil || f["cb"] != nil },
            title: { f in "Домашние наггетсы" + (f["s"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let p = f["p"] else { return [] }
                var s = ["Разогрей духовку до 200 °C."]
                if let sd = f["s"] { s.append(Say.side(sd)) }
                let sp = Say.spiceList(f.spices)
                s.append("Нарежь \(p.words.acc) кусочками 3–4 см, посоли\(sp.isEmpty ? "" : " и добавь \(Say.list(sp))").")
                s.append("Взбей яйца в миске.")
                let coat: String
                if let cr = f["cr"] {
                    s.append("Измельчи \(cr.words.acc) в крошку — например, в пакете скалкой.")
                    coat = "этой крошкой"
                } else {
                    coat = f["cb"]?.words.ins ?? "мукой"
                }
                s.append("Обмакни кусочки в яйцо и обсыпь со всех сторон \(coat).")
                s.append("Выложи на пергамент и запекай 15–18 минут до золотистой корочки.")
                if let v = f["v"] { s += Say.vegPrep([v]) }
                if let x = RK.serve([f["sc"], f["v"]]) { s.append(x) }
                return s
            }))

        // ───────────── Макароны и крупы ─────────────

        t.append(T("carbonara", [.main], minutes: 20,
            slots: [S("s", [.pasta], no: ["noodles"], range: 70...120),
                    S("p", [.sausage], tags: ["bacon", "deli"], no: ["salted"], range: 40...100, main: true),
                    S("e", [.eggs], no: ["quail"], range: 50...120),
                    S("c", [.cheese], tags: ["grate", "melt"], no: ["slice", "stick", "spread"], range: 20...40)],
            extras: [X("fat", ["c:olive_oil", "c:sunflower_oil"], 3...6, when: { f in !(f["p"]?.has("bacon") ?? false) })],
            spices: ["c:pepper", "c:salt", "c:garlic"],
            title: { f in "Паста карбонара " + Say.with(f["p"].map { $0.words.ins } ?? "беконом") },
            steps: { f in
                guard let sd = f["s"], let p = f["p"], let c = f["c"] else { return [] }
                var s = [Say.side(sd), "Сохрани полстакана воды из-под макарон.",
                         "Натри \(c.words.acc) и смешай с яйцами и щедрой щепоткой чёрного перца."]
                if p.has("bacon") { s.append("Нарежь \(p.words.acc) полосками и обжарь до хруста на сухой сковороде 4–5 минут.") }
                else { s.append("Нарежь \(p.words.acc) полосками и обжарь на масле 2–3 минуты.") }
                s.append("Переложи горячие макароны в сковороду, сними её с огня и сразу влей яичную смесь.")
                s.append("Быстро перемешай, подливая воду из-под макарон, — соус должен стать кремовым, а не превратиться в омлет.")
                return s
            }))

        t.append(T("navy_pasta", [.main], minutes: 25,
            slots: [S("s", [.pasta], no: ["noodles"], range: 70...130),
                    S("p", [.meat], tags: ["ground", "canned"], noCooks: [.cannedFish], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("v2", [.vegetable], req: false, tags: ["carrot"])],
            extras: [X("tp", ["c:tomato_paste", "c:ketchup"], 10...25), X("fat", fat, 5...10, when: RK.heats)],
            spices: ["c:salt", "c:pepper", "c:garlic_dry"], portable: true, onePan: true,
            title: { f in
                guard let p = f["p"] else { return "Макароны по-флотски" }
                return Say.cook(p) == .cannedMeat ? "Макароны по-флотски " + Say.with(p.words.ins) : "Макароны по-флотски"
            },
            steps: { f in
                guard let sd = f["s"], let p = f["p"] else { return [] }
                var s = [Say.side(sd)]
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                let canned = Say.cook(p) == .cannedMeat
                if !veg.isEmpty { s.append("Разогрей сковороду\(canned ? "" : " с маслом") и обжарь \(Say.list(veg.map { $0.words.acc })) 4 минуты.") }
                else if !canned { s.append("Разогрей масло в сковороде.") }
                if canned, let pr = Say.prep(p) { s.append(pr) }
                s.append(Say.pan(p))
                if let tp = f["tp"] { s.append("Добавь \(tp.words.acc) и пару ложек воды.") }
                s.append("Смешай \(Say.with(sd.words.ins)), посоли, поперчи и прогрей вместе 2 минуты.")
                return s
            }))

        t.append(T("cream_pasta", [.main], minutes: 25,
            slots: [S("s", [.pasta], range: 70...120),
                    S("p", [.meat, .fish], no: ["ground", "canned", "bone", "salted"], noCooks: [.liver, .bacon, .cannedMeat, .cannedFish, .groundMeat, .noCook, .sausage], main: true),
                    S("m", [.vegetable, .greens], req: false, tags: ["mushroom", "cookable", "green"], no: ["raw"]),
                    S("c", [.cheese], req: false, tags: ["grate", "melt"], no: ["slice", "stick"], range: 15...30)],
            extras: [XA("cr", [("c:cream_10", 80...150), ("c:cream_cheese", 30...60), ("c:sour_cream_10", 60...120), ("c:sour_cream", 40...80), ("c:cream_33", 40...70)], req: true),
                     X("fat", fat, 5...10)],
            spices: ["c:salt", "c:pepper", "c:garlic", "c:nutmeg", "c:italian_herbs"], portable: true,
            title: { f in "Паста " + Say.with(f["p"].map { $0.words.ins } ?? "курицей") + " в сливочном соусе" },
            steps: { f in
                guard let sd = f["s"], let p = f["p"], let cr = f["cr"] else { return [] }
                var s = [Say.side(sd)]
                if let pr = Say.prep(p) { s.append(pr) }
                if let m = f["m"] { s += Say.vegPrep([m]) }
                s.append("Разогрей масло в сковороде.")
                s.append(Say.pan(p))
                if let m = f["m"] { s.append("Добавь \(m.words.acc) и жарь 3–4 минуты.") }
                let garlic = RK.on(f, "c:garlic") ? ", выдави зубчик чеснока" : ""
                s.append("Добавь \(cr.words.acc) и 100 мл воды из-под макарон\(garlic) и прогрей 2–3 минуты, пока соус не загустеет.")
                s.append("Смешай \(Say.with(sd.words.ins))\(f["c"].map { ", посыпь \($0.words.ins)" } ?? "").")
                return s
            }))

        t.append(T("fried_rice", [.main], minutes: 25,
            slots: [S("r", [.grain], tags: ["rice"], range: 50...100),
                    S("e", [.eggs], no: ["quail"], range: 50...150, main: true),
                    S("p", [.meat, .fish, .sausage], req: false, no: ["salted", "canned"], noCooks: [.liver, .cannedFish, .cannedMeat, .dryBeans]),
                    S("v", [.vegetable], req: false, tags: ["peas", "corn", "carrot", "mix", "pepper", "onion"], no: ["raw", "hot"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...10)],
            extras: [X("soy", ["c:soy_sauce", "c:teriyaki"], 15...25, req: true), X("fat", fat, 8...12)],
            spices: ["c:garlic", "c:ginger", "c:pepper"], portable: true, onePan: true,
            title: { f in "Жареный рис с яйцом" + (f["p"].map { " и " + $0.words.ins } ?? "") },
            steps: { f in
                guard let r = f["r"], let soy = f["soy"] else { return [] }
                var s = [Say.side(r), "Дай рису остыть — лучше всего жарить вчерашний холодный рис."]
                if let p = f["p"] {
                    s += RK.protein(p)
                    if Say.needsHeat(p) { s.append("Сдвинь на край сковороды.") }
                } else {
                    s.append("Разогрей масло в сковороде.")
                }
                if let v = f["v"] { s += Say.vegPrep([v]); s.append("Добавь \(v.words.acc) и жарь 3 минуты.") }
                s.append("Вбей яйца и помешивай минуту, пока не схватятся.")
                var add = ["рис", soy.words.acc]
                add += Say.spiceList(f.spices)
                s.append("Добавь \(Say.list(add)) и жарь на сильном огне 3–4 минуты, постоянно помешивая.")
                if let h = f["h"] { s.append("Посыпь \(h.words.ins).") }
                return s
            }))

        t.append(T("curry", [.main], minutes: 35,
            slots: [S("p", [.meat, .legumes, .fish], no: ["ground", "bone", "salted"], noCooks: [.liver, .bacon, .cannedFish, .groundMeat, .cannedMeat, .dryBeans, .noCook, .sausage], main: true),
                    S("r", [.grain], tags: ["rice"], range: 50...100),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("v2", [.vegetable, .greens], req: false, tags: ["pepper", "green", "mix", "cookable", "pumpkin", "cream"], no: ["raw", "hot"])],
            extras: [XA("cr", [("c:cream_10", 60...120), ("c:greek_yogurt_0", 60...120), ("c:yogurt_plain", 60...120), ("c:sour_cream_10", 50...100)]),
                     XA("tp", [("c:tomato_paste", 15...30), ("c:marinara", 60...120)]), X("fat", fat, 6...12)],
            spices: ["c:curry", "c:turmeric", "c:garlic", "c:ginger", "c:cumin", "c:salt"], portable: true, weight: 1.1,
            check: { f in RK.on(f, "c:curry") || RK.on(f, "c:turmeric") },
            title: { f in
                guard let p = f["p"], let r = f["r"] else { return "Карри" }
                return "Карри " + Say.with(p.words.ins) + " и " + r.words.ins
            },
            steps: { f in
                guard let p = f["p"], let r = f["r"] else { return [] }
                let c = Say.cook(p)
                var s = [Say.side(r)]
                if c == .lentils { s.append("Промой \(p.words.acc).") }
                else if let pr = Say.prep(p) { s.append(pr) }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s.append("Разогрей масло в сковороде\(f["v"].map { " и обжарь \($0.words.acc) 3–4 минуты" } ?? "").")
                if c != .lentils && Say.needsHeat(p) { s.append(Say.pan(p)) }
                let sp = Say.spiceList(f.spices)
                if !sp.isEmpty { s.append("Добавь \(Say.list(sp)) и прогрей 30 секунд, чтобы раскрылся аромат.") }
                if let v2 = f["v2"] { s.append("Добавь \(v2.words.acc).") }
                let cr = f["cr"]
                let yogurt = cr?.role == .yogurt
                var pour = RK.A([f["tp"]])
                if let cc = cr, !yogurt { pour.append(cc.words.acc) }
                pour.append(c == .lentils ? "500 мл воды" : "200 мл воды")
                s.append("Влей \(Say.list(pour)).")
                if c == .cannedLegumes { s.append("Откинь \(p.words.acc) на дуршлаг и добавь в сковороду.") }
                if c == .lentils { s.append("Добавь чечевицу и туши под крышкой 20 минут, пока она не станет мягкой.") }
                else { s.append("Туши под крышкой 12–15 минут и посоли по вкусу.") }
                if let cc = cr, yogurt { s.append("Сними с огня и вмешай \(cc.words.acc) — на огне йогурт свернётся.") }
                s.append("Подавай \(Say.with(r.words.ins)).")
                return s
            }))

        t.append(T("teriyaki_bowl", [.main], minutes: 30,
            slots: [S("p", [.meat, .fish, .legumes], tags: ["chicken", "turkey", "fatty", "tofu", "shrimp", "pork"], no: ["ground", "canned", "salted", "bone"], noCooks: [.liver, .groundMeat, .cannedFish, .cannedMeat, .bacon, .sausage, .noCook], main: true),
                    S("r", [.grain, .pasta], tags: ["rice", "noodles"]),
                    S("v", [.vegetable], req: false, tags: ["green", "mix", "pepper"], no: ["raw", "hot"]),
                    S("ss", [.nuts], req: false, tags: ["topping"], no: ["coconut"], range: 3...8)],
            extras: [XA("sc", [("c:teriyaki", 30...50), ("c:soy_sauce", 20...30)], req: true),
                     X("hn", ["c:honey", "c:sugar"], 8...15, when: { f in f["sc"]?.isKind("c:soy_sauce") ?? false }),
                     X("fat", fat, 6...10)],
            spices: ["c:garlic", "c:ginger"], portable: true,
            title: { f in
                guard let p = f["p"], let r = f["r"] else { return "Терияки" }
                return p.words.title + " терияки " + Say.with(r.words.ins)
            },
            steps: { f in
                guard let p = f["p"], let r = f["r"], let sc = f["sc"] else { return [] }
                var s = [Say.side(r)]
                if let pr = Say.prep(p) { s.append(pr) }
                if let v = f["v"] { s += Say.vegPrep([v]) }
                s.append("Разогрей масло в сковороде.")
                s.append(Say.pan(p))
                if let v = f["v"] { s.append("Добавь \(v.words.acc) и жарь 3 минуты.") }
                if sc.isKind("c:teriyaki") {
                    s.append("Влей \(sc.words.acc) и прогрей 2 минуты, пока соус не покроет всё глазурью.")
                } else {
                    var mix = RK.I([f["hn"]])
                    if RK.on(f, "c:garlic") { mix.append("чесноком") }
                    if RK.on(f, "c:ginger") { mix.append("имбирём") }
                    mix.append("2 ложками воды")
                    s.append("Смешай \(sc.words.acc) \(Say.with(Say.list(mix))), влей в сковороду и уваривай 2 минуты до глазури.")
                }
                if let ss = f["ss"] { s.append("Посыпь \(ss.words.ins).") }
                s.append("Подавай \(Say.with(r.words.ins)).")
                return s
            }))

        // ───────────── Рыба ─────────────

        t.append(T("fish_veg_oven", [.main], minutes: 35,
            slots: [S("p", [.fish], noCooks: [.cannedFish, .noCook, .shrimp], main: true),
                    S("v", [.vegetable], tags: ["stew", "pepper", "tomato", "onion", "green", "zucchini"], no: ["raw", "fatty", "hot"]),
                    S("v2", [.vegetable], req: false, tags: ["stew", "pepper", "tomato", "onion", "green", "zucchini"], no: ["raw", "fatty", "hot"]),
                    S("c", [.cheese], req: false, tags: ["melt", "grate"], no: ["slice", "stick"], range: 15...30),
                    S("s", [.grain], req: false, noCooks: [.barley])],
            extras: [X("fat", ["c:olive_oil", "c:sunflower_oil"], 6...12), X("sc", ["c:sour_cream_10", "c:sour_cream"], 20...40)],
            spices: ["c:salt", "c:pepper", "c:lemon_juice", "c:italian_herbs", "c:garlic_dry"], oven: true, onePan: true,
            title: { f in
                guard let p = f["p"] else { return "Рыба с овощами в духовке" }
                return p.words.title + " с овощами в духовке" + (f["c"] != nil ? " под сыром" : "")
            },
            steps: { f in
                guard let p = f["p"], let v = f["v"] else { return [] }
                var s = ["Разогрей духовку до 200 °C."]
                if let sd = f["s"] { s.append(Say.side(sd)) }
                let veg = [v] + f.all(["v2"])
                s += Say.vegPrep(veg)
                s.append("Выложи \(Say.list(veg.map { $0.words.acc })) в форму, сбрызни маслом и посоли.")
                if let pr = Say.prep(p) { s.append(pr) }
                var put = "Положи \(p.words.acc) сверху"
                if RK.on(f, "c:lemon_juice") { put += ", сбрызни лимонным соком" }
                let herbs = Say.spiceList(f.spices.filter { !$0.isKind("c:pepper") })
                if !herbs.isEmpty { put += " и посыпь: \(Say.list(herbs))" }
                s.append(put + ".")
                if let sc = f["sc"] { s.append("Смажь рыбу \(sc.words.ins).") }
                s.append("Запекай 20 минут.")
                if let c = f["c"] { s.append("За 5 минут до конца посыпь \(c.words.ins).") }
                if let sd = f["s"] { s.append("Подавай \(Say.with(sd.words.ins)).") }
                return s
            }))

        t.append(T("herring_potato", [.main], minutes: 30,
            slots: [S("p", [.fish], tags: ["herring"], range: 80...150, main: true),
                    S("s", [.potato], cooks: [.potato], range: 200...350),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("pk", [.vegetable], req: false, tags: ["pickled", "kraut"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15)],
            extras: [X("fat", ["c:sunflower_oil", "c:olive_oil", "c:butter"], 5...10)],
            spices: ["c:salt", "c:vinegar"], weight: 0.7,
            title: { _ in "Сельдь с варёной картошкой" },
            steps: { f in
                guard let p = f["p"], let pt = f["s"] else { return [] }
                var s = ["Почисть \(pt.words.acc) и отвари целиком в подсоленной воде 20–25 минут."]
                if let v = f["v"] { s.append("Нарежь \(v.words.acc) тонкими кольцами\(RK.on(f, "c:vinegar") ? " и сбрызни уксусом" : "").") }
                s.append("Нарежь \(p.words.acc) кусочками.")
                var pour = "Полей горячую картошку \(f["fat"].map { $0.words.ins } ?? "маслом")"
                if let h = f["h"] { pour += " и посыпь \(h.words.ins)" }
                s.append(pour + ".")
                s.append("Подавай \(Say.with(Say.list(RK.I([p, f["v"], f["pk"]])))).")
                return s
            }))

        // ───────────── Овощи, бобовые, выпечка на сковороде ─────────────

        t.append(T("draniki", [.main, .breakfast], minutes: 35,
            slots: [S("s", [.potato], cooks: [.potato], range: 300...500, main: true),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...100),
                    S("v", [.vegetable], req: false, tags: ["onion"], range: 40...80)],
            extras: [X("fl", ["c:flour", "c:starch"], 15...30), X("sc", RK.sour, 30...60), X("fat", fat, 10...20)],
            spices: ["c:salt", "c:pepper", "c:garlic"], weight: 0.8,
            title: { f in "Драники" + (f["sc"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let pt = f["s"] else { return [] }
                var s = ["Почисть и натри на мелкой тёрке \(Say.list(RK.A([pt, f["v"]]))), отожми лишний сок."]
                let add = ["яйца"] + RK.A([f["fl"]]) + ["соль", "перец"]
                s.append("Добавь \(Say.list(add)) и перемешай.")
                s.append("Разогрей масло и выкладывай массу ложкой тонкими лепёшками.")
                s.append("Жарь по 3–4 минуты с каждой стороны до хрустящей корочки.")
                if let sc = f["sc"] { s.append("Подавай горячими \(Say.with(sc.words.ins)).") }
                return s
            }))

        t.append(T("zucchini_fritters", [.main, .breakfast, .snack], minutes: 30,
            slots: [S("v", [.vegetable], tags: ["zucchini"], range: 250...400),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...100, main: true),
                    S("c", [.cheese], req: false, tags: ["melt", "salad", "grate"], no: ["stick", "slice"], range: 20...40),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...10)],
            extras: [X("fl", ["c:flour", "c:oat_flour", "c:rice_flour"], 30...50, req: true), X("sc", RK.sour, 30...60), X("fat", fat, 8...14)],
            spices: ["c:salt", "c:pepper", "c:garlic"], weight: 0.8,
            title: { f in "Кабачковые оладьи" + (f["c"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let v = f["v"], let fl = f["fl"] else { return [] }
                var s = ["Натри \(v.words.acc) на крупной тёрке, посоли и через 10 минут отожми сок."]
                if let c = f["c"] { s.append("Натри \(c.words.acc).") }
                if let h = f["h"] { s.append("Мелко порежь \(h.words.acc).") }
                var add = ["яйца"] + RK.A([f["c"], f["h"]]) + [fl.words.acc]
                if RK.on(f, "c:garlic") { add.append("выдавленный чеснок") }
                s.append("Добавь \(Say.list(add)) и перемешай.")
                s.append("Жарь на масле ложкой небольшие оладьи по 3 минуты с каждой стороны.")
                if let sc = f["sc"] { s.append("Подавай \(Say.with(sc.words.ins)).") }
                return s
            }))

        t.append(T("stewed_cabbage", [.main], minutes: 45,
            slots: [S("cb", [.vegetable], tags: ["cabbage", "kraut"], range: 200...400),
                    S("p", [.sausage, .meat], no: ["cooked"], noCooks: [.liver, .noCook, .cookedMeat], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("v2", [.vegetable], req: false, tags: ["carrot"])],
            extras: [X("tp", ["c:tomato_paste"], 15...30), X("fat", fat, 6...12, when: RK.heats)],
            spices: ["c:salt", "c:pepper", "c:bay_leaf", "c:paprika", "c:cumin"], portable: true, onePan: true,
            title: { f in
                let base = f["cb"]?.has("kraut") == true ? "Тушёная квашеная капуста" : "Тушёная капуста"
                return base + " " + Say.with(f["p"].map { $0.words.ins } ?? "мясом")
            },
            steps: { f in
                guard let cb = f["cb"], let p = f["p"] else { return [] }
                var s: [String] = []
                if cb.has("kraut") { s.append("Промой \(cb.words.acc), если она слишком кислая, и отожми.") }
                else { s.append("Нашинкуй \(cb.words.acc).") }
                let veg = f.all(["v", "v2"])
                s += Say.vegPrep(veg)
                s += RK.protein(p)
                if !veg.isEmpty { s.append("Добавь \(Say.list(veg.map { $0.words.acc })) и жарь 4 минуты.") }
                var add = ["капусту"] + RK.A([f["tp"]])
                add += Say.spiceList(f.spices)
                add.append("100 мл воды")
                s.append("Добавь \(Say.list(add)) и посоли.")
                s.append("Туши под крышкой 25–30 минут, помешивая, пока капуста не станет мягкой.")
                return s
            }))

        t.append(T("potato_casserole", [.main], minutes: 60,
            slots: [S("s", [.potato], cooks: [.potato], range: 250...450),
                    S("p", [.meat], tags: ["ground"], main: true),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("c", [.cheese], req: false, tags: ["melt"], no: ["stick", "slice"], range: 20...40),
                    S("e", [.eggs], req: false, no: ["whites", "quail"], range: 50...60),
                    S("m", [.milk], req: false, no: ["rtd", "kefir"], range: 50...100)],
            extras: [X("fat", fat, 6...10), X("but", ["c:butter"], 5...10)],
            spices: ["c:salt", "c:pepper", "c:nutmeg", "c:paprika"], oven: true, portable: true,
            title: { _ in "Картофельная запеканка с фаршем" },
            steps: { f in
                guard let pt = f["s"], let p = f["p"] else { return [] }
                var s = ["Почисть \(pt.words.acc) и отвари 15–18 минут."]
                var mash = RK.I([f["m"], f["but"]])
                if f["e"] != nil { mash.append("яйцом") }
                s.append(mash.isEmpty ? "Слей воду и разомни картошку в пюре." : "Слей воду и разомни картошку в пюре \(Say.with(Say.list(mash))).")
                s.append("Разогрей духовку до 190 °C.")
                if let v = f["v"] { s.append("Мелко нарежь \(v.words.acc) и обжарь на масле 3 минуты.") }
                else { s.append("Разогрей масло в сковороде.") }
                s.append(Say.pan(p))
                s.append("Посоли и поперчи фарш.")
                s.append("Выложи в форму половину пюре, сверху фарш, затем остальное пюре и разровняй.")
                if let c = f["c"] { s.append("Натри \(c.words.acc) и посыпь сверху.") }
                s.append("Запекай 20–25 минут до румяной корочки.")
                return s
            },
            tip: { _ in "Запеканку удобно разрезать на порции и разогревать в микроволновке." }))

        t.append(T("lobio", [.main], minutes: 30,
            slots: [S("l", [.legumes], tags: ["beans"], cooks: [.cannedLegumes, .dryBeans], range: 150...300, main: true),
                    S("v", [.vegetable], req: false, tags: ["onion"]),
                    S("t", [.vegetable], req: false, tags: ["tomato"]),
                    S("n", [.nuts], req: false, tags: ["walnut"], range: 15...30),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...15),
                    S("b", [.bread], req: false, tags: ["slice", "pocket", "wrap"], range: 40...80)],
            extras: [X("fat", fat, 6...10)],
            spices: ["c:salt", "c:khmeli_suneli", "c:coriander", "c:garlic", "c:chili", "c:vinegar"], portable: true, onePan: true,
            title: { f in "Лобио" + (f["n"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let l = f["l"] else { return [] }
                var s = [Say.side(l)]
                let veg = f.all(["v", "t"])
                s += Say.vegPrep(veg)
                if !veg.isEmpty { s.append("Обжарь \(Say.list(veg.map { $0.words.acc })) на масле 4–5 минут.") }
                else { s.append("Разогрей масло в сковороде.") }
                let sp = Say.spiceList(f.spices.filter { !$0.isKind("c:garlic") })
                s.append(sp.isEmpty ? "Добавь фасоль и полстакана воды." : "Добавь фасоль, полстакана воды и специи: \(Say.list(sp)).")
                s.append("Разомни часть фасоли толкушкой.")
                s.append("Туши 10 минут, иногда помешивая.")
                if let n = f["n"] { s.append("Измельчи \(n.words.acc) и вмешай.") }
                var end: [String] = []
                if RK.on(f, "c:garlic") { end.append("добавь выдавленный чеснок") }
                if RK.on(f, "c:vinegar") { end.append("сбрызни уксусом") }
                if !end.isEmpty { s.append("В конце \(end.joined(separator: " и ")).") }
                if let h = f["h"] { s.append("Посыпь \(h.words.ins).") }
                if let b = f["b"] { s.append("Подавай \(Say.with(b.words.ins)).") }
                return s
            }))

        t.append(T("khachapuri_lazy", [.breakfast, .main, .snack], minutes: 25,
            slots: [S("c", [.cheese], tags: ["melt", "salad"], no: ["stick", "slice", "grate"], range: 60...120, main: true),
                    S("m", [.milk, .yogurt], no: ["rtd", "dessert_ready"], range: 100...200),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...100),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...10)],
            extras: [X("fl", ["c:flour"], 50...80, req: true), X("fat", fat, 5...10)],
            spices: ["c:salt", "c:baking_soda"], onePan: true,
            title: { _ in "Ленивые хачапури на сковороде" },
            steps: { f in
                guard let c = f["c"], let m = f["m"], let fl = f["fl"] else { return [] }
                var s = ["Натри \(c.words.acc)."]
                if let h = f["h"] { s.append("Мелко порежь \(h.words.acc).") }
                var mix = ["яйцами", fl.words.ins]
                if RK.on(f, "c:baking_soda") { mix.append("щепоткой соды") }
                s.append("Смешай \(m.words.acc) \(Say.with(Say.list(mix))), добавь сыр\(f["h"] != nil ? " и зелень" : "").")
                s.append("Разогрей масло в сковороде, вылей тесто и разровняй.")
                s.append("Жарь под крышкой на слабом огне 7–8 минут, переверни и жарь ещё 4–5 минут.")
                return s
            }))

        // ───────────── Салаты ─────────────

        t.append(T("olivier", [.main], minutes: 40,
            slots: [S("s", [.potato], cooks: [.potato], range: 100...200),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...150),
                    S("pr", [.sausage, .meat], no: ["ground", "bone", "canned", "salted"], noCooks: [.liver, .bacon, .sausage, .groundMeat, .cannedMeat], main: true),
                    S("pe", [.vegetable], tags: ["peas"], range: 40...100),
                    S("pk", [.vegetable], req: false, tags: ["pickled"]),
                    S("v", [.vegetable], req: false, tags: ["carrot"]),
                    S("v2", [.vegetable], req: false, tags: ["cucumber"]),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...10)],
            extras: [XA("dr", mayoLike, req: true)],
            spices: ["c:salt", "c:pepper"], portable: true,
            title: { f in "Оливье " + Say.with(f["pr"].map { $0.words.ins } ?? "колбасой") },
            steps: { f in
                guard let pt = f["s"], let pr = f["pr"], let pe = f["pe"], let dr = f["dr"] else { return [] }
                var s = ["Отвари \(Say.list(RK.A([pt, f["v"]]))) в мундире 20–25 минут и остуди.", RK.boiled(false)]
                if let m = RK.brothMinutes(pr) { s.append("Отвари \(pr.words.acc) в подсоленной воде \(m) и остуди.") }
                else if let x = Say.prep(pr), Say.cook(pr) == .cookedMeat { s.append(x) }
                switch Say.cook(pe) {
                case .frozenVeg: s.append("Отвари \(pe.words.acc) 3 минуты и остуди.")
                case .cannedVeg: s.append("Откинь \(pe.words.acc) на дуршлаг.")
                default: break
                }
                var cut = RK.A([pt, f["v"]])
                cut += ["яйца", pr.words.acc]
                cut += RK.A([f["pk"], f["v2"]])
                s.append("Почисть и нарежь мелкими кубиками \(Say.list(cut)).")
                s.append("Добавь \(Say.list(RK.A([pe, f["h"]]))).")
                s.append("Заправь \(dr.words.ins), посоли и поперчи.")
                return s
            },
            tip: { _ in "Заправляй прямо перед едой — так салат дольше хранится." }))

        t.append(T("caesar", [.main], minutes: 25,
            slots: [S("g", [.greens], tags: ["leaf"], no: ["herb"], range: 80...150),
                    S("p", [.meat, .fish], tags: ["chicken", "turkey", "shrimp"], no: ["ground", "canned", "bone"], noCooks: [.liver, .groundMeat, .bacon, .cannedMeat, .sausage], main: true),
                    S("c", [.cheese], tags: ["grate", "melt"], no: ["slice", "stick", "spread"], range: 15...30),
                    S("b", [.bread], req: false, tags: ["slice", "bun"], range: 20...50),
                    S("t", [.vegetable], req: false, tags: ["tomato"]),
                    S("e", [.eggs], req: false, no: ["whites"], range: 50...100)],
            extras: [XA("dr", [("c:caesar_dressing", 20...40), ("c:mayo_light", 20...35), ("c:mayo", 15...30), ("c:greek_yogurt_0", 40...70)], req: true),
                     X("fat", fat, 5...10, when: RK.heats)],
            spices: ["c:salt", "c:pepper", "c:garlic", "c:lemon_juice"], portable: true,
            title: { f in "Цезарь " + Say.with(f["p"].map { $0.words.ins } ?? "курицей") },
            steps: { f in
                guard let g = f["g"], let p = f["p"], let c = f["c"], let dr = f["dr"] else { return [] }
                var s = RK.protein(p)
                if Say.needsHeat(p) { s.append("Дай немного остыть и нарежь.") }
                if let b = f["b"] { s.append("Нарежь \(b.words.acc) кубиками и подсуши на сухой сковороде 3–4 минуты — получатся сухарики.") }
                if f["e"] != nil { s.append(RK.boiled(true)) }
                s.append("Порви руками \(g.words.acc).")
                if let tm = f["t"] { s += Say.vegPrep([tm]) }
                if !dr.isKind("c:caesar_dressing") {
                    var add: [String] = []
                    if RK.on(f, "c:garlic") { add.append("выдавленным чесноком") }
                    if RK.on(f, "c:lemon_juice") { add.append("лимонным соком") }
                    if !add.isEmpty { s.append("Смешай \(dr.words.acc) \(Say.with(Say.list(add))) — получится соус.") }
                }
                var parts = RK.A([g, f["t"], p])
                if f["e"] != nil { parts.append("яйца половинками") }
                if f["b"] != nil { parts.append("сухарики") }
                s.append("Собери салат: \(Say.list(parts)).")
                s.append("Полей соусом и посыпь \(c.words.ins).")
                return s
            },
            tip: { _ in "С собой бери соус отдельно — листья не размокнут." }))

        t.append(T("crab_salad", [.main, .snack], minutes: 25,
            slots: [S("p", [.fish], tags: ["crab"], range: 100...200, main: true),
                    S("e", [.eggs], no: ["whites", "quail"], range: 50...150),
                    S("cn", [.vegetable], tags: ["corn"], range: 60...120),
                    S("v", [.vegetable], req: false, tags: ["cucumber"]),
                    S("r", [.grain], req: false, tags: ["rice"], range: 20...40),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...10)],
            extras: [XA("dr", mayoLike, req: true)],
            spices: ["c:salt", "c:pepper"], portable: true,
            title: { _ in "Крабовый салат" },
            steps: { f in
                guard let p = f["p"], let cn = f["cn"], let dr = f["dr"] else { return [] }
                var s: [String] = []
                if let r = f["r"] { s.append(Say.side(r)); s.append("Остуди рис.") }
                s.append(RK.boiled(false))
                s.append("Нарежь кубиками \(Say.list([p.words.acc, "яйца"] + RK.A([f["v"]]))).")
                s += Say.vegPrep([cn])
                if let h = f["h"] { s.append("Мелко порежь \(h.words.acc).") }
                s.append("Смешай всё, заправь \(dr.words.ins) и посоли.")
                return s
            }))

        t.append(T("vinegret", [.main, .snack], minutes: 60,
            slots: [S("bt", [.vegetable], tags: ["beet"], range: 100...200),
                    S("s", [.potato], cooks: [.potato], range: 100...200),
                    S("v", [.vegetable], req: false, tags: ["carrot"]),
                    S("pk", [.vegetable], tags: ["pickled", "kraut"], range: 50...120),
                    S("l", [.legumes, .vegetable], req: false, tags: ["beans", "peas"], cooks: [.cannedLegumes, .cannedVeg, .frozenVeg], range: 50...120),
                    S("p", [.fish], req: false, tags: ["herring", "salted"], main: true),
                    S("h", [.greens], req: false, tags: ["herb"], range: 5...10)],
            extras: [X("dr", ["c:sunflower_oil", "c:olive_oil"], 10...15, req: true)],
            spices: ["c:salt"], portable: true, weight: 0.6,
            title: { f in "Винегрет" + (f["p"].map { " " + Say.with($0.words.ins) } ?? "") },
            steps: { f in
                guard let bt = f["bt"], let pt = f["s"], let pk = f["pk"], let dr = f["dr"] else { return [] }
                var s = ["Отвари \(Say.list(RK.A([bt, pt, f["v"]]))) в мундире до мягкости: свёкла варится около часа, остальное — 20–25 минут.",
                         "Остуди, почисть и нарежь мелкими кубиками."]
                s.append(pk.has("nocut") ? "Отожми \(pk.words.acc)." : "Нарежь \(pk.words.acc).")
                if let l = f["l"] {
                    switch Say.cook(l) {
                    case .frozenVeg: s.append("Отвари \(l.words.acc) 3 минуты.")
                    default: s.append("Откинь \(l.words.acc) на дуршлаг.")
                    }
                }
                if let h = f["h"] { s.append("Мелко порежь \(h.words.acc).") }
                s.append("Смешай всё, заправь \(dr.words.ins) и посоли.")
                if let p = f["p"] { s.append("Нарежь \(p.words.acc) кусочками и подавай рядом.") }
                return s
            },
            tip: { _ in "Свёклу отваривай заранее — с ней винегрет собирается за 10 минут." }))

        t.append(T("pizza_lavash", [.main, .snack], minutes: 20,
            slots: [S("b", [.bread], tags: ["wrap"], range: 50...120),
                    S("c", [.cheese], tags: ["melt"], no: ["stick", "slice"], range: 40...90),
                    S("p", [.sausage, .meat, .fish], req: false, no: ["salted"], cooks: [.noCook, .cookedMeat, .cannedFish, .sausage], main: true),
                    S("v", [.vegetable], req: false, tags: ["tomato", "mushroom", "pepper", "onion", "fatty"], no: ["avocado", "hot"])],
            extras: [XA("t", [("c:marinara", 40...80), ("c:tomato_paste", 15...25), ("c:ketchup", 20...35)], req: true)],
            spices: ["c:oregano", "c:basil", "c:italian_herbs"], onePan: true,
            title: { f in
                guard let b = f["b"] else { return "Пицца" }
                let base = b.isKind("c:lavash") ? "Пицца на лаваше" : "Пицца на тортилье"
                return base + (f["p"].map { " " + Say.with($0.words.ins) } ?? "")
            },
            steps: { f in
                guard let b = f["b"], let c = f["c"], let tm = f["t"] else { return [] }
                var s = ["Смажь \(b.words.acc) \(tm.words.ins)\(tm.isKind("c:tomato_paste") ? ", разведённой ложкой воды" : "")."]
                if let p = f["p"] {
                    if Say.cook(p) == .cannedFish, let pr = Say.prep(p) { s.append(pr) }
                    else { s.append("Нарежь \(p.words.acc) тонкими ломтиками.") }
                }
                if let v = f["v"] { s += Say.vegPrep([v]) }
                let top = RK.A([f["p"], f["v"]])
                if !top.isEmpty { s.append("Разложи сверху \(Say.list(top)).") }
                s.append("Натри \(c.words.acc) и посыпь сверху.")
                s.append("Выложи на сковороду, накрой крышкой и готовь на среднем огне 6–8 минут, пока сыр не расплавится, а низ не станет хрустящим.")
                if !Say.spiceList(f.spices).isEmpty { s.append("Посыпь \(Say.list(Say.spiceList(f.spices))) и нарежь на куски.") }
                else { s.append("Нарежь на куски.") }
                return s
            }))

        return t
    }
}
