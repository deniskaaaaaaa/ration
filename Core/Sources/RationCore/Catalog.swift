import Foundation

/// Встроенный каталог обычных продуктов на русском. КБЖУ — на 100 г сырого или сухого продукта,
/// по таблицам USDA (FoodData Central) и обычным значениям с упаковок.
public enum Catalog {
    public static let all: [Food] = build()

    public static let byID: [String: Food] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    public static func food(_ id: String) -> Food? { byID[id] }

    /// Что по умолчанию «всегда есть дома».
    public static let defaultStapleIDs: [String] = [
        "c:salt", "c:pepper", "c:paprika", "c:garlic_dry", "c:onion_dry", "c:turmeric", "c:oregano",
        "c:basil", "c:chicken_spice", "c:bay_leaf", "c:italian_herbs", "c:cinnamon",
        "c:sunflower_oil", "c:olive_oil", "c:butter",
        "c:ketchup", "c:mayo", "c:mustard", "c:soy_sauce", "c:tomato_paste",
        "c:sugar", "c:flour", "c:honey", "c:vinegar", "c:lemon_juice"
    ]

    /// Продукт из базы штрихкодов: слова для рецепта, способ готовки и вес штуки берутся у вида из каталога.
    public static func packaged(code: String, name: String, brand: String?, per100: Macros,
                                role: Role, kind: String?) -> Food {
        let k = kind.flatMap { byID[$0] }
        return Food(id: "off:" + code, name: name, brand: brand, role: role, tags: k?.tags ?? [],
                    per100: per100, pieceGrams: k?.pieceGrams, forms: k?.forms, cook: k?.cook,
                    source: .barcode, barcode: code, aliases: [], kind: kind)
    }

    /// Поиск по каталогу: по русскому названию и английским синонимам.
    public static func search(_ query: String, limit: Int = 30) -> [Food] {
        let q = normalize(query)
        guard !q.isEmpty else { return [] }
        let words = q.split(separator: " ").map(String.init)
        var scored: [(Int, Food)] = []
        for food in all {
            let hay = normalize(food.name + " " + food.aliases.joined(separator: " "))
            guard words.allSatisfy({ hay.contains($0) }) else { continue }
            let name = normalize(food.name)
            let score = name.hasPrefix(q) ? 0 : (name.contains(q) ? 1 : 2)
            scored.append((score, food))
        }
        return scored.sorted { $0.0 == $1.0 ? $0.1.name < $1.1.name : $0.0 < $1.0 }.prefix(limit).map { $0.1 }
    }

    /// Продукт каталога по метке распознавания изображения (английский идентификатор).
    public static func matchVisionLabel(_ label: String) -> Food? {
        let l = label.lowercased().replacingOccurrences(of: "_", with: " ")
        for food in all where food.role != .spice {
            if food.aliases.contains(where: { $0 == l }) { return food }
        }
        return nil
    }

    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Список

    private static func g(_ id: String, _ name: String, _ role: Role,
                          _ kcal: Double, _ p: Double, _ f: Double, _ c: Double,
                          _ forms: (String, String, String),
                          tags: [String] = [], piece: Double? = nil, cook: Cook? = nil, en: [String] = []) -> Food {
        Food(id: "c:" + id, name: name, role: role, tags: tags,
             per100: Macros(kcal: kcal, p: p, f: f, c: c), pieceGrams: piece,
             forms: Forms(forms.0, acc: forms.1, ins: forms.2), cook: cook, source: .catalog, aliases: en)
    }

