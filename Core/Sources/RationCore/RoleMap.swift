import Foundation

/// Сопоставление категорий Open Food Facts (и слов в названии) с ролью продукта и «видом» из каталога.
/// Один источник правды: этот же JSON читает tools/build_db.py при сборке базы продуктов.
/// Правила идут от частного к общему. Сначала ищется совпадение по категориям, потом — по словам названия.
public enum RoleMap {
    public struct Rule: Codable, Sendable {
        public var role: Role
        public var kind: String?
        public var tags: [String]?
        public var words: [String]?
    }

    public static let rules: [Rule] = {
        let data = Data(json.utf8)
        return (try? JSONDecoder().decode([Rule].self, from: data)) ?? []
    }()

    /// Роль и вид продукта по категориям и названию.
    public static func classify(categories: [String], name: String) -> (Role, String?) {
        let cats = Set(categories.map { $0.lowercased() })
        for r in rules {
            if let t = r.tags, t.contains(where: { cats.contains($0) }) { return (r.role, r.kind) }
        }
        let n = " " + name.lowercased() + " "
        for r in rules {
            if let w = r.words, w.contains(where: { n.contains($0) }) { return (r.role, r.kind) }
        }
        return (.other, nil)
    }

    // BEGIN-ROLEMAP-JSON
    static let json = #"""
[
 {"role":"drink","tags":["en:juices","en:fruit-juices","en:sodas","en:carbonated-drinks","en:energy-drinks","en:waters","en:coffees","en:teas","en:alcoholic-beverages","en:sweetened-beverages"],"words":["juice","soda","lemonade","energy drink","сок "]},
 {"role":"sweet","kind":"c:dark_chocolate","tags":["en:chocolates","en:dark-chocolates","en:milk-chocolates","en:chocolate-candies"],"words":["chocolate","шоколад"]},
 {"role":"meat","kind":"c:rotisserie_chicken","tags":["en:rotisserie-chickens","en:roast-chickens"],"words":["rotisserie"]},
 {"role":"ready","kind":"c:nuggets","tags":["en:chicken-nuggets","en:breaded-chicken"],"words":["nugget"]},
 {"role":"meat","kind":"c:ground_turkey","tags":["en:ground-turkey","en:minced-turkey","en:turkey-mince"],"words":["ground turkey","фарш индейки"]},
 {"role":"meat","kind":"c:ground_chicken","tags":["en:ground-chicken","en:minced-chicken"],"words":["ground chicken","куриный фарш"]},
 {"role":"meat","kind":"c:ground_pork","tags":["en:ground-pork","en:minced-pork"],"words":["ground pork","свиной фарш"]},
 {"role":"meat","kind":"c:ground_beef_85","tags":["en:ground-beef","en:minced-beef","en:ground-meat","en:minced-meat","en:beef-mince"],"words":["ground beef","фарш"]},
 {"role":"meat","kind":"c:chicken_breast","tags":["en:chicken-breasts","en:chicken-breast-fillets","en:chicken-fillets","en:chicken-breast"],"words":["chicken breast","куриное филе","куриная грудка"]},
 {"role":"meat","kind":"c:chicken_thigh","tags":["en:chicken-thighs"],"words":["chicken thigh","бедр"]},
 {"role":"meat","kind":"c:chicken_wings","tags":["en:chicken-wings"],"words":["chicken wing","крыл"]},
 {"role":"meat","kind":"c:chicken_drumstick","tags":["en:chicken-legs","en:chicken-drumsticks"],"words":["drumstick","голен"]},
 {"role":"meat","kind":"c:turkey_breast","tags":["en:turkey-breasts","en:turkey-fillets"],"words":["turkey breast","филе индейки"]},
 {"role":"meat","kind":"c:chicken_liver","tags":["en:chicken-livers"],"words":["chicken liver","куриная печень"]},
 {"role":"meat","kind":"c:beef_liver","tags":["en:livers","en:beef-livers"],"words":["liver","печень"]},
 {"role":"sausage","kind":"c:bacon","tags":["en:bacons","en:bacon"],"words":["bacon","бекон"]},
 {"role":"sausage","kind":"c:chicken_sausage","tags":["en:chicken-sausages","en:poultry-sausages"],"words":["chicken sausage"]},
 {"role":"sausage","kind":"c:hot_dogs","tags":["en:frankfurter-sausages","en:hot-dogs","en:frankfurters","en:wieners"],"words":["hot dog","frank","wiener","сосиск"]},
 {"role":"sausage","kind":"c:turkey_deli","tags":["en:sliced-turkey","en:turkey-cold-cuts","en:turkey-breast-slices"],"words":["deli turkey","sliced turkey","turkey breast slices"]},
 {"role":"sausage","kind":"c:ham","tags":["en:hams","en:cooked-hams","en:sliced-hams"],"words":[" ham ","ветчин"]},
 {"role":"sausage","kind":"c:smoked_sausage","tags":["en:sausages","en:dry-sausages","en:salamis","en:smoked-sausages","en:cold-cuts","en:pepperoni"],"words":["salami","kielbasa","sausage","pepperoni","колбас"]},
 {"role":"meat","kind":"c:pork_shoulder","tags":["en:porks","en:pork-meat","en:pork"],"words":["pork","свинин"]},
 {"role":"meat","kind":"c:beef_lean","tags":["en:beefs","en:beef-meat","en:beef","en:steaks"],"words":["beef","steak","говядин"]},
 {"role":"meat","kind":"c:chicken_breast","tags":["en:chickens","en:chicken-meat","en:poultries","en:poultry-meat"],"words":["chicken","куриц","курин"]},
 {"role":"meat","kind":"c:turkey_breast","tags":["en:turkeys","en:turkey-meat"],"words":["turkey","индейк"]},
 {"role":"fish","kind":"c:tuna_water","tags":["en:canned-tunas","en:tunas-in-water","en:tunas","en:canned-tuna"],"words":["tuna","тунец"]},
 {"role":"fish","kind":"c:sardines","tags":["en:sardines","en:canned-sardines"],"words":["sardine","сардин"]},
 {"role":"fish","kind":"c:canned_salmon","tags":["en:canned-salmons"],"words":["canned salmon","pink salmon"]},
 {"role":"fish","kind":"c:salmon","tags":["en:salmons","en:salmon-fillets","en:smoked-salmons"],"words":["salmon","лосос","сёмг","семг"]},
 {"role":"fish","kind":"c:shrimp","tags":["en:shrimps","en:prawns"],"words":["shrimp","prawn","кревет"]},
 {"role":"fish","kind":"c:tilapia","tags":["en:tilapias"],"words":["tilapia"]},
 {"role":"fish","kind":"c:crab_sticks","tags":["en:surimi","en:crab-sticks"],"words":["imitation crab","краб"]},
 {"role":"fish","kind":"c:herring","tags":["en:herrings"],"words":["herring","сельд"]},
 {"role":"fish","kind":"c:cod","tags":["en:cods","en:pollocks","en:white-fish","en:haddocks"],"words":["cod","pollock","haddock","треск","минтай"]},
 {"role":"eggs","kind":"c:egg_white","tags":["en:egg-whites","en:liquid-egg-whites"],"words":["egg white"]},
 {"role":"eggs","kind":"c:egg","tags":["en:eggs","en:chicken-eggs","en:free-range-chicken-eggs"],"words":["large eggs"," eggs","яйц"]},
 {"role":"cottage","kind":"c:cottage_cheese_2","tags":["en:cottage-cheeses"],"words":["cottage cheese"]},
 {"role":"cottage","kind":"c:cottage_5","tags":["en:quark","en:fromage-frais","en:tvorog","en:curds","en:farmer-cheeses"],"words":["творог","farmer cheese","tvorog","quark"]},
 {"role":"yogurt","kind":"c:skyr","tags":["en:skyrs","en:skyr"],"words":["skyr"]},
 {"role":"yogurt","kind":"c:greek_yogurt_0","tags":["en:greek-style-yogurts","en:greek-yogurts"],"words":["greek"]},
 {"role":"milk","kind":"c:kefir_25","tags":["en:kefirs","en:kefir"],"words":["kefir","кефир"]},
 {"role":"yogurt","kind":"c:yogurt_plain","tags":["en:yogurts","en:plain-yogurts","en:fermented-milk-products"],"words":["yogurt","yoghurt","йогурт"]},
 {"role":"milk","kind":"c:almond_milk","tags":["en:almond-milks","en:plant-based-milks","en:oat-milks","en:soy-milks"],"words":["almond milk","oat milk","soy milk","oatmilk"]},
 {"role":"sauce","kind":"c:sour_cream","tags":["en:sour-creams","en:smetana"],"words":["sour cream","сметан"]},
 {"role":"milk","kind":"c:milk_2","tags":["en:milks","en:semi-skimmed-milks","en:whole-milks","en:skimmed-milks","en:cow-milks"],"words":[" milk","молоко"]},
 {"role":"nuts","kind":"c:peanut_butter","tags":["en:peanut-butters","en:nut-butters","en:almond-butters"],"words":["peanut butter","арахисовая паста"]},
 {"role":"cheese","kind":"c:cream_cheese","tags":["en:cream-cheeses","en:spreadable-cheeses"],"words":["cream cheese"]},
 {"role":"cheese","kind":"c:mozzarella","tags":["en:mozzarella","en:mozzarellas","en:string-cheeses"],"words":["mozzarella","моцарел"]},
 {"role":"cheese","kind":"c:feta","tags":["en:feta","en:fetas"],"words":["feta","фета"]},
 {"role":"cheese","kind":"c:parmesan","tags":["en:parmigiano-reggiano","en:parmesan","en:grana-padano"],"words":["parmesan","пармезан"]},
 {"role":"cheese","kind":"c:cheddar","tags":["en:cheddar","en:cheddars"],"words":["cheddar","чеддер"]},
 {"role":"cheese","kind":"c:hard_cheese","tags":["en:cheeses","en:hard-cheeses","en:sliced-cheeses"],"words":["cheese","сыр"]},
 {"role":"fat","kind":"c:butter","tags":["en:butters","en:salted-butters","en:unsalted-butters"],"words":["butter","сливочное масло"]},
 {"role":"fat","kind":"c:olive_oil","tags":["en:olive-oils","en:extra-virgin-olive-oils"],"words":["olive oil","оливковое масло"]},
 {"role":"fat","kind":"c:sunflower_oil","tags":["en:vegetable-oils","en:sunflower-oils","en:canola-oils","en:oils","en:vegetable-fats"],"words":["canola oil","vegetable oil","подсолнечное масло"]},
 {"role":"bread","kind":"c:rice_cakes","tags":["en:rice-cakes","en:puffed-rice-cakes"],"words":["rice cake"]},
 {"role":"grain","kind":"c:buckwheat","tags":["en:buckwheat","en:buckwheat-groats","en:buckwheats"],"words":["buckwheat","гречк","гречнев"]},
 {"role":"grain","kind":"c:quinoa","tags":["en:quinoa","en:quinoas"],"words":["quinoa","киноа"]},
 {"role":"grain","kind":"c:bulgur","tags":["en:bulgur","en:bulgurs"],"words":["bulgur","булгур"]},
 {"role":"grain","kind":"c:couscous","tags":["en:couscous"],"words":["couscous","кускус"]},
 {"role":"grain","kind":"c:millet","tags":["en:millets"],"words":["millet","пшено"]},
 {"role":"grain","kind":"c:barley","tags":["en:pearl-barley","en:barleys"],"words":["barley","перлов"]},
 {"role":"grain","kind":"c:rice_brown","tags":["en:brown-rices","en:wholegrain-rices"],"words":["brown rice"]},
 {"role":"pasta","kind":"c:rice_noodles","tags":["en:rice-noodles"],"words":["rice noodle","rice vermicelli"]},
 {"role":"grain","kind":"c:rice_white","tags":["en:rices","en:long-grain-rices","en:basmati-rices","en:jasmine-rices","en:white-rices","en:rice"],"words":[" rice","рис "]},
 {"role":"oats","kind":"c:granola","tags":["en:granolas","en:mueslis","en:crunchy-cereals"],"words":["granola","muesli","мюсли"]},
 {"role":"oats","kind":"c:oats","tags":["en:oat-flakes","en:rolled-oats","en:oatmeals","en:porridge-oats","en:oats","en:instant-oatmeals"],"words":["oats","oatmeal","овсян","геркулес"]},
 {"role":"oats","kind":"c:corn_flakes","tags":["en:breakfast-cereals","en:cereal-flakes","en:corn-flakes"],"words":["cereal","flakes","хлопья"]},
 {"role":"ready","kind":"c:instant_noodles","tags":["en:instant-noodles","en:ramen"],"words":["ramen","instant noodle","cup noodle","доширак"]},
 {"role":"pasta","kind":"c:egg_noodles","tags":["en:noodles","en:egg-noodles","en:udon","en:soba"],"words":["noodle","лапша"]},
 {"role":"pasta","kind":"c:pasta","tags":["en:pastas","en:dry-pastas","en:spaghetti","en:penne","en:macaroni","en:durum-wheat-pasta","en:fusilli"],"words":["pasta","spaghetti","penne","macaroni","rotini","linguine","fettuccine","макарон","спагетти"]},
 {"role":"bread","kind":"c:tortilla","tags":["en:tortillas","en:wraps","en:flour-tortillas","en:wheat-tortillas"],"words":["tortilla","wrap","тортиль"]},
 {"role":"bread","kind":"c:tortilla_corn","tags":["en:corn-tortillas"],"words":["corn tortilla"]},
 {"role":"bread","kind":"c:lavash","tags":["en:lavash"],"words":["lavash","лаваш"]},
 {"role":"bread","kind":"c:pita","tags":["en:pitas","en:pita-breads","en:flatbreads","en:naans"],"words":["pita","naan","flatbread","пита"]},
 {"role":"bread","kind":"c:bagel","tags":["en:bagels"],"words":["bagel"]},
 {"role":"bread","kind":"c:burger_bun","tags":["en:burger-buns","en:buns","en:hot-dog-buns"],"words":[" bun","булоч"]},
 {"role":"bread","kind":"c:crispbread","tags":["en:crispbreads","en:rusks","en:crispbread"],"words":["crispbread","хлебц"]},
 {"role":"bread","kind":"c:bread_whole","tags":["en:wholemeal-breads","en:whole-wheat-breads","en:whole-grain-breads","en:multigrain-breads"],"words":["whole wheat bread","whole grain bread","multigrain"]},
 {"role":"bread","kind":"c:bread_rye","tags":["en:rye-breads","en:pumpernickel"],"words":["rye","ржан","бородинск"]},
 {"role":"bread","kind":"c:bread_white","tags":["en:breads","en:sliced-breads","en:white-breads","en:sandwich-breads","en:toasts"],"words":["bread","хлеб","батон"]},
 {"role":"snack","tags":["en:chips-and-fries","en:crisps","en:potato-crisps","en:chips","en:tortilla-chips","en:popcorn","en:pretzels"],"words":["chips","crisps","popcorn","pretzel","чипс"]},
 {"role":"potato","kind":"c:fries_frozen","tags":["en:french-fries","en:frozen-fries","en:fries","en:hash-browns"],"words":["fries","hash brown"]},
 {"role":"ready","kind":"c:pelmeni","tags":["en:pelmeni","en:meat-dumplings","en:dumplings","en:potstickers"],"words":["pelmeni","пельмен","dumpling","potsticker"]},
 {"role":"ready","kind":"c:vareniki","tags":["en:pierogi","en:vareniki"],"words":["pierogi","вареник"]},
 {"role":"ready","kind":"c:frozen_pizza","tags":["en:pizzas","en:frozen-pizzas"],"words":["pizza","пицц"]},
 {"role":"ready","kind":"c:frozen_meal","tags":["en:meals","en:frozen-ready-made-meals","en:microwave-meals","en:prepared-meals","en:ready-meals","en:frozen-meals","en:burritos","en:sandwiches","en:soups"],"words":["burrito","frozen meal","bowl ","entree"]},
 {"role":"potato","kind":"c:sweet_potato","tags":["en:sweet-potatoes"],"words":["sweet potato","батат"]},
 {"role":"potato","kind":"c:potato","tags":["en:potatoes","en:fresh-potatoes"],"words":["potato","картоф","картош"]},
 {"role":"snack","kind":"c:hummus","tags":["en:hummus","en:hummuses"],"words":["hummus","хумус"]},
 {"role":"vegetable","kind":"c:green_beans","tags":["en:green-beans"],"words":["green beans","стручков"]},
 {"role":"legumes","kind":"c:chickpeas_can","tags":["en:chickpeas","en:canned-chickpeas"],"words":["chickpea","garbanzo","нут"]},
 {"role":"legumes","kind":"c:black_beans_can","tags":["en:black-beans","en:canned-black-beans"],"words":["black bean"]},
 {"role":"legumes","kind":"c:lentils","tags":["en:lentils"],"words":["lentil","чечевиц"]},
 {"role":"legumes","kind":"c:tofu","tags":["en:tofu","en:tofus"],"words":["tofu","тофу"]},
 {"role":"legumes","kind":"c:edamame","tags":["en:edamame","en:soybeans"],"words":["edamame"]},
 {"role":"legumes","kind":"c:kidney_beans_can","tags":["en:kidney-beans","en:red-beans","en:canned-beans","en:beans","en:pinto-beans","en:refried-beans","en:baked-beans"],"words":["beans","фасол"]},
 {"role":"sauce","kind":"c:ketchup","tags":["en:ketchup","en:tomato-ketchup"],"words":["ketchup","кетчуп"]},
 {"role":"sauce","kind":"c:mayo","tags":["en:mayonnaises","en:mayonnaise"],"words":["mayo","майонез"]},
 {"role":"sauce","kind":"c:mustard","tags":["en:mustards"],"words":["mustard","горчиц"]},
 {"role":"sauce","kind":"c:soy_sauce","tags":["en:soy-sauces"],"words":["soy sauce","соевый соус"]},
 {"role":"sauce","kind":"c:salsa","tags":["en:salsa","en:salsas"],"words":["salsa","сальса"]},
 {"role":"sauce","kind":"c:bbq_sauce","tags":["en:barbecue-sauces"],"words":["bbq","barbecue","барбекю"]},
 {"role":"sauce","kind":"c:tomato_paste","tags":["en:tomato-pastes","en:tomato-concentrates"],"words":["tomato paste","томатная паста"]},
 {"role":"sauce","kind":"c:marinara","tags":["en:tomato-sauces","en:pasta-sauces","en:pizza-sauces"],"words":["marinara","pasta sauce","alfredo"]},
 {"role":"vegetable","kind":"c:veg_mix_frozen","tags":["en:frozen-vegetables","en:mixed-vegetables","en:vegetable-mixes","en:frozen-mixed-vegetables"],"words":["mixed vegetables","vegetable blend","овощная смесь"]},
 {"role":"vegetable","kind":"c:broccoli_frozen","tags":["en:broccoli","en:frozen-broccoli","en:broccolis"],"words":["broccoli","брокколи"]},
 {"role":"vegetable","kind":"c:peas_frozen","tags":["en:peas","en:green-peas","en:garden-peas"],"words":[" peas","горош"]},
 {"role":"vegetable","kind":"c:corn","tags":["en:sweet-corn","en:corn","en:canned-corn","en:sweet-corns"],"words":[" corn","кукуруз"]},
 {"role":"vegetable","kind":"c:tomato","tags":["en:tomatoes","en:canned-tomatoes","en:diced-tomatoes","en:crushed-tomatoes"],"words":["tomato","помидор","томат"]},
 {"role":"vegetable","kind":"c:pickles","tags":["en:pickles","en:pickled-cucumbers","en:gherkins"],"words":["pickle","маринован"]},
 {"role":"vegetable","kind":"c:sauerkraut","tags":["en:sauerkrauts","en:sauerkraut"],"words":["sauerkraut","квашен"]},
 {"role":"vegetable","kind":"c:olives","tags":["en:olives","en:green-olives","en:black-olives"],"words":["olive","маслин","оливк"]},
 {"role":"vegetable","kind":"c:mushrooms","tags":["en:mushrooms","en:champignons"],"words":["mushroom","гриб","шампиньон"]},
 {"role":"vegetable","kind":"c:avocado","tags":["en:avocados","en:guacamole"],"words":["avocado","guacamole","авокадо"]},
 {"role":"greens","kind":"c:spinach","tags":["en:spinachs","en:spinach","en:baby-spinach"],"words":["spinach","шпинат"]},
 {"role":"greens","kind":"c:salad_mix","tags":["en:salads","en:lettuces","en:leaf-salads","en:salad-mixes"],"words":["salad","lettuce","romaine","салат"]},
 {"role":"berries","kind":"c:berries_frozen","tags":["en:berries","en:frozen-berries","en:blueberries","en:strawberries","en:raspberries","en:frozen-fruits"],"words":["berries","blueberr","strawberr","raspberr","ягод"]},
 {"role":"fruit","kind":"c:raisins","tags":["en:raisins","en:sultanas"],"words":["raisin","изюм"]},
 {"role":"fruit","kind":"c:dates","tags":["en:dates","en:dried-dates"],"words":["dates","финик"]},
 {"role":"fruit","kind":"c:dried_apricots","tags":["en:dried-apricots","en:dried-fruits"],"words":["dried","курага","сухофрукт"]},
 {"role":"fruit","kind":"c:banana","tags":["en:bananas"],"words":["banana","банан"]},
 {"role":"fruit","kind":"c:apple","tags":["en:apples","en:applesauces","en:apple-compotes"],"words":["apple","яблок"]},
 {"role":"nuts","kind":"c:almonds","tags":["en:almonds"],"words":["almond","миндал"]},
 {"role":"nuts","kind":"c:peanuts","tags":["en:peanuts","en:roasted-peanuts"],"words":["peanut","арахис"]},
 {"role":"nuts","kind":"c:walnuts","tags":["en:walnuts"],"words":["walnut","грецк"]},
 {"role":"nuts","kind":"c:cashews","tags":["en:cashew-nuts","en:cashews"],"words":["cashew","кешью"]},
 {"role":"nuts","kind":"c:chia","tags":["en:chia-seeds"],"words":["chia","чиа"]},
 {"role":"nuts","kind":"c:sunflower_seeds","tags":["en:seeds","en:sunflower-seeds","en:pumpkin-seeds"],"words":["seeds","семечк","семена"]},
 {"role":"protein","kind":"c:whey","tags":["en:protein-powders","en:whey-proteins","en:whey-protein-isolates","en:dietary-supplements","en:bodybuilding-supplements"],"words":["whey","protein powder","isolate","протеин"]},
 {"role":"snack","kind":"c:protein_bar","tags":["en:protein-bars"],"words":["protein bar"]},
 {"role":"snack","kind":"c:crackers","tags":["en:crackers","en:salty-snacks","en:appetizers"],"words":["cracker","крекер"]},
 {"role":"sweet","kind":"c:honey","tags":["en:honeys","en:honey"],"words":["honey","мёд","мед "]},
 {"role":"sweet","kind":"c:jam","tags":["en:jams","en:fruit-preserves","en:marmalades","en:jellies"],"words":["jam","jelly","preserves","варенье","джем"]},
 {"role":"sweet","kind":"c:sugar","tags":["en:sugars","en:white-sugars","en:cane-sugars"],"words":["sugar","сахар"]},
 {"role":"other","kind":"c:flour","tags":["en:flours","en:wheat-flours"],"words":["flour","мука"]},
 {"role":"meat","tags":["en:meats","en:fresh-meats","en:meat-preparations"]},
 {"role":"fish","tags":["en:fishes","en:fish-fillets","en:seafood","en:canned-fishes","en:frozen-fishes"],"words":["fish","рыб"]},
 {"role":"vegetable","kind":"c:veg_mix_frozen","tags":["en:vegetables","en:fresh-vegetables","en:canned-vegetables"]},
 {"role":"fruit","tags":["en:fruits","en:fresh-fruits","en:canned-fruits","en:fruit-cups"],"words":["fruit","фрукт"]},
 {"role":"nuts","kind":"c:almonds","tags":["en:nuts","en:mixed-nuts","en:nuts-and-their-products","en:trail-mixes"],"words":["nuts","trail mix","орех"]},
 {"role":"snack","tags":["en:snacks","en:sweet-snacks","en:biscuits-and-cakes","en:biscuits","en:cookies","en:cakes","en:bars","en:cereal-bars","en:confectioneries","en:candies","en:ice-creams","en:frozen-desserts","en:desserts","en:pastries","en:donuts","en:muffins"],"words":["cookie","cake","bar ","candy","ice cream","печенье","торт","конфет"]},
 {"role":"sauce","tags":["en:sauces","en:condiments","en:salad-dressings","en:dressings","en:dips","en:hot-sauces","en:spreads"],"words":["dressing","sauce","dip","соус"]},
 {"role":"drink","tags":["en:beverages","en:drinks","en:plant-based-beverages"]}
]
"""#
    // END-ROLEMAP-JSON
}
