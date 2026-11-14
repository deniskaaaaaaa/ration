import SwiftUI
import UIKit

struct GoalView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppHeader()
                HeroCard()
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Цель")
                    GoalTiles()
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Параметры", aside: "формула Миффлина — Сан Жеора")
                    ParamsCard()
                    Text(hint)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    withAnimation(.snappy) { store.tab = .food }
                } label: {
                    HStack(spacing: 8) { Text("Дальше — продукты"); Image(systemName: "arrow.right") }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var hint: String {
        let p = store.profile
        if p.manual { return "Включены свои цифры — приложение берёт их как есть." }
        let g = p.goal
        return "Белок \(fmtSmart(g.proteinPerKg)) г и жиры \(fmtSmart(g.fatPerKg)) г на каждый килограмм веса, остальные калории — углеводы."
    }
}

// MARK: - Кольцо цели

struct HeroCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let p = store.profile
        let T = store.target
        let total = max(T.kcalFromMacros, 1)
        let fp = T.p * 4 / total, ff = T.f * 9 / total, fc = T.c * 4 / total

        Card(padding: 20) {
            HStack {
                Eyebrow("Цель на день")
                Spacer()
                HStack(spacing: 6) {
                    if !p.manual { Image(systemName: goalIcon(p.goal)).font(.system(size: 12, weight: .bold)) }
                    Text(p.manual ? "свои цифры" : p.goal.title)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.accent.opacity(0.14)))
                .overlay(Capsule().stroke(Theme.accent.opacity(0.3), lineWidth: 1))
            }

            ZStack {
                SplitRing(fractions: [fp, ff, fc], colors: [Theme.prot, Theme.fat, Theme.carb], lineWidth: 16)
                    .frame(width: 228, height: 228)
                VStack(spacing: 6) {
                    Text(fmt(T.kcal))
                        .font(.rounded(46, .heavy))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("ккал в день").font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .animation(.snappy, value: T.kcal)

            HStack(spacing: 8) {
                MacroTile(name: "Белки", grams: T.p, share: fp, color: Theme.prot)
                MacroTile(name: "Жиры", grams: T.f, share: ff, color: Theme.fat)
                MacroTile(name: "Углеводы", grams: T.c, share: fc, color: Theme.carb)
            }

            Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 16)
            HStack {
                Text("Обмен в покое **\(fmt(p.bmr))**")
                Spacer()
                Text("Расход за день **\(fmt(p.tdee))**")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .padding(.top, 12)
        }
        .shadow(color: Theme.accent.opacity(0.16), radius: 40, y: 22)
    }

    private func goalIcon(_ g: Goal) -> String {
        switch g {
        case .cut: return "flame.fill"
        case .keep: return "scalemass"
        case .bulk: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct MacroTile: View {
    let name: String
    let grams: Double
    let share: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Dot(color: color)
                Text(name).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(fmt(grams)).font(.rounded(23, .bold)).monospacedDigit().contentTransition(.numericText())
                Text("г").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
            }
            Text("\(Int((share * 100).rounded()))% калорий").font(.system(size: 12)).foregroundStyle(Theme.dim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .animation(.snappy, value: grams)
    }
}

// MARK: - Выбор цели

struct GoalTiles: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 10) {
            tile(.cut, "flame.fill")
            tile(.keep, "scalemass")
            tile(.bulk, "chart.line.uptrend.xyaxis")
        }
    }

    private func tile(_ g: Goal, _ icon: String) -> some View {
        let on = store.profile.goal == g && !store.profile.manual
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy) {
                store.profile.goal = g
                store.profile.manual = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.raised))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(on ? Theme.accentInk : Theme.muted)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.title).font(.system(size: 15, weight: .bold)).lineLimit(1).minimumScaleFactor(0.75)
                    Text(g.subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(on ? AnyShapeStyle(LinearGradient(colors: [Theme.accent.opacity(0.2), Theme.accent.opacity(0.03)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.surface))
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? Theme.accent.opacity(0.6) : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Параметры

struct ParamsCard: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Card(padding: 0) {
            row {
                Text("Пол").font(.system(size: 15, weight: .semibold))
                Spacer()
                Segmented(items: [(true, "Мужчина"), (false, "Женщина")], selection: $store.profile.male)
                    .frame(width: 196)
            }
            divider
            row {
                label("Возраст", "лет")
                Spacer()
                StepperField(value: $store.profile.age, step: 1, range: 14...90)
            }
            divider
            row {
                label("Рост", "см")
                Spacer()
                StepperField(value: $store.profile.height, step: 1, range: 120...230)
            }
            divider
            row {
                label("Вес", "кг")
                Spacer()
                StepperField(value: $store.profile.weight, step: 0.5, range: 35...250)
            }
            divider
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Активность").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(store.profile.activityLevel.title) · ×\(fmtSmart(store.profile.activityLevel.factor))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent2)
                }
                Slider(value: activityBinding, in: 0...Double(ActivityLevel.all.count - 1), step: 1)
                    .tint(Theme.accent)
                Text(store.profile.activityLevel.detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            divider
            row {
                label("Свои КБЖУ", "ввести цифры вручную")
                Spacer()
                Toggle("", isOn: manualBinding).labelsHidden().tint(Theme.accent)
            }
            if store.profile.manual {
                divider
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        NumberBox(title: "Ккал", color: Theme.accent, value: $store.profile.manualTarget.kcal)
                        NumberBox(title: "Белки", color: Theme.prot, value: $store.profile.manualTarget.p)
                        NumberBox(title: "Жиры", color: Theme.fat, value: $store.profile.manualTarget.f)
                        NumberBox(title: "Углев.", color: Theme.carb, value: $store.profile.manualTarget.c)
                    }
                    let m = store.profile.manualTarget
                    let calc = m.kcalFromMacros
                    let off = m.kcal > 0 && abs(calc - m.kcal) / m.kcal > 0.05
                    Text(off ? "По БЖУ выходит \(fmt(calc)) ккал — не совпадает с \(fmt(m.kcal)). Приложение будет держаться белка и калорий."
                             : "По БЖУ выходит \(fmt(calc)) ккал.")
                        .font(.system(size: 13))
                        .foregroundStyle(off ? Theme.warn : Theme.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var activityBinding: Binding<Double> {
        Binding(get: { Double(store.profile.activity) },
                set: { store.profile.activity = Int($0.rounded()) })
    }

    private var manualBinding: Binding<Bool> {
        Binding(get: { store.profile.manual },
                set: { on in
                    withAnimation(.snappy) {
                        if on { store.profile.manualTarget = store.profile.computedTarget }
                        store.profile.manual = on
                    }
                })
    }

    private func row<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 12) { c() }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 60)
    }

    private func label(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(sub).font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 16)
    }
}

struct StepperField: View {
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 2) {
            button("minus") { value = max(range.lowerBound, ((value - step) * 10).rounded() / 10) }
            Text(fmtSmart(value))
                .font(.rounded(18, .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(width: 72)
            button("plus") { value = min(range.upperBound, ((value + step) * 10).rounded() / 10) }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .animation(.snappy(duration: 0.2), value: value)
    }

    private func button(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.raised))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}

struct NumberBox: View {
    let title: String
    let color: Color
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Dot(color: color, size: 6)
                Text(title).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            TextField("0", value: $value, format: .number.precision(.fractionLength(0)))
                .keyboardType(.numberPad)
                .font(.rounded(17, .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}