    private static func build() -> [Food] {
        var a: [Food] = []

        // Птица и мясо (сырые)
        a += [
            g("chicken_breast", "Куриное филе (грудка)", .meat, 120, 22.5, 2.6, 0, ("Курица", "куриное филе", "курицей"), tags: ["chicken", "lean"], cook: .chicken, en: ["chicken breast", "chicken"]),
            g("chicken_thigh", "Куриные бёдра без кожи", .meat, 121, 19.7, 4.1, 0, ("Курица", "куриные бёдра", "курицей"), tags: ["chicken"], cook: .chicken, en: ["chicken thigh", "chicken thighs"]),
            g("chicken_drumstick", "Куриные голени", .meat, 161, 18.1, 9.2, 0, ("Курица", "куриные голени", "курицей"), tags: ["chicken", "bone"], cook: .chicken, en: ["chicken drumstick", "drumsticks"]),
            g("chicken_wings", "Куриные крылья", .meat, 191, 17.5, 12.9, 0, ("Крылышки", "крылья", "крылышками"), tags: ["chicken", "bone"], cook: .chicken, en: ["chicken wings", "wings"]),
            g("ground_chicken", "Куриный фарш", .meat, 143, 17.4, 8.1, 0, ("Фарш", "куриный фарш", "куриным фаршем"), tags: ["chicken", "ground"], cook: .groundMeat, en: ["ground chicken"]),
            g("turkey_breast", "Филе индейки", .meat, 114, 23.7, 1.5, 0, ("Индейка", "филе индейки", "индейкой"), tags: ["turkey", "lean"], cook: .chicken, en: ["turkey breast", "turkey"]),
            g("ground_turkey", "Фарш индейки 93/7", .meat, 150, 18.7, 8.3, 0, ("Фарш", "фарш индейки", "фаршем индейки"), tags: ["turkey", "ground"], cook: .groundMeat, en: ["ground turkey"]),
            g("ground_beef_90", "Говяжий фарш 90/10", .meat, 176, 20, 10, 0, ("Фарш", "говяжий фарш", "говяжьим фаршем"), tags: ["beef", "ground"], cook: .groundMeat, en: ["lean ground beef"]),
            g("ground_beef_85", "Говяжий фарш 85/15", .meat, 215, 18.6, 15, 0, ("Фарш", "говяжий фарш", "говяжьим фаршем"), tags: ["beef", "ground"], cook: .groundMeat, en: ["ground beef"]),
            g("ground_beef_80", "Говяжий фарш 80/20", .meat, 254, 17.2, 20, 0, ("Фарш", "говяжий фарш", "говяжьим фаршем"), tags: ["beef", "ground"], cook: .groundMeat, en: ["ground beef 80"]),
            g("beef_lean", "Говядина постная (стейк)", .meat, 150, 21, 7, 0, ("Говядина", "говядину", "говядиной"), tags: ["beef"], cook: .beef, en: ["beef", "steak", "sirloin"]),
            g("beef_stew", "Говядина для тушения", .meat, 190, 19, 12, 0, ("Говядина", "говядину", "говядиной"), tags: ["beef", "stew"], cook: .beef, en: ["stew beef", "chuck"]),
            g("pork_tenderloin", "Свиная вырезка", .meat, 120, 21, 3.5, 0, ("Свинина", "свиную вырезку", "свининой"), tags: ["pork", "lean"], cook: .pork, en: ["pork tenderloin", "pork loin"]),
            g("pork_shoulder", "Свинина (шея, лопатка)", .meat, 200, 17, 14.5, 0, ("Свинина", "свинину", "свининой"), tags: ["pork"], cook: .pork, en: ["pork shoulder", "pork"]),
            g("ground_pork", "Свиной фарш", .meat, 263, 16.9, 21.2, 0, ("Фарш", "свиной фарш", "свиным фаршем"), tags: ["pork", "ground"], cook: .groundMeat, en: ["ground pork"]),
            g("lamb", "Баранина", .meat, 282, 16.6, 23.4, 0, ("Баранина", "баранину", "бараниной"), tags: ["lamb"], cook: .beef, en: ["lamb"]),
            g("beef_liver", "Говяжья печень", .meat, 135, 20.4, 3.6, 3.9, ("Печень", "печень", "печенью"), tags: ["liver"], cook: .liver, en: ["beef liver"]),
            g("chicken_liver", "Куриная печень", .meat, 119, 16.9, 4.8, 0.7, ("Печень", "куриную печень", "печенью"), tags: ["liver", "chicken"], cook: .liver, en: ["chicken liver"]),
            g("rotisserie_chicken", "Курица-гриль (готовая)", .meat, 190, 27, 9, 0, ("Курица-гриль", "курицу-гриль", "курицей-гриль"), tags: ["chicken", "cooked"], cook: .cookedMeat, en: ["rotisserie chicken"]),
            g("bacon", "Бекон", .sausage, 458, 11.6, 45, 1.3, ("Бекон", "бекон", "беконом"), tags: ["pork", "bacon"], cook: .bacon, en: ["bacon"])
        ]

        // Колбаса и сосиски
        a += [
            g("hot_dogs", "Сосиски", .sausage, 280, 11, 25, 2, ("Сосиски", "сосиски", "сосисками"), tags: ["pork"], piece: 45, cook: .sausage, en: ["hot dog", "sausages", "frankfurter"]),
            g("smoked_sausage", "Колбаса полукопчёная", .sausage, 330, 14, 29, 2, ("Колбаса", "колбасу", "колбасой"), tags: ["pork", "sliced"], cook: .sausage, en: ["kielbasa", "smoked sausage"]),
            g("ham", "Ветчина (нарезка)", .sausage, 120, 17, 4.5, 2, ("Ветчина", "ветчину", "ветчиной"), tags: ["pork", "sliced", "deli"], cook: .noCook, en: ["ham", "deli ham"]),
            g("turkey_deli", "Индейка (нарезка)", .sausage, 105, 17, 2, 3.5, ("Индейка", "индейку", "индейкой"), tags: ["turkey", "sliced", "deli"], cook: .noCook, en: ["turkey deli", "sliced turkey"]),
            g("chicken_sausage", "Куриные колбаски", .sausage, 170, 14, 11, 3, ("Колбаски", "колбаски", "колбасками"), tags: ["chicken"], piece: 85, cook: .sausage, en: ["chicken sausage"])
        ]

        // Рыба и морепродукты
        a += [
            g("salmon", "Лосось (сёмга)", .fish, 208, 20.4, 13.4, 0, ("Лосось", "лосось", "лососем"), tags: ["fillet", "fatty"], cook: .salmon, en: ["salmon"]),
            g("tilapia", "Тилапия", .fish, 96, 20.1, 1.7, 0, ("Тилапия", "тилапию", "тилапией"), tags: ["fillet", "white"], cook: .fishFillet, en: ["tilapia"]),
            g("cod", "Треска", .fish, 82, 17.8, 0.7, 0, ("Треска", "треску", "треской"), tags: ["fillet", "white"], cook: .fishFillet, en: ["cod"]),
            g("pollock", "Минтай", .fish, 92, 19.4, 1, 0, ("Минтай", "минтай", "минтаем"), tags: ["fillet", "white"], cook: .fishFillet, en: ["pollock"]),
            g("mackerel", "Скумбрия", .fish, 205, 18.6, 13.9, 0, ("Скумбрия", "скумбрию", "скумбрией"), tags: ["fillet", "fatty"], cook: .salmon, en: ["mackerel"]),
            g("shrimp", "Креветки", .fish, 85, 20.1, 0.5, 0, ("Креветки", "креветки", "креветками"), tags: ["shrimp"], cook: .shrimp, en: ["shrimp", "prawns"]),
            g("tuna_water", "Тунец в собственном соку (конс.)", .fish, 116, 25.5, 0.8, 0, ("Тунец", "тунец", "тунцом"), tags: ["canned"], piece: 140, cook: .cannedFish, en: ["canned tuna", "tuna"]),
            g("tuna_oil", "Тунец в масле (конс.)", .fish, 198, 29, 8.2, 0, ("Тунец", "тунец", "тунцом"), tags: ["canned"], piece: 140, cook: .cannedFish, en: ["tuna in oil"]),
            g("sardines", "Сардины в масле (конс.)", .fish, 208, 24.6, 11.5, 0, ("Сардины", "сардины", "сардинами"), tags: ["canned"], piece: 90, cook: .cannedFish, en: ["sardines"]),
            g("canned_salmon", "Лосось консервированный", .fish, 139, 23, 5, 0, ("Лосось", "лосось", "лососем"), tags: ["canned"], piece: 140, cook: .cannedFish, en: ["canned salmon"]),
            g("herring", "Сельдь слабосолёная", .fish, 217, 19.8, 15.4, 0, ("Сельдь", "сельдь", "сельдью"), tags: ["salted"], cook: .noCook, en: ["herring"]),
            g("crab_sticks", "Крабовые палочки", .fish, 95, 7.6, 0.5, 15, ("Крабовые палочки", "крабовые палочки", "крабовыми палочками"), tags: ["ready"], piece: 17, cook: .noCook, en: ["imitation crab", "crab sticks"])
        ]

        // Яйца
        a += [
            g("egg", "Яйцо куриное", .eggs, 143, 12.6, 9.5, 0.7, ("Яйца", "яйца", "яйцом"), piece: 50, cook: .egg, en: ["egg", "eggs"]),
            g("egg_white", "Яичный белок", .eggs, 52, 10.9, 0.2, 0.7, ("Белки", "яичные белки", "яичными белками"), tags: ["whites"], cook: .egg, en: ["egg whites", "liquid egg whites"])
        ]

        // Молочное
        a += [
            g("cottage_5", "Творог 5%", .cottage, 121, 17.2, 5, 1.8, ("Творог", "творог", "творогом"), cook: .noCook, en: ["farmer cheese", "tvorog"]),
            g("cottage_9", "Творог 9%", .cottage, 159, 16.7, 9, 2, ("Творог", "творог", "творогом"), cook: .noCook, en: ["tvorog 9"]),
            g("cottage_0", "Творог обезжиренный", .cottage, 71, 16.5, 0.5, 1.3, ("Творог", "творог", "творогом"), cook: .noCook, en: ["fat free farmer cheese"]),
            g("cottage_cheese_2", "Зернёный творог (cottage cheese 2%)", .cottage, 84, 11, 2.3, 4.3, ("Зернёный творог", "зернёный творог", "зернёным творогом"), tags: ["grainy"], cook: .noCook, en: ["cottage cheese"]),
            g("greek_yogurt_0", "Греческий йогурт 0%", .yogurt, 59, 10.3, 0.4, 3.6, ("Греческий йогурт", "греческий йогурт", "греческим йогуртом"), tags: ["greek"], cook: .noCook, en: ["greek yogurt", "nonfat greek yogurt"]),
            g("greek_yogurt_2", "Греческий йогурт 2%", .yogurt, 73, 10, 1.9, 3.9, ("Греческий йогурт", "греческий йогурт", "греческим йогуртом"), tags: ["greek"], cook: .noCook, en: ["greek yogurt 2"]),
            g("skyr", "Скир", .yogurt, 63, 11, 0.2, 4, ("Скир", "скир", "скиром"), tags: ["greek"], cook: .noCook, en: ["skyr", "icelandic yogurt"]),
            g("yogurt_plain", "Йогурт натуральный", .yogurt, 61, 3.5, 3.3, 4.7, ("Йогурт", "йогурт", "йогуртом"), cook: .noCook, en: ["plain yogurt", "yogurt"]),
            g("kefir_1", "Кефир 1%", .milk, 40, 3, 1, 4, ("Кефир", "кефир", "кефиром"), tags: ["kefir"], cook: .noCook, en: ["kefir lowfat"]),
            g("kefir_25", "Кефир 2,5%", .milk, 53, 2.9, 2.5, 4, ("Кефир", "кефир", "кефиром"), tags: ["kefir"], cook: .noCook, en: ["kefir"]),
            g("milk_2", "Молоко 2%", .milk, 50, 3.3, 2, 4.8, ("Молоко", "молоко", "молоком"), cook: .noCook, en: ["milk", "2% milk", "reduced fat milk"]),
            g("milk_whole", "Молоко 3,25%", .milk, 61, 3.2, 3.3, 4.8, ("Молоко", "молоко", "молоком"), cook: .noCook, en: ["whole milk"]),
            g("milk_skim", "Молоко обезжиренное", .milk, 34, 3.4, 0.1, 5, ("Молоко", "молоко", "молоком"), cook: .noCook, en: ["skim milk", "fat free milk"]),
            g("milk_25", "Молоко 2,5%", .milk, 52, 2.8, 2.5, 4.7, ("Молоко", "молоко", "молоком"), cook: .noCook, en: ["milk 2.5"]),
            g("almond_milk", "Миндальное молоко без сахара", .milk, 15, 0.6, 1.2, 0.3, ("Миндальное молоко", "миндальное молоко", "миндальным молоком"), cook: .noCook, en: ["almond milk"]),
            g("cheddar", "Сыр чеддер", .cheese, 403, 24.9, 33.1, 1.3, ("Сыр", "сыр", "сыром"), cook: .noCook, en: ["cheddar", "cheese"]),
            g("mozzarella", "Моцарелла (полужирная)", .cheese, 254, 24.3, 15.9, 2.8, ("Моцарелла", "моцареллу", "моцареллой"), cook: .noCook, en: ["mozzarella"]),
            g("hard_cheese", "Сыр твёрдый", .cheese, 360, 24, 29, 0, ("Сыр", "сыр", "сыром"), cook: .noCook, en: ["hard cheese", "gouda", "swiss cheese"]),
            g("feta", "Фета", .cheese, 264, 14.2, 21.3, 4.1, ("Фета", "фету", "фетой"), tags: ["salad"], cook: .noCook, en: ["feta"]),
            g("parmesan", "Пармезан", .cheese, 392, 35.8, 25.8, 3.2, ("Пармезан", "пармезан", "пармезаном"), cook: .noCook, en: ["parmesan"]),
            g("cream_cheese", "Сливочный сыр", .cheese, 342, 5.9, 34.2, 4.1, ("Сливочный сыр", "сливочный сыр", "сливочным сыром"), tags: ["spread"], cook: .noCook, en: ["cream cheese"]),
            g("sour_cream", "Сметана 20%", .sauce, 206, 2.8, 20, 3.2, ("Сметана", "сметану", "сметаной"), tags: ["dairy"], cook: .noCook, en: ["sour cream"])
        ]

        // Крупы (сухие)
        a += [
            g("rice_white", "Рис белый", .grain, 365, 7.1, 0.7, 80, ("Рис", "рис", "рисом"), tags: ["rice"], cook: .rice, en: ["rice", "white rice", "jasmine rice", "basmati"]),
            g("rice_brown", "Рис бурый", .grain, 370, 7.9, 2.9, 77.2, ("Бурый рис", "бурый рис", "бурым рисом"), tags: ["rice"], cook: .rice, en: ["brown rice"]),
            g("buckwheat", "Гречка", .grain, 343, 13.3, 3.4, 71.5, ("Гречка", "гречку", "гречкой"), tags: ["buckwheat"], cook: .buckwheat, en: ["buckwheat"]),
            g("quinoa", "Киноа", .grain, 368, 14.1, 6.1, 64.2, ("Киноа", "киноа", "киноа"), tags: ["quinoa"], cook: .quinoa, en: ["quinoa"]),
            g("bulgur", "Булгур", .grain, 342, 12.3, 1.3, 75.9, ("Булгур", "булгур", "булгуром"), tags: ["bulgur"], cook: .bulgur, en: ["bulgur"]),
            g("couscous", "Кускус", .grain, 376, 12.8, 0.6, 77.4, ("Кускус", "кускус", "кускусом"), tags: ["couscous"], cook: .couscous, en: ["couscous"]),
            g("millet", "Пшено", .grain, 378, 11, 4.2, 72.9, ("Пшено", "пшено", "пшеном"), tags: ["millet"], cook: .millet, en: ["millet"]),
            g("barley", "Перловка", .grain, 352, 9.9, 1.2, 77.7, ("Перловка", "перловку", "перловкой"), tags: ["barley"], cook: .barley, en: ["pearl barley", "barley"]),
            g("oats", "Овсяные хлопья", .oats, 379, 13.2, 6.5, 67.7, ("Овсянка", "овсяные хлопья", "овсянкой"), tags: ["oats"], cook: .noCook, en: ["oats", "oatmeal", "rolled oats"]),
            g("granola", "Гранола", .oats, 471, 10, 20, 64, ("Гранола", "гранолу", "гранолой"), tags: ["granola"], cook: .noCook, en: ["granola"]),
            g("corn_flakes", "Кукурузные хлопья", .oats, 357, 7.5, 0.4, 84, ("Хлопья", "хлопья", "хлопьями"), tags: ["cereal"], cook: .noCook, en: ["corn flakes", "cereal"])
        ]

        // Макароны и лапша (сухие)
        a += [
            g("pasta", "Макароны из твёрдых сортов", .pasta, 371, 13, 1.5, 74.7, ("Макароны", "макароны", "макаронами"), cook: .pasta, en: ["pasta", "spaghetti", "penne", "macaroni"]),
            g("pasta_whole", "Макароны цельнозерновые", .pasta, 348, 14.6, 1.4, 73, ("Макароны", "макароны", "макаронами"), cook: .pasta, en: ["whole wheat pasta"]),
            g("egg_noodles", "Яичная лапша", .pasta, 384, 14.2, 4.4, 71.3, ("Лапша", "лапшу", "лапшой"), tags: ["noodles"], cook: .noodles, en: ["egg noodles", "noodles"]),
            g("rice_noodles", "Рисовая лапша", .pasta, 364, 6, 0.6, 80, ("Рисовая лапша", "рисовую лапшу", "рисовой лапшой"), tags: ["noodles"], cook: .noodles, en: ["rice noodles"])
        ]

        // Хлеб и лепёшки
        a += [
            g("bread_white", "Хлеб белый", .bread, 266, 8.9, 3.3, 49, ("Хлеб", "хлеб", "хлебом"), tags: ["slice"], piece: 28, cook: .noCook, en: ["bread", "white bread"]),
            g("bread_whole", "Хлеб цельнозерновой", .bread, 252, 12.5, 3.5, 42.7, ("Хлеб", "хлеб", "хлебом"), tags: ["slice"], piece: 32, cook: .noCook, en: ["whole wheat bread", "whole grain bread"]),
            g("bread_rye", "Хлеб ржаной", .bread, 259, 8.5, 3.3, 48.3, ("Ржаной хлеб", "ржаной хлеб", "ржаным хлебом"), tags: ["slice"], piece: 30, cook: .noCook, en: ["rye bread"]),
            g("tortilla", "Тортилья пшеничная", .bread, 304, 8.2, 8, 50, ("Тортилья", "тортилью", "тортильей"), tags: ["wrap"], piece: 45, cook: .noCook, en: ["tortilla", "flour tortilla", "wrap"]),
            g("tortilla_corn", "Тортилья кукурузная", .bread, 218, 5.7, 2.9, 44.6, ("Тортилья", "тортилью", "тортильей"), tags: ["wrap", "small"], piece: 26, cook: .noCook, en: ["corn tortilla"]),
            g("lavash", "Лаваш тонкий", .bread, 277, 9, 1.5, 56, ("Лаваш", "лаваш", "лавашом"), tags: ["wrap"], cook: .noCook, en: ["lavash"]),
            g("pita", "Пита", .bread, 275, 9.1, 1.2, 55.7, ("Пита", "питу", "питой"), tags: ["pocket"], piece: 60, cook: .noCook, en: ["pita"]),
            g("bagel", "Бейгл", .bread, 250, 10, 1.5, 49, ("Бейгл", "бейгл", "бейглом"), tags: ["bun"], piece: 100, cook: .noCook, en: ["bagel"]),
            g("burger_bun", "Булочка для бургера", .bread, 279, 9.5, 4.3, 50, ("Булочка", "булочку", "булочкой"), tags: ["bun"], piece: 50, cook: .noCook, en: ["hamburger bun", "bun"]),
            g("crispbread", "Хлебцы цельнозерновые", .bread, 330, 11, 3, 62, ("Хлебцы", "хлебцы", "хлебцами"), tags: ["crisp"], piece: 10, cook: .noCook, en: ["crispbread"]),
            g("rice_cakes", "Рисовые хлебцы", .bread, 387, 8.2, 2.8, 81.5, ("Рисовые хлебцы", "рисовые хлебцы", "рисовыми хлебцами"), tags: ["crisp"], piece: 9, cook: .noCook, en: ["rice cakes"])
        ]

        // Картофель
        a += [
            g("potato", "Картофель", .potato, 77, 2, 0.1, 17.5, ("Картошка", "картофель", "картошкой"), piece: 170, cook: .potato, en: ["potato", "potatoes"]),
            g("sweet_potato", "Батат", .potato, 86, 1.6, 0.1, 20.1, ("Батат", "батат", "бататом"), piece: 200, cook: .sweetPotato, en: ["sweet potato", "yam"]),
            g("fries_frozen", "Картофель фри (заморож.)", .potato, 150, 2.4, 5, 24, ("Картофель фри", "картофель фри", "картофелем фри"), tags: ["frozen"], cook: .fries, en: ["french fries", "frozen fries"])
        ]

        // Бобовые и тофу
        a += [
            g("black_beans_can", "Фасоль чёрная (конс.)", .legumes, 91, 6, 0.3, 16.6, ("Фасоль", "фасоль", "фасолью"), tags: ["beans", "canned"], cook: .cannedLegumes, en: ["black beans"]),
            g("kidney_beans_can", "Фасоль красная (конс.)", .legumes, 84, 5.2, 0.4, 15, ("Фасоль", "фасоль", "фасолью"), tags: ["beans", "canned"], cook: .cannedLegumes, en: ["kidney beans", "red beans"]),
            g("chickpeas_can", "Нут (конс.)", .legumes, 139, 7, 2.6, 22.5, ("Нут", "нут", "нутом"), tags: ["chickpeas", "canned"], cook: .cannedLegumes, en: ["chickpeas", "garbanzo"]),
            g("lentils", "Чечевица", .legumes, 352, 24.6, 1.1, 63.4, ("Чечевица", "чечевицу", "чечевицей"), tags: ["lentils", "dry"], cook: .lentils, en: ["lentils"]),
            g("beans_dry", "Фасоль сухая", .legumes, 333, 23.6, 0.8, 60, ("Фасоль", "фасоль", "фасолью"), tags: ["beans", "dry"], cook: .dryBeans, en: ["dry beans"]),
            g("edamame", "Эдамаме (заморож.)", .legumes, 121, 11.9, 5.2, 8.9, ("Эдамаме", "эдамаме", "эдамаме"), tags: ["frozen"], cook: .frozenVeg, en: ["edamame"]),
            g("tofu", "Тофу твёрдый", .legumes, 144, 17.3, 8.7, 2.8, ("Тофу", "тофу", "тофу"), tags: ["tofu"], cook: .tofu, en: ["tofu"])
        ]

        // Овощи
        a += [
            g("tomato", "Помидоры", .vegetable, 18, 0.9, 0.2, 3.9, ("Помидоры", "помидоры", "помидорами"), tags: ["tomato", "salad"], piece: 120, cook: .freshVeg, en: ["tomato", "tomatoes"]),
            g("cherry_tomato", "Черри", .vegetable, 18, 0.9, 0.2, 3.9, ("Черри", "черри", "черри"), tags: ["tomato", "salad"], cook: .freshVeg, en: ["cherry tomatoes", "cherry tomato"]),
            g("cucumber", "Огурцы", .vegetable, 15, 0.7, 0.1, 3.6, ("Огурцы", "огурцы", "огурцами"), tags: ["salad", "raw"], piece: 150, cook: .freshVeg, en: ["cucumber"]),
            g("onion", "Лук репчатый", .vegetable, 40, 1.1, 0.1, 9.3, ("Лук", "лук", "луком"), tags: ["onion", "base"], piece: 110, cook: .freshVeg, en: ["onion", "onions"]),
            g("carrot", "Морковь", .vegetable, 41, 0.9, 0.2, 9.6, ("Морковь", "морковь", "морковью"), tags: ["carrot", "base"], piece: 70, cook: .freshVeg, en: ["carrot", "carrots"]),
            g("bell_pepper", "Перец болгарский", .vegetable, 26, 1, 0.3, 6, ("Перец", "болгарский перец", "перцем"), tags: ["pepper", "salad"], piece: 150, cook: .freshVeg, en: ["bell pepper", "pepper"]),
            g("zucchini", "Кабачок", .vegetable, 17, 1.2, 0.3, 3.1, ("Кабачок", "кабачок", "кабачком"), tags: ["stew"], piece: 200, cook: .freshVeg, en: ["zucchini", "courgette"]),
            g("eggplant", "Баклажан", .vegetable, 25, 1, 0.2, 5.9, ("Баклажан", "баклажан", "баклажаном"), tags: ["stew"], piece: 300, cook: .freshVeg, en: ["eggplant"]),
            g("broccoli", "Брокколи", .vegetable, 34, 2.8, 0.4, 6.6, ("Брокколи", "брокколи", "брокколи"), tags: ["green"], cook: .freshVeg, en: ["broccoli"]),
            g("broccoli_frozen", "Брокколи (заморож.)", .vegetable, 28, 3, 0.3, 5.3, ("Брокколи", "брокколи", "брокколи"), tags: ["green", "frozen"], cook: .frozenVeg, en: ["frozen broccoli"]),
            g("cauliflower", "Цветная капуста", .vegetable, 25, 1.9, 0.3, 5, ("Цветная капуста", "цветную капусту", "цветной капустой"), cook: .freshVeg, en: ["cauliflower"]),
            g("cabbage", "Капуста белокочанная", .vegetable, 25, 1.3, 0.1, 5.8, ("Капуста", "капусту", "капустой"), tags: ["salad", "stew"], cook: .freshVeg, en: ["cabbage"]),
            g("mushrooms", "Шампиньоны", .vegetable, 22, 3.1, 0.3, 3.3, ("Грибы", "грибы", "грибами"), tags: ["mushroom"], cook: .freshVeg, en: ["mushroom", "mushrooms"]),
            g("green_beans", "Стручковая фасоль", .vegetable, 31, 1.8, 0.2, 7, ("Стручковая фасоль", "стручковую фасоль", "стручковой фасолью"), tags: ["green"], cook: .freshVeg, en: ["green beans"]),
            g("veg_mix_frozen", "Овощная смесь (заморож.)", .vegetable, 65, 3, 0.5, 12, ("Овощи", "овощную смесь", "овощами"), tags: ["frozen", "mix"], cook: .frozenVeg, en: ["mixed vegetables", "frozen vegetables"]),
            g("stirfry_mix", "Овощи для жарки (заморож.)", .vegetable, 30, 1.6, 0.2, 6, ("Овощи", "овощи для жарки", "овощами"), tags: ["frozen", "mix"], cook: .frozenVeg, en: ["stir fry vegetables"]),
            g("peas_frozen", "Горошек зелёный (заморож.)", .vegetable, 77, 5.2, 0.4, 13.6, ("Горошек", "горошек", "горошком"), tags: ["frozen", "peas"], cook: .frozenVeg, en: ["green peas", "peas"]),
            g("corn", "Кукуруза (конс. или заморож.)", .vegetable, 82, 2.7, 1.2, 17, ("Кукуруза", "кукурузу", "кукурузой"), tags: ["corn", "salad"], cook: .cannedVeg, en: ["corn", "sweet corn"]),
            g("beet", "Свёкла", .vegetable, 43, 1.6, 0.2, 9.6, ("Свёкла", "свёклу", "свёклой"), piece: 150, cook: .freshVeg, en: ["beet", "beets"]),
            g("pumpkin", "Тыква", .vegetable, 26, 1, 0.1, 6.5, ("Тыква", "тыкву", "тыквой"), tags: ["stew"], cook: .freshVeg, en: ["pumpkin", "squash", "butternut squash"]),
            g("celery", "Сельдерей", .vegetable, 14, 0.7, 0.2, 3, ("Сельдерей", "сельдерей", "сельдереем"), tags: ["salad"], cook: .freshVeg, en: ["celery"]),
            g("radish", "Редис", .vegetable, 16, 0.7, 0.1, 3.4, ("Редис", "редис", "редисом"), tags: ["salad", "raw"], cook: .freshVeg, en: ["radish"]),
            g("avocado", "Авокадо", .vegetable, 160, 2, 14.7, 8.5, ("Авокадо", "авокадо", "авокадо"), tags: ["salad", "raw", "fatty"], piece: 150, cook: .freshVeg, en: ["avocado"]),
            g("pickles", "Огурцы маринованные", .vegetable, 12, 0.5, 0.2, 2.3, ("Маринованные огурцы", "маринованные огурцы", "маринованными огурцами"), tags: ["raw", "salad"], cook: .noCook, en: ["pickles"]),
            g("sauerkraut", "Квашеная капуста", .vegetable, 19, 0.9, 0.1, 4.3, ("Квашеная капуста", "квашеную капусту", "квашеной капустой"), tags: ["raw", "nocut"], cook: .noCook, en: ["sauerkraut"]),
            g("olives", "Оливки", .vegetable, 115, 0.8, 10.7, 6.3, ("Оливки", "оливки", "оливками"), tags: ["salad", "raw", "fatty"], cook: .noCook, en: ["olives"])
        ]

        // Зелень и салат
        a += [
            g("lettuce", "Салат листовой", .greens, 15, 1.4, 0.2, 2.9, ("Салат", "листья салата", "салатом"), tags: ["leaf"], cook: .leafy, en: ["lettuce"]),
            g("romaine", "Ромэн", .greens, 17, 1.2, 0.3, 3.3, ("Ромэн", "ромэн", "ромэном"), tags: ["leaf"], cook: .leafy, en: ["romaine"]),
            g("salad_mix", "Салатная смесь", .greens, 17, 1.4, 0.2, 3.2, ("Салат", "салатную смесь", "салатом"), tags: ["leaf"], cook: .leafy, en: ["salad mix", "spring mix", "salad"]),
            g("spinach", "Шпинат", .greens, 23, 2.9, 0.4, 3.6, ("Шпинат", "шпинат", "шпинатом"), tags: ["leaf", "cookable"], cook: .leafy, en: ["spinach"]),
            g("green_onion", "Зелёный лук", .greens, 32, 1.8, 0.2, 7.3, ("Зелёный лук", "зелёный лук", "зелёным луком"), tags: ["herb"], cook: .leafy, en: ["green onion", "scallions"]),
            g("dill", "Укроп", .greens, 43, 3.5, 1.1, 7, ("Укроп", "укроп", "укропом"), tags: ["herb"], cook: .leafy, en: ["dill"]),
            g("parsley", "Петрушка", .greens, 36, 3, 0.8, 6.3, ("Петрушка", "петрушку", "петрушкой"), tags: ["herb"], cook: .leafy, en: ["parsley"]),
            g("cilantro", "Кинза", .greens, 23, 2.1, 0.5, 3.7, ("Кинза", "кинзу", "кинзой"), tags: ["herb"], cook: .leafy, en: ["cilantro"])
        ]

        // Фрукты
        a += [
            g("banana", "Банан", .fruit, 89, 1.1, 0.3, 22.8, ("Банан", "банан", "бананом"), piece: 120, cook: .noCook, en: ["banana", "bananas"]),
            g("apple", "Яблоко", .fruit, 52, 0.3, 0.2, 13.8, ("Яблоко", "яблоко", "яблоком"), piece: 180, cook: .noCook, en: ["apple", "apples", "granny smith"]),
            g("orange", "Апельсин", .fruit, 47, 0.9, 0.1, 11.8, ("Апельсин", "апельсин", "апельсином"), piece: 150, cook: .noCook, en: ["orange", "oranges"]),
            g("mandarin", "Мандарин", .fruit, 53, 0.8, 0.3, 13.3, ("Мандарины", "мандарины", "мандаринами"), piece: 80, cook: .noCook, en: ["mandarin", "clementine", "tangerine"]),
            g("pear", "Груша", .fruit, 57, 0.4, 0.1, 15.2, ("Груша", "грушу", "грушей"), piece: 180, cook: .noCook, en: ["pear"]),
            g("grapes", "Виноград", .fruit, 69, 0.7, 0.2, 18.1, ("Виноград", "виноград", "виноградом"), cook: .noCook, en: ["grapes", "grape"]),
            g("kiwi", "Киви", .fruit, 61, 1.1, 0.5, 14.7, ("Киви", "киви", "киви"), piece: 75, cook: .noCook, en: ["kiwi"]),
            g("mango", "Манго", .fruit, 60, 0.8, 0.4, 15, ("Манго", "манго", "манго"), piece: 200, cook: .noCook, en: ["mango"]),
            g("pineapple", "Ананас", .fruit, 50, 0.5, 0.1, 13.1, ("Ананас", "ананас", "ананасом"), cook: .noCook, en: ["pineapple"]),
            g("peach", "Персик", .fruit, 39, 0.9, 0.3, 9.5, ("Персик", "персик", "персиком"), piece: 150, cook: .noCook, en: ["peach", "nectarine"]),
            g("watermelon", "Арбуз", .fruit, 30, 0.6, 0.2, 7.6, ("Арбуз", "арбуз", "арбузом"), cook: .noCook, en: ["watermelon"]),
            g("dates", "Финики", .fruit, 282, 2.5, 0.4, 75, ("Финики", "финики", "финиками"), tags: ["dried"], piece: 8, cook: .noCook, en: ["dates"]),
            g("raisins", "Изюм", .fruit, 299, 3.1, 0.5, 79, ("Изюм", "изюм", "изюмом"), tags: ["dried"], cook: .noCook, en: ["raisins"]),
            g("dried_apricots", "Курага", .fruit, 241, 3.4, 0.5, 62.6, ("Курага", "курагу", "курагой"), tags: ["dried"], cook: .noCook, en: ["dried apricots"])
        ]

        // Ягоды
        a += [
            g("strawberries", "Клубника", .berries, 32, 0.7, 0.3, 7.7, ("Клубника", "клубнику", "клубникой"), cook: .noCook, en: ["strawberry", "strawberries"]),
            g("blueberries", "Черника / голубика", .berries, 57, 0.7, 0.3, 14.5, ("Голубика", "голубику", "голубикой"), cook: .noCook, en: ["blueberries", "blueberry"]),
            g("raspberries", "Малина", .berries, 52, 1.2, 0.7, 11.9, ("Малина", "малину", "малиной"), cook: .noCook, en: ["raspberries", "raspberry"]),
            g("berries_frozen", "Ягодная смесь (заморож.)", .berries, 50, 0.8, 0.3, 12, ("Ягоды", "ягоды", "ягодами"), tags: ["frozen"], cook: .noCook, en: ["frozen berries", "mixed berries"])
        ]

        // Орехи и семечки
        a += [
            g("almonds", "Миндаль", .nuts, 579, 21.2, 49.9, 21.6, ("Миндаль", "миндаль", "миндалём"), cook: .noCook, en: ["almonds"]),
            g("walnuts", "Грецкие орехи", .nuts, 654, 15.2, 65.2, 13.7, ("Грецкие орехи", "грецкие орехи", "грецкими орехами"), cook: .noCook, en: ["walnuts"]),
            g("peanuts", "Арахис", .nuts, 567, 25.8, 49.2, 16.1, ("Арахис", "арахис", "арахисом"), cook: .noCook, en: ["peanuts"]),
            g("cashews", "Кешью", .nuts, 553, 18.2, 43.9, 30.2, ("Кешью", "кешью", "кешью"), cook: .noCook, en: ["cashews"]),
            g("peanut_butter", "Арахисовая паста", .nuts, 588, 25, 50, 20, ("Арахисовая паста", "арахисовую пасту", "арахисовой пастой"), tags: ["spread"], cook: .noCook, en: ["peanut butter"]),
            g("sunflower_seeds", "Семечки подсолнечника", .nuts, 584, 20.8, 51.5, 20, ("Семечки", "семечки", "семечками"), cook: .noCook, en: ["sunflower seeds"]),
            g("chia", "Семена чиа", .nuts, 486, 16.5, 30.7, 42.1, ("Чиа", "семена чиа", "чиа"), cook: .noCook, en: ["chia seeds", "chia"])
        ]

        // Протеин, сладкое, перекусы
        a += [
            g("whey", "Протеин сывороточный", .protein, 380, 75, 5, 8, ("Протеин", "протеин", "протеином"), cook: .noCook, en: ["whey protein", "protein powder"]),
            g("protein_bar", "Протеиновый батончик", .snack, 340, 33, 12, 37, ("Протеиновый батончик", "протеиновый батончик", "протеиновым батончиком"), tags: ["bar", "protein"], piece: 60, cook: .noCook, en: ["protein bar"]),
            g("dark_chocolate", "Тёмный шоколад", .sweet, 598, 7.8, 42.6, 45.9, ("Шоколад", "шоколад", "шоколадом"), cook: .noCook, en: ["dark chocolate", "chocolate"]),
            g("jam", "Варенье / джем", .sweet, 278, 0.4, 0.1, 68.9, ("Джем", "джем", "джемом"), tags: ["spread"], cook: .noCook, en: ["jam", "jelly"]),
            g("crackers", "Крекеры", .snack, 440, 9, 14, 70, ("Крекеры", "крекеры", "крекерами"), cook: .noCook, en: ["crackers"]),
            g("hummus", "Хумус", .snack, 166, 7.9, 9.6, 14.3, ("Хумус", "хумус", "хумусом"), tags: ["spread", "dip"], cook: .noCook, en: ["hummus"])
        ]

        // Готовая еда
        a += [
            g("pelmeni", "Пельмени (заморож.)", .ready, 275, 12, 12.4, 29, ("Пельмени", "пельмени", "пельменями"), tags: ["dumplings"], cook: .dumplings, en: ["pelmeni", "dumplings"]),
            g("vareniki", "Вареники с картошкой", .ready, 200, 5, 5, 33, ("Вареники", "вареники", "варениками"), tags: ["dumplings"], cook: .dumplings, en: ["pierogi", "vareniki"]),
            g("frozen_pizza", "Пицца (заморож.)", .ready, 260, 11, 10, 31, ("Пицца", "пиццу", "пиццей"), tags: ["oven"], cook: .readyFrozen, en: ["pizza", "frozen pizza"]),
            g("nuggets", "Куриные наггетсы (заморож.)", .ready, 296, 14.8, 19.8, 15, ("Наггетсы", "наггетсы", "наггетсами"), tags: ["oven", "chicken"], cook: .readyFrozen, en: ["chicken nuggets", "nuggets"]),
            g("frozen_meal", "Готовое блюдо (заморож.)", .ready, 140, 7, 4, 18, ("Готовое блюдо", "готовое блюдо", "готовым блюдом"), tags: ["micro"], cook: .readyFrozen, en: ["frozen meal", "frozen dinner"]),
            g("instant_noodles", "Лапша быстрого приготовления", .ready, 436, 9.5, 17.6, 60, ("Лапша", "лапшу", "лапшой"), tags: ["instant"], piece: 85, cook: .ready, en: ["instant noodles", "ramen"])
        ]

        // Соусы (всегда дома)
        a += [
            g("ketchup", "Кетчуп", .sauce, 101, 1, 0.1, 27.4, ("Кетчуп", "кетчуп", "кетчупом"), cook: .noCook, en: ["ketchup"]),
            g("mayo", "Майонез", .sauce, 680, 1, 75, 0.6, ("Майонез", "майонез", "майонезом"), tags: ["fatty"], cook: .noCook, en: ["mayonnaise", "mayo"]),
            g("mustard", "Горчица", .sauce, 60, 3.7, 3.3, 5.8, ("Горчица", "горчицу", "горчицей"), cook: .noCook, en: ["mustard"]),
            g("soy_sauce", "Соевый соус", .sauce, 53, 8.1, 0.6, 4.9, ("Соевый соус", "соевый соус", "соевым соусом"), tags: ["asian"], cook: .noCook, en: ["soy sauce"]),
            g("tomato_paste", "Томатная паста", .sauce, 82, 4.3, 0.5, 18.9, ("Томатная паста", "томатную пасту", "томатной пастой"), tags: ["tomato"], cook: .noCook, en: ["tomato paste"]),
            g("marinara", "Томатный соус", .sauce, 50, 1.5, 1.5, 8, ("Томатный соус", "томатный соус", "томатным соусом"), tags: ["tomato"], cook: .noCook, en: ["marinara", "pasta sauce", "tomato sauce"]),
            g("bbq_sauce", "Соус барбекю", .sauce, 172, 0.8, 0.6, 40.8, ("Барбекю", "соус барбекю", "соусом барбекю"), cook: .noCook, en: ["bbq sauce", "barbecue sauce"]),
            g("salsa", "Сальса", .sauce, 36, 1.5, 0.2, 6.6, ("Сальса", "сальсу", "сальсой"), tags: ["tomato"], cook: .noCook, en: ["salsa"]),
            g("hot_sauce", "Острый соус", .spice, 11, 0.5, 0.4, 1.8, ("Острый соус", "острый соус", "острым соусом"), cook: .noCook, en: ["hot sauce", "sriracha"])
        ]

        // Масла
        a += [
            g("sunflower_oil", "Подсолнечное масло", .fat, 884, 0, 100, 0, ("Масло", "подсолнечное масло", "маслом"), cook: .noCook, en: ["vegetable oil", "sunflower oil", "canola oil"]),
            g("olive_oil", "Оливковое масло", .fat, 884, 0, 100, 0, ("Оливковое масло", "оливковое масло", "оливковым маслом"), tags: ["salad"], cook: .noCook, en: ["olive oil"]),
            g("butter", "Сливочное масло", .fat, 717, 0.9, 81.1, 0.1, ("Сливочное масло", "сливочное масло", "сливочным маслом"), tags: ["dairy"], cook: .noCook, en: ["butter"])
        ]

        // Бакалея
        a += [
            g("sugar", "Сахар", .sweet, 387, 0, 0, 100, ("Сахар", "сахар", "сахаром"), tags: ["staple"], cook: .noCook, en: ["sugar"]),
            g("honey", "Мёд", .sweet, 304, 0.3, 0, 82.4, ("Мёд", "мёд", "мёдом"), cook: .noCook, en: ["honey"]),
            g("flour", "Мука пшеничная", .other, 364, 10.3, 1, 76.3, ("Мука", "муку", "мукой"), tags: ["flour"], cook: .noCook, en: ["flour", "all purpose flour"])
        ]

        // Специи (калории не считаются)
        let spices: [(String, String, String, String, String)] = [
            ("salt", "Соль", "соль", "солью", "salt"),
            ("pepper", "Перец чёрный", "чёрный перец", "перцем", "black pepper"),
            ("paprika", "Паприка", "паприку", "паприкой", "paprika"),
            ("garlic_dry", "Чеснок сушёный", "сушёный чеснок", "чесноком", "garlic powder"),
            ("onion_dry", "Лук сушёный", "сушёный лук", "сушёным луком", "onion powder"),
            ("turmeric", "Куркума", "куркуму", "куркумой", "turmeric"),
            ("oregano", "Орегано", "орегано", "орегано", "oregano"),
            ("basil", "Базилик сушёный", "базилик", "базиликом", "basil"),
            ("chicken_spice", "Приправа для курицы", "приправу для курицы", "приправой", "chicken seasoning"),
            ("bay_leaf", "Лавровый лист", "лавровый лист", "лавровым листом", "bay leaf"),
            ("italian_herbs", "Итальянские травы", "итальянские травы", "итальянскими травами", "italian seasoning"),
            ("cinnamon", "Корица", "корицу", "корицей", "cinnamon"),
            ("chili", "Перец чили", "чили", "чили", "chili flakes"),
            ("cumin", "Зира (кумин)", "зиру", "зирой", "cumin"),
            ("garlic", "Чеснок свежий", "чеснок", "чесноком", "garlic"),
            ("vinegar", "Уксус", "уксус", "уксусом", "vinegar"),
            ("lemon_juice", "Лимонный сок", "лимонный сок", "лимонным соком", "lemon juice")
        ]
        for s in spices {
            a.append(g(s.0, s.1, .spice, 0, 0, 0, 0, (s.1, s.2, s.3), cook: .noCook, en: [s.4]))
        }
        return a
    }
}
