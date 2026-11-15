#!/usr/bin/env python3
"""Собирает базу продуктов foods.sqlite из выгрузки Open Food Facts (CSV, разделитель — табуляция)
и, если дан, из архива USDA FoodData Central Branded Foods (CSV в zip).

    python3 tools/build_db.py off.csv.gz data/foods.sqlite [--usda branded_food_csv.zip]
    python3 tools/build_db.py --selftest

Роли и «виды» продуктов берутся из Core/Sources/RationCore/RoleMap.swift — тот же JSON, что в приложении.
Данные Open Food Facts распространяются по лицензии Open Database License (ODbL),
USDA FoodData Central — общественное достояние (CC0).
"""
import argparse
import csv
import gzip
import io
import json
import os
import re
import sqlite3
import sys
import tempfile
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROLEMAP = os.path.join(ROOT, "Core", "Sources", "RationCore", "RoleMap.swift")

PRIORITY = {
    "en:united-states": 0,
    "en:canada": 1,
    "en:russia": 2, "en:ukraine": 2, "en:belarus": 2, "en:kazakhstan": 2, "en:poland": 2,
    "en:lithuania": 2, "en:latvia": 2, "en:estonia": 2, "en:moldova": 2, "en:georgia": 2,
    "en:armenia": 2, "en:uzbekistan": 2, "en:mexico": 2,
}


def load_rules(path=ROLEMAP):
    s = open(path, encoding="utf-8").read()
    body = s[s.index('#"""') + 4: s.index('"""#')]
    return json.loads(body)


class Classifier:
    """Повторяет RoleMap.classify из Swift: сначала категории (самое раннее правило), потом слова в названии."""

    def __init__(self, rules):
        self.rules = rules
        self.tag_index = {}
        for i, r in enumerate(rules):
            for t in r.get("tags") or []:
                self.tag_index.setdefault(t, i)
        self.words = [(i, r["words"]) for i, r in enumerate(rules) if r.get("words")]

    def classify(self, cats, name):
        best = None
        for c in cats:
            i = self.tag_index.get(c)
            if i is not None and (best is None or i < best):
                best = i
        if best is None:
            n = " " + name.lower() + " "
            for i, ws in self.words:
                if any(w in n for w in ws):
                    best = i
                    break
        if best is None:
            return "other", None
        r = self.rules[best]
        return r["role"], r.get("kind")


def num(v):
    if v is None:
        return None
    v = v.strip()
    if not v:
        return None
    try:
        x = float(v)
    except ValueError:
        return None
    if x != x or x < 0:
        return None
    return x


def sane(role, kind, kcal, p):
    """Поправка роли по КБЖУ: сухое молоко или протеин в порошке не должны стать «молоком»."""
    if role == "milk" and kcal > 150:
        return ("protein", "c:whey") if p > 40 else ("other", None)
    if role in ("yogurt", "cottage") and kcal > 260:
        return ("snack", None)
    return role, kind


SPACE = re.compile(r"\s+")
CODE = re.compile(r"^\d{6,14}$")


def clean(s, limit):
    s = SPACE.sub(" ", (s or "").replace("\\n", " ")).strip(" ,;-")
    return s[:limit]


def rows_from(path):
    opener = gzip.open if path.endswith(".gz") else open
    raw = opener(path, "rb")
    text = io.TextIOWrapper(raw, encoding="utf-8", errors="replace", newline="")
    csv.field_size_limit(sys.maxsize)
    return csv.reader(text, delimiter="\t", quoting=csv.QUOTE_NONE)


# ---------- USDA FoodData Central, Branded Foods ----------

