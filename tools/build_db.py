#!/usr/bin/env python3
"""Собирает базу продуктов foods.sqlite из выгрузки Open Food Facts (CSV, разделитель — табуляция).

    python3 tools/build_db.py off.csv.gz data/foods.sqlite
    python3 tools/build_db.py --selftest

Роли и «виды» продуктов берутся из Core/Sources/RationCore/RoleMap.swift — тот же JSON, что в приложении.
Данные Open Food Facts распространяются по лицензии Open Database License (ODbL).
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


def build(src, out, log=print):
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
        role, kind = clf.classify(cats, name)
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

    rows = sorted(best.values(), key=lambda r: r[-1])
    log(f"Всего строк {total:,}; в базу идёт {len(rows):,} продуктов")

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
        ("source", "Open Food Facts (ODbL), https://world.openfoodfacts.org"),
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
    print("selftest ok")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest or not a.src:
        selftest()
    else:
        build(a.src, a.out)
