import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Встроенная база продуктов со штрихкодами (Open Food Facts, собирается в облаке при сборке приложения).
final class FoodDB: @unchecked Sendable {
    static let shared = FoodDB()

    private var db: OpaquePointer?
    private let lock = NSLock()
    private var ftsWorks = true
    private(set) var count = 0
    private(set) var built = ""

    var available: Bool { db != nil }

    private init() {
        guard let path = Bundle.main.path(forResource: "foods", ofType: "sqlite") else { return }
        let uri = URL(fileURLWithPath: path).absoluteString + "?immutable=1"
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(uri, &handle, flags, nil) == SQLITE_OK {
            db = handle
            count = Int(scalar("SELECT value FROM meta WHERE key = 'count'") ?? "") ?? 0
            built = scalar("SELECT value FROM meta WHERE key = 'built'") ?? ""
        } else if let h = handle {
            sqlite3_close(h)
        }
    }

    private static let columns = "code, name, brand, qty, kcal, p, f, c, role, kind"

    /// Продукт по штрихкоду.
    func lookup(_ code: String) -> Food? {
        let variants = Array(Barcode.variants(code).prefix(5))
        guard !variants.isEmpty else { return nil }
        let marks = variants.map { _ in "?" }.joined(separator: ",")
        return rows("SELECT \(Self.columns) FROM products WHERE code IN (\(marks)) ORDER BY rank LIMIT 1", variants).first
    }

    /// Поиск по названию и бренду.
    func search(_ query: String, limit: Int = 40) -> [Food] {
        let tokens = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
            .prefix(5)
        guard !tokens.isEmpty else { return [] }
        if ftsWorks {
            let match = tokens.map { $0 + "*" }.joined(separator: " ")
            var failed = false
            let res = rows("SELECT \(Self.columns) FROM products WHERE id IN (SELECT docid FROM products_fts WHERE products_fts MATCH ? LIMIT 600) ORDER BY rank LIMIT \(limit)", [match], failed: &failed)
            if !failed { return res }
            ftsWorks = false
        }
        let like = "%" + (tokens.first ?? "") + "%"
        return rows("SELECT \(Self.columns) FROM products WHERE name LIKE ? ORDER BY rank LIMIT \(limit)", [like])
    }

    // MARK: SQLite

    private func scalar(_ sql: String) -> String? {
        guard let db = db else { return nil }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, sqlite3_step(stmt) == SQLITE_ROW,
              let c = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: c)
    }

    private func rows(_ sql: String, _ binds: [String]) -> [Food] {
        var failed = false
        return rows(sql, binds, failed: &failed)
    }

    private func rows(_ sql: String, _ binds: [String], failed: inout Bool) -> [Food] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            failed = true
            return []
        }
        defer { sqlite3_finalize(stmt) }
        for (i, b) in binds.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), b, -1, SQLITE_TRANSIENT)
        }
        var out: [Food] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { failed = true; break }
            let code = text(stmt, 0)
            let name = text(stmt, 1)
            let brand = text(stmt, 2)
            let qty = text(stmt, 3)
            let m = Macros(kcal: sqlite3_column_double(stmt, 4), p: sqlite3_column_double(stmt, 5),
                           f: sqlite3_column_double(stmt, 6), c: sqlite3_column_double(stmt, 7))
            let role = Role(rawValue: text(stmt, 8)) ?? .other
            let kind = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : text(stmt, 9)
            let brandLine = [brand, qty].filter { !$0.isEmpty }.joined(separator: " · ")
            out.append(Catalog.packaged(code: code, name: name, brand: brandLine.isEmpty ? nil : brandLine,
                                        per100: m, role: role, kind: kind?.isEmpty == true ? nil : kind))
        }
        return out
    }

    private func text(_ s: OpaquePointer?, _ i: Int32) -> String {
        guard let c = sqlite3_column_text(s, i) else { return "" }
        return String(cString: c)
    }
}

/// Продукта нет во встроенной базе — спросить Open Food Facts через интернет (бесплатно).
enum OFFClient {
    static func fetch(_ code: String) async -> Food? {
        let digits = code.filter { $0.isNumber }
        guard !digits.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json?fields=code,product_name,brands,quantity,categories_tags,nutriments") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Ratsion/1.0 (iPhone; personal meal planner)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        guard let response = try? await URLSession.shared.data(for: req),
              let root = try? JSONSerialization.jsonObject(with: response.0) as? [String: Any],
              (root["status"] as? Int) == 1,
              let p = root["product"] as? [String: Any],
              let n = p["nutriments"] as? [String: Any] else { return nil }
        func num(_ k: String) -> Double? {
            if let d = n[k] as? Double { return d }
            if let i = n[k] as? Int { return Double(i) }
            if let s = n[k] as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
            return nil
        }
        let name = (p["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, let pr = num("proteins_100g"), let f = num("fat_100g"), let c = num("carbohydrates_100g") else { return nil }
        let kcal = num("energy-kcal_100g") ?? num("energy_100g").map { $0 / 4.184 } ?? (pr * 4 + f * 9 + c * 4)
        let cats = p["categories_tags"] as? [String] ?? []
        let (role, kind) = RoleMap.classify(categories: cats, name: name)
        let brand = (p["brands"] as? String)?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) }
        let qty = p["quantity"] as? String
        let brandLine = [brand ?? "", qty ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
        let normalized = digits.count <= 13 ? String(repeating: "0", count: 13 - digits.count) + digits : digits
        return Catalog.packaged(code: normalized, name: name, brand: brandLine.isEmpty ? nil : brandLine,
                                per100: Macros(kcal: kcal, p: pr, f: f, c: c), role: role, kind: kind)
    }
}

/// Найти продукт по штрихкоду: сначала во встроенной базе, потом в интернете.
enum Lookup {
    static func barcode(_ code: String) async -> Food? {
        if let f = await Task.detached(priority: .userInitiated, operation: { FoodDB.shared.lookup(code) }).value { return f }
        return await OFFClient.fetch(code)
    }

    static func search(_ q: String) async -> [Food] {
        let local = Catalog.search(q, limit: 15)
        let db = await Task.detached(priority: .userInitiated, operation: { FoodDB.shared.search(q) }).value
        return local + db
    }
}