# Категория USDA (branded_food_category) → категория Open Food Facts, по которой RoleMap даст роль.
# Ищется первое вхождение подстроки. None — роль решают слова в названии; OTHER — продукт без роли.
OTHER = "other"
USDA_CATS = [
    ("baby", OTHER), ("infant", OTHER), ("pet food", OTHER), ("vitamin", OTHER), ("supplement", OTHER),
    ("herbs & spices", OTHER), ("seasoning", OTHER), ("baking", OTHER), ("extract", OTHER), ("syrup", OTHER),
    ("energy, protein", "en:beverages"), ("protein & muscle", "en:beverages"), ("plant based milk", "en:plant-based-milks"),
    ("soda", "en:beverages"), ("water", "en:beverages"), ("juice", "en:beverages"), ("coffee", "en:beverages"),
    ("tea ", "en:beverages"), ("drink", "en:beverages"), ("beverage", "en:beverages"), ("alcohol", "en:beverages"),
    ("beer", "en:beverages"), ("wine", "en:beverages"),
    ("ice cream", "en:ice-creams"), ("frozen yogurt", "en:ice-creams"), ("frozen dessert", "en:frozen-desserts"),
    ("ketchup", "en:sauces"), ("dressing", "en:sauces"), ("mayonnaise", "en:sauces"), ("dips", "en:sauces"),
    ("salsa", "en:sauces"), ("gravy", "en:sauces"), ("marinade", "en:sauces"), ("sauce", "en:sauces"),
    ("nut & seed butter", "en:nut-butters"), ("peanut butter", "en:nut-butters"),
    ("butter & spread", "en:butters"), ("margarine", "en:butters"), ("oil", "en:vegetable-oils"),
    ("yogurt", "en:yogurts"), ("cheese", "en:cheeses"), ("egg", "en:eggs"), ("milk", "en:milks"), ("cream", None),
    ("pasta dinner", "en:meals"), ("flavored rice", "en:meals"), ("rice dish", "en:meals"),
    ("frozen dinner", "en:meals"), ("entree", "en:meals"), ("prepared", "en:meals"), ("meals", "en:meals"),
    ("deli salad", "en:meals"), ("lunch snack", "en:meals"), ("appetizer", "en:meals"), ("pizza", "en:pizzas"),
    ("soup", "en:soups"), ("sandwich", "en:sandwiches"),
    ("bacon", "en:sausages"), ("sausage", "en:sausages"), ("hotdog", "en:sausages"), ("pepperoni", "en:cold-cuts"),
    ("salami", "en:cold-cuts"), ("cold cut", "en:cold-cuts"), ("patties", "en:ground-beef"), ("burger", "en:ground-beef"),
    ("poultry", "en:chickens"), ("chicken", "en:chickens"), ("turkey", "en:turkeys"), ("beef", "en:beefs"),
    ("pork", "en:porks"), ("meat", "en:meats"),
    ("tuna", "en:tunas"), ("seafood", "en:seafood"), ("fish", "en:fishes"),
    ("pasta", "en:pastas"), ("noodle", "en:noodles"), ("rice", "en:rices"), ("grain", None),
    ("tortilla", "en:tortillas"), ("bagel", "en:bagels"), ("bun", "en:buns"), ("roll", "en:buns"), ("bread", "en:breads"),
    ("cracker", "en:crackers"), ("bars", "en:bars"), ("oatmeal", "en:oats"), ("hot cereal", "en:oats"),
    ("granola", "en:granolas"), ("cereal", "en:breakfast-cereals"),
    ("chips", "en:chips"), ("pretzel", "en:pretzels"), ("popcorn", None), ("trail mix", "en:trail-mixes"),
    ("nuts", "en:nuts"), ("seeds", "en:seeds"),
    ("cookie", "en:cookies"), ("biscuit", "en:biscuits"), ("cake", "en:cakes"), ("pastr", "en:pastries"),
    ("donut", "en:donuts"), ("muffin", "en:muffins"), ("candy", "en:candies"), ("chocolate", "en:chocolates"),
    ("pudding", "en:desserts"), ("dessert", "en:desserts"), ("gelatin", "en:desserts"),
    ("jam", "en:jams"), ("jelly", "en:jams"), ("honey", "en:honeys"), ("sugar", "en:sugars"), ("flour", "en:flours"),
    ("frozen vegetable", "en:frozen-vegetables"), ("canned vegetable", "en:canned-vegetables"), ("pickle", "en:pickles"),
    ("bean", "en:beans"), ("canned fruit", "en:canned-fruits"), ("fruit & vegetable", None), ("vegetable", "en:vegetables"),
    ("fruit", "en:fruits"), ("snack", "en:snacks"),
]

