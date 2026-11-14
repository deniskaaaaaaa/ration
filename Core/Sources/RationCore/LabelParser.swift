import Foundation

/// Разбор текста этикетки (распознанного камерой): Nutrition Facts (США) или «Пищевая ценность на 100 г».
public struct LabelResult: Equatable, Sendable {
    /// КБЖУ на 100 г, если их удалось получить.
    public var per100: Macros?
    /// КБЖУ на порцию (американская этикетка).
    public var perServing: Macros?
    /// Вес порции, г (или мл).
    public var servingGrams: Double?
    /// Сколько показателей нашлось (0–4).
    public var found: Int

    public var isUseful: Bool { found >= 2 }
}

public enum LabelParser {
    public static func parse(_ raw: String) -> LabelResult {
        var t = raw.lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "ё", with: "е")
        t = replace(t, #"(\d),(\d)"#, "$1.$2")
        // «Og» вместо «0g» — частая ошибка распознавания.
        t = replace(t, #"(?<=\s)o(?=\s?g\b)"#, "0")
        t = replace(t, #"\s+"#, " ")

        let num = #"(\d+(?:\.\d+)?)"#
        let sep = #"\s*[:\-–—]?\s*"#

        let kcal = first(t, [num + #"\s*(?:ккал|kcal)"#,
                             #"calories(?!\s*from)"# + sep + #"(\d{1,4})"#,
                             #"(\d{2,4})\s*calories"#])
        let protein = first(t, [#"(?:protein|белки|белок|белков)"# + sep + num])
        let fat = first(t, [#"(?:total fat|жиры|жир)"# + sep + num, #"\bfat"# + sep + num])
        let carbs = first(t, [#"(?:total carbohydrates?|total carbs?|углеводы|углевод)"# + sep + num,
                              #"carbohydrates?"# + sep + num])
        var serving = first(t, [#"serving size[^(]{0,40}\("# + num + #"\s*(?:g|ml|мл|г)\)"#,
                                #"serving size"# + sep + num + #"\s*(?:g|ml)\b"#,
                                #"(?:порци\w*|serving)\D{0,15}"# + num + #"\s*(?:g|г|ml|мл)\b"#])
        if let s = serving, s <= 0 { serving = nil }

        let foundCount = [kcal, protein, fat, carbs].compactMap { $0 }.count
        let p = protein ?? 0, f = fat ?? 0, c = carbs ?? 0
        let k = kcal ?? (p * 4 + f * 9 + c * 4)
        let values = Macros(kcal: k, p: p, f: f, c: c)

        let per100Marked = t.range(of: #"(на|per|in|/)\s*100\s*(г|g|мл|ml)"#, options: .regularExpression) != nil
            || t.contains("100 г") || t.contains("100г")
        let usStyle = t.contains("nutrition facts") || t.contains("serving size") || t.contains("per serving")

        var r = LabelResult(per100: nil, perServing: nil, servingGrams: serving, found: foundCount)
        if foundCount == 0 { return r }
        if per100Marked && !usStyle {
            r.per100 = values
        } else if let s = serving {
            r.perServing = values
            r.per100 = values * (100 / s)
        } else if per100Marked {
            r.per100 = values
        } else {
            r.perServing = values
        }
        return r
    }

    private static func replace(_ s: String, _ pattern: String, _ with: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: with)
    }

    private static func first(_ s: String, _ patterns: [String]) -> Double? {
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p) else { continue }
            if let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), m.numberOfRanges > 1,
               let r = Range(m.range(at: 1), in: s), let v = Double(s[r]) {
                return v
            }
        }
        return nil
    }
}

/// Штрихкоды: UPC-A и EAN-13 — одно и то же число с нулём впереди или без.
public enum Barcode {
    public static func variants(_ code: String) -> [String] {
        let digits = code.filter { $0.isNumber }
        guard !digits.isEmpty else { return [] }
        var out = [digits]
        if digits.count == 12 { out.append("0" + digits) }
        if digits.count == 13 && digits.hasPrefix("0") { out.append(String(digits.dropFirst())) }
        if digits.count == 14 && digits.hasPrefix("0") { out.append(String(digits.dropFirst())); out.append(String(digits.dropFirst(2))) }
        if digits.count < 12 { out.append(String(repeating: "0", count: 13 - digits.count) + digits) }
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }
}