# Роли, которые не спорят друг с другом: категория говорит «мясо», а слова уточняют — «куриная колбаса».
FAMILY = {"meat": "meat", "sausage": "meat", "yogurt": "dairy", "milk": "dairy", "cottage": "dairy", "cheese": "dairy",
          "snack": "snack", "sweet": "snack"}

NUTRIENTS = {"1008": "kcal", "2047": "kcal2", "2048": "kcal3", "1062": "kj", "1003": "p", "1004": "f", "1005": "c"}
SMALL = {"and", "or", "with", "of", "in", "on", "a", "an", "the", "for", "to", "de", "la", "n", "w/"}
ACRONYMS = {"bbq": "BBQ", "usda": "USDA", "xl": "XL", "ii": "II", "iii": "III", "pb": "PB", "pb&j": "PB&J", "tv": "TV"}


def nice(s, limit):
    """USDA пишет названия КАПСОМ — делаем «Original Greek Yogurt»."""
    s = clean(s, limit)
    letters = [ch for ch in s if ch.isalpha()]
    if not letters or sum(ch.isupper() for ch in letters) < 0.8 * len(letters):
        return s
    out = []
    for i, w in enumerate(s.lower().split(" ")):
        if w in ACRONYMS:
            out.append(ACRONYMS[w])
        elif i > 0 and w in SMALL:
            out.append(w)
        else:
            out.append(re.sub(r"(^|[-/(&+])([a-zà-ÿ])", lambda m: m.group(1) + m.group(2).upper(), w))
    return " ".join(out)


def usda_category(cat):
    c = (cat or "").lower()
    for sub, tag in USDA_CATS:
        if sub in c:
            return True, tag
    return False, None


def usda_code(gtin):
    code = re.sub(r"\D", "", gtin or "")
    if not CODE.match(code):
        return None
    if len(code) == 14 and code.startswith("0"):
        code = code[1:]
    if len(code) <= 13:
        code = code.zfill(13)
    return code


def open_member(z, base):
    names = [n for n in z.namelist() if n.rsplit("/", 1)[-1].lower() == base]
    if not names:
        raise KeyError(base)
    raw = z.open(names[0])
    return csv.reader(io.TextIOWrapper(raw, encoding="utf-8", errors="replace", newline=""))


def add_usda(best, path, clf, log=print):
    """Добавляет в best продукты USDA, которых нет в Open Food Facts. Возвращает число добавленных."""
    t0 = time.time()
    csv.field_size_limit(sys.maxsize)
    z = zipfile.ZipFile(path)

    # 1) branded_food.csv: штрихкод, бренд, категория, порция. Для одного штрихкода — самая свежая запись.
    reader = open_member(z, "branded_food.csv")
    header = next(reader)
    col = {n: i for i, n in enumerate(header)}
    need = [col[k] for k in ("fdc_id", "gtin_upc")]
    g = lambda row, k: row[col[k]] if k in col and col[k] < len(row) else ""
    picked = {}
    total = 0
    for row in reader:
        total += 1
        if len(row) <= max(need):
            continue
        code = usda_code(g(row, "gtin_upc"))
        if code is None or code in best:
            continue
        try:
            fdc = int(g(row, "fdc_id"))
        except ValueError:
            continue
        date = g(row, "available_date") or g(row, "modified_date") or g(row, "publication_date")
        prev = picked.get(code)
        if prev is not None and (prev[1], prev[0]) >= (date, fdc):
            continue
        unit = g(row, "serving_size_unit").strip().lower()
        serving = num(g(row, "serving_size")) if unit in ("g", "grm", "gm", "ml", "mlt") else None
        if serving is not None and (serving <= 0 or serving > 2000):
            serving = None
        brand = g(row, "brand_name").strip() or g(row, "brand_owner").strip()
        picked[code] = (fdc, date, nice(brand.split(",")[0], 40), g(row, "branded_food_category").strip(),
                        serving, clean(g(row, "package_weight"), 24))
    log(f"USDA: записей {total:,}, новых штрихкодов {len(picked):,} ({time.time() - t0:.0f} с)")
    by_fdc = {v[0]: code for code, v in picked.items()}

    # 2) food.csv: названия.
    names = {}
    reader = open_member(z, "food.csv")
    header = next(reader)
    i_id, i_desc = header.index("fdc_id"), header.index("description")
    for row in reader:
        if len(row) > max(i_id, i_desc):
            try:
                fdc = int(row[i_id])
            except ValueError:
                continue
            if fdc in by_fdc:
                names[fdc] = row[i_desc]

    # 3) food_nutrient.csv: ккал и БЖУ на 100 г.
    nut = {}
    reader = open_member(z, "food_nutrient.csv")
    header = next(reader)
    i_id, i_n, i_a = header.index("fdc_id"), header.index("nutrient_id"), header.index("amount")
    m = max(i_id, i_n, i_a)
    rows = 0
    for row in reader:
        rows += 1
        if len(row) <= m:
            continue
        key = NUTRIENTS.get(row[i_n])
        if key is None:
            continue
        try:
            fdc = int(row[i_id])
        except ValueError:
            continue
        if fdc not in by_fdc:
            continue
        a = num(row[i_a])
        if a is not None:
            nut.setdefault(fdc, {})[key] = a
    log(f"USDA: строк нутриентов {rows:,} ({time.time() - t0:.0f} с)")

    added = 0
    for fdc, code in by_fdc.items():
        n = nut.get(fdc)
        name = nice(names.get(fdc, ""), 90)
        if not n or len(name) < 2 or name.isdigit():
            continue
        p, f, c = n.get("p"), n.get("f"), n.get("c")
        if p is None or f is None or c is None:
            continue
        kcal = n.get("kcal") or n.get("kcal2") or n.get("kcal3")
        if kcal is None and n.get("kj") is not None:
            kcal = n["kj"] / 4.184
        calc = p * 4 + f * 9 + c * 4
        if kcal is None:
            kcal = calc
        if kcal > 950 or p > 100 or f > 100 or c > 100 or p + f + c > 105:
            continue
        if abs(calc - kcal) > max(60, 0.35 * kcal) and not (kcal < 15 and calc < 25):
            continue
        _, _, brand, cat, serving, qty = picked[code]
        known, tag = usda_category(cat)
        w_role, w_kind = clf.classify([], name)
        if not known or tag is None:
            role, kind = w_role, w_kind
        elif tag == OTHER:
            role, kind = "other", None
        else:
            c_role, c_kind = clf.classify([tag], "")
            same = w_role == c_role or (FAMILY.get(w_role) and FAMILY.get(w_role) == FAMILY.get(c_role))
            role, kind = (w_role, w_kind) if same else (c_role, c_kind)
        role, kind = sane(role, kind, kcal, p)
        best[code] = (code, name, brand, qty, round(kcal, 1), round(p, 1), round(f, 1), round(c, 1),
                      serving, role, kind, 5)
        added += 1
    log(f"USDA: добавлено {added:,} продуктов ({time.time() - t0:.0f} с)")
    return added


def build(src, out, log=print, usda=None):
    t0 = time.time()
    rules = load_rules()
    clf = Classifier(rules)
    reader = rows_from(src)
    header = next(reader)
    col = {name: i for i, name in enumerate(header)}

    def idx(*names):
        for n in names:
            if n in col:
                return col[n]
        return None

    i_code = idx("code")
    i_name = idx("product_name", "product_name_en", "abbreviated_product_name")
    i_generic = idx("generic_name")
    i_brand = idx("brands")
    i_qty = idx("quantity")
    i_cats = idx("categories_tags")
    i_countries = idx("countries_tags")
    i_serving = idx("serving_quantity")
    i_kcal = idx("energy-kcal_100g")
    i_kj = idx("energy_100g", "energy-kj_100g")
    i_p = idx("proteins_100g")
    i_f = idx("fat_100g")
    i_c = idx("carbohydrates_100g")
    i_scans = idx("unique_scans_n")
    need = max(i for i in [i_code, i_name, i_p, i_f, i_c] if i is not None)
    if None in (i_code, i_name, i_p, i_f, i_c):
        raise SystemExit(f"В выгрузке нет нужных колонок: {header[:40]}")

    def get(row, i):
        return row[i] if i is not None and i < len(row) else ""

    best = {}
    total = kept = 0
    for row in reader:
        total += 1
        if len(row) <= need:
            continue
        code = get(row, i_code).strip()
        if not CODE.match(code):
            continue
        if len(code) <= 13:
            code = code.zfill(13)   # UPC-A, EAN-8 и EAN-13 — к одному виду из 13 цифр
        name = clean(get(row, i_name), 90) or clean(get(row, i_generic), 90)
        if len(name) < 2 or name.isdigit():
            continue
        p, f, c = num(get(row, i_p)), num(get(row, i_f)), num(get(row, i_c))
        if p is None or f is None or c is None:
            continue
        kcal = num(get(row, i_kcal))
        if kcal is None:
            kj = num(get(row, i_kj))
            kcal = kj / 4.184 if kj is not None else None
        if kcal is None:
            continue
        if kcal > 950 or p > 100 or f > 100 or c > 100 or p + f + c > 105:
            continue
        calc = p * 4 + f * 9 + c * 4
        if abs(calc - kcal) > max(60, 0.35 * kcal) and not (kcal < 15 and calc < 25):
            continue
        cats = [x for x in get(row, i_cats).split(",") if x]
        role, kind = sane(*clf.classify(cats, name), kcal, p)
        countries = get(row, i_countries).split(",")
        prio = min([PRIORITY.get(x, 3) for x in countries if x] or [3])
        scans = int(num(get(row, i_scans)) or 0)
        rank = prio * 10_000_000 - min(scans, 9_999_999)
        serving = num(get(row, i_serving))
        if serving is not None and (serving <= 0 or serving > 2000):
            serving = None
        brand = clean(get(row, i_brand).split(",")[0], 40)
        qty = clean(get(row, i_qty), 24)
        prev = best.get(code)
        if prev is not None and prev[-1] <= rank:
            continue
        best[code] = (code, name, brand, qty, round(kcal, 1), round(p, 1), round(f, 1), round(c, 1),
                      serving, role, kind, rank)
        kept += 1
        if total % 500_000 == 0:
            log(f"  прочитано {total:,} строк, подходит {len(best):,} ({time.time() - t0:.0f} с)")

    log(f"Open Food Facts: строк {total:,}, подходит {len(best):,}")
    n_usda = 0
    if usda:
        try:
            n_usda = add_usda(best, usda, clf, log)
        except Exception as e:   # без USDA база всё равно соберётся
            log(f"USDA пропущена: {type(e).__name__}: {e}")
    rows = sorted(best.values(), key=lambda r: r[-1])
    log(f"В базу идёт {len(rows):,} продуктов (из них USDA {n_usda:,})")

    if os.path.exists(out):
        os.remove(out)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    db = sqlite3.connect(out)
    db.executescript("""
        PRAGMA page_size = 4096;
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
        CREATE TABLE products(
            id INTEGER PRIMARY KEY,
            code TEXT NOT NULL, name TEXT NOT NULL, brand TEXT, qty TEXT,
            kcal REAL, p REAL, f REAL, c REAL, serving REAL,
            role TEXT, kind TEXT, rank INTEGER);
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
    """)
    db.executemany("INSERT INTO products(code,name,brand,qty,kcal,p,f,c,serving,role,kind,rank) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", rows)
    db.execute("CREATE INDEX products_code ON products(code)")
    db.execute('CREATE VIRTUAL TABLE products_fts USING fts4(content="products", name, brand, tokenize=unicode61)')
    db.execute("INSERT INTO products_fts(products_fts) VALUES('rebuild')")
    db.execute("INSERT INTO products_fts(products_fts) VALUES('optimize')")
    db.executemany("INSERT INTO meta VALUES (?,?)", [
        ("source", "Open Food Facts (ODbL), https://world.openfoodfacts.org" +
                   ("; USDA FoodData Central (CC0), https://fdc.nal.usda.gov" if n_usda else "")),
        ("usda", str(n_usda)),
        ("built", time.strftime("%Y-%m-%d")),
        ("count", str(len(rows))),
    ])
    db.commit()
    db.execute("VACUUM")
    db.close()
    log(f"Готово: {out}, {os.path.getsize(out) / 1e6:.0f} МБ, {time.time() - t0:.0f} с")
    return len(rows)


def selftest():
    header = ["code", "url", "product_name", "generic_name", "quantity", "brands", "categories_tags", "countries_tags",
              "serving_quantity", "unique_scans_n", "energy-kcal_100g", "energy_100g", "fat_100g",
              "carbohydrates_100g", "proteins_100g"]
    rows = [
        ["0737628064502", "", "Thai Peanut Noodle Kit", "", "155 g", "Simply Asia", "en:noodles", "en:united-states", "52", "30", "385", "", "7.7", "71", "9.6"],
        ["737628064502", "", "Duplicate worse", "", "", "", "", "en:france", "", "1", "385", "", "7.7", "71", "9.6"],
        ["0021000658831", "", "Chicken Breast Strips", "", "", "Perdue", "", "en:united-states", "84", "100", "", "460", "1.5", "0", "23"],
        ["4600000000001", "", "Творог 5%", "", "200 г", "Простоквашино", "en:quark", "en:russia", "", "5", "121", "", "5", "1.8", "17.2"],
        ["12345", "", "Bad code", "", "", "", "", "", "", "", "100", "", "1", "1", "1"],
        ["0000000000017", "", "Broken macros", "", "", "", "", "en:united-states", "", "", "900", "", "1", "1", "1"],
        ["0041196910759", "", "Lay's Classic Potato Chips", "", "", "Lay's", "", "en:united-states", "28", "50", "536", "", "35", "53", "7"],
    ]
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "sample.csv.gz")
        with gzip.open(src, "wt", encoding="utf-8", newline="") as fh:
            fh.write("\t".join(header) + "\n")
            for r in rows:
                fh.write("\t".join(r) + "\n")
        out = os.path.join(d, "foods.sqlite")
        n = build(src, out, log=lambda *_: None)
        db = sqlite3.connect(out)
        got = {r[0]: r[1:] for r in db.execute("SELECT code, name, role, kind, kcal FROM products")}
        assert n == 4, (n, got)
        assert got["0737628064502"][1:3] == ("pasta", "c:egg_noodles"), got["0737628064502"]
        assert got["0021000658831"][1:3] == ("meat", "c:chicken_breast"), got["0021000658831"]
        assert abs(got["0021000658831"][3] - 109.9) < 0.2
        assert got["4600000000001"][1:3] == ("cottage", "c:cottage_5")
        assert got["0041196910759"][1] == "snack"
        hits = [r[0] for r in db.execute("SELECT p.name FROM products p WHERE p.id IN (SELECT docid FROM products_fts WHERE products_fts MATCH 'chick*') ORDER BY p.rank")]
        assert hits == ["Chicken Breast Strips"], hits
        hits = [r[0] for r in db.execute("SELECT p.name FROM products p WHERE p.id IN (SELECT docid FROM products_fts WHERE products_fts MATCH 'творог*')")]
        assert hits == ["Творог 5%"], hits
        first = db.execute("SELECT code FROM products ORDER BY id LIMIT 1").fetchone()[0]
        assert first == "0021000658831", first   # больше всего сканирований в США — первым
        db.close()

        # USDA: три CSV в zip (внутри папка, как в настоящем архиве).
        uz = os.path.join(d, "usda.zip")
        def csvtext(rows):
            buf = io.StringIO()
            w = csv.writer(buf, quoting=csv.QUOTE_ALL)
            w.writerows(rows)
            return buf.getvalue()
        branded = [["fdc_id", "brand_owner", "brand_name", "subbrand_name", "gtin_upc", "ingredients", "not_a_significant_source_of",
                    "serving_size", "serving_size_unit", "household_serving_fulltext", "branded_food_category", "data_source",
                    "package_weight", "modified_date", "available_date", "market_country", "discontinued_date"],
                   ["1001", "Chobani LLC", "CHOBANI", "", "818290012345", "Milk, cultures", "", "150", "g", "1 cup",
                    "Yogurt", "GDSN", "5.3 oz/150 g", "2024-01-01", "2024-01-01", "United States", ""],
                   ["1002", "Chobani LLC", "CHOBANI", "", "818290012345", "Old", "", "150", "g", "", "Yogurt", "GDSN", "", "2020-01-01", "2020-01-01", "United States", ""],
                   ["1003", "Perdue", "", "", "00021000658831", "", "", "84", "g", "", "Poultry, Chicken & Turkey", "LI", "", "2024-01-01", "2024-01-01", "United States", ""],
                   ["1004", "Foster Farms", "FOSTER FARMS", "", "075278012345", "", "", "112", "GRM", "", "Poultry, Chicken & Turkey", "LI", "", "2024-01-01", "2024-01-01", "United States", ""],
                   ["1005", "Kraft Heinz", "HEINZ", "", "013000006408", "", "", "17", "g", "", "Ketchup, Mustard, BBQ & Cheese Sauce", "LI", "", "2024-01-01", "2024-01-01", "United States", ""],
                   ["1006", "Kraft Heinz", "KRAFT", "", "021000012345", "", "", "70", "g", "", "Pasta Dinners", "LI", "", "2024-01-01", "2024-01-01", "United States", ""],
                   ["1007", "Nobody", "", "", "abc", "", "", "", "", "", "Cheese", "LI", "", "", "", "", ""]]
        food = [["fdc_id", "data_type", "description", "food_category_id", "publication_date"],
                ["1001", "branded_food", "PLAIN NONFAT GREEK YOGURT", "", "2024-01-01"],
                ["1002", "branded_food", "OLD NAME", "", "2020-01-01"],
                ["1003", "branded_food", "DUPLICATE OF OFF", "", "2024-01-01"],
                ["1004", "branded_food", "BONELESS SKINLESS CHICKEN THIGHS", "", "2024-01-01"],
                ["1005", "branded_food", "TOMATO KETCHUP", "", "2024-01-01"],
                ["1006", "branded_food", "MACARONI & CHEESE DINNER", "", "2024-01-01"],
                ["1007", "branded_food", "NO CODE", "", ""]]
        nut = [["id", "fdc_id", "nutrient_id", "amount", "data_points", "derivation_id", "min", "max", "median", "loq", "footnote", "min_year_acquired", "percent_daily_value"]]
        for fdc, kcal, p_, f_, c_ in [(1001, 53, 10, 0, 3.6), (1002, 99, 1, 1, 1), (1004, None, 18, 9, 0), (1005, 118, 1.2, 0.1, 27), (1006, 371, 11, 4.5, 71)]:
            for nid, a in [("1008", kcal), ("1003", p_), ("1004", f_), ("1005", c_), ("1093", 50)]:
                if a is not None:
                    nut.append(["9", str(fdc), nid, str(a), "", "", "", "", "", "", "", "", ""])
        with zipfile.ZipFile(uz, "w") as zf:
            zf.writestr("FoodData_Central_branded_food_csv_2026-10-29/branded_food.csv", csvtext(branded))
            zf.writestr("FoodData_Central_branded_food_csv_2026-10-29/food.csv", csvtext(food))
            zf.writestr("FoodData_Central_branded_food_csv_2026-10-29/food_nutrient.csv", csvtext(nut))
        out2 = os.path.join(d, "foods2.sqlite")
        n2 = build(src, out2, log=lambda *_: None, usda=uz)
        db = sqlite3.connect(out2)
        got = {r[0]: r[1:] for r in db.execute("SELECT code, name, brand, role, kind, kcal, serving FROM products")}
        assert n2 == 8, (n2, sorted(got))
        assert got["0818290012345"][:4] == ("Plain Nonfat Greek Yogurt", "Chobani", "yogurt", "c:greek_yogurt_0"), got["0818290012345"]
        assert got["0818290012345"][5] == 150
        assert got["0021000658831"][0] == "Chicken Breast Strips"   # штрихкод уже есть в Open Food Facts
        assert got["0075278012345"][2:4] == ("meat", "c:chicken_thigh"), got["0075278012345"]
        assert abs(got["0075278012345"][4] - 153) < 0.5   # ккал посчитаны из БЖУ
        assert got["0013000006408"][2:4] == ("sauce", "c:ketchup"), got["0013000006408"]
        assert got["0021000012345"][2:4] == ("ready", "c:frozen_meal"), got["0021000012345"]   # категория важнее слова «cheese»
        assert db.execute("SELECT value FROM meta WHERE key='usda'").fetchone()[0] == "4"
        hits = [r[0] for r in db.execute("SELECT p.name FROM products p WHERE p.id IN (SELECT docid FROM products_fts WHERE products_fts MATCH 'greek*')")]
        assert hits == ["Plain Nonfat Greek Yogurt"], hits
        db.close()
        # битый zip — база всё равно собирается из Open Food Facts
        bad = os.path.join(d, "bad.zip")
        open(bad, "wb").write(b"<html>not a zip</html>")
        assert build(src, os.path.join(d, "foods3.sqlite"), log=lambda *_: None, usda=bad) == 4

    clf = Classifier(load_rules())
    for sub, tag in USDA_CATS:
        if tag not in (None, OTHER):
            role, _ = clf.classify([tag], "")
            assert role != "other" or tag == "en:flours", (sub, tag)
    assert nice("LAY'S CLASSIC POTATO CHIPS", 90) == "Lay's Classic Potato Chips", nice("LAY'S CLASSIC POTATO CHIPS", 90)
    assert nice("BBQ SAUCE WITH HONEY", 90) == "BBQ Sauce with Honey"
    assert nice("Kodiak Cakes Power Cakes", 90) == "Kodiak Cakes Power Cakes"
    assert sane(*clf.classify([], "Premier Protein Shake Chocolate"), 49, 9.2) == ("milk", "c:protein_drink")
    assert sane(*clf.classify([], "Whey Protein Shake Mix"), 380, 75) == ("protein", "c:whey")
    assert sane(*clf.classify([], "Cream of Wheat Original"), 370, 10) == ("oats", "c:semolina")
    assert clf.classify([], "Тушёнка говяжья высший сорт")[1] == "c:canned_beef"
    assert clf.classify([], "Вареники с творогом")[1] == "c:cheese_vareniki"
    assert clf.classify([], "Филе бедра индейки")[1] == "c:turkey_thigh"
    assert clf.classify([], "Durum wheat spaghetti")[1] == "c:pasta"
    assert clf.classify([], "Cherry tomatoes")[1] == "c:tomato"
    assert usda_code("00021000658831") == "0021000658831" and usda_code("818290012345") == "0818290012345"
    print("selftest ok")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--usda", help="zip с USDA FoodData Central Branded Foods (CSV)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest or not a.src:
        selftest()
    else:
        build(a.src, a.out, usda=a.usda if a.usda and os.path.exists(a.usda) else None)
