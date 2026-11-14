import SwiftUI
import UIKit

@main
struct RationApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack(alignment: .bottom) {
            Backdrop()
            Group {
                switch store.tab {
                case .goal: GoalView()
                case .food: PantryView()
                case .plan: PlanView()
                }
            }
            .transition(.opacity)
            TabBar(tab: $store.tab, count: store.pantry.count)
        }
        .foregroundStyle(Theme.text)
        .overlay(alignment: .top) {
            if let t = store.toast {
                Text(t)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.raised))
                    .overlay(Capsule().stroke(Theme.line2, lineWidth: 1))
                    .shadow(color: .black.opacity(0.6), radius: 16, y: 8)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

struct TabBar: View {
    @Binding var tab: AppTab
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            item(.goal, "scope", "Цель")
            item(.food, "refrigerator", "Продукты")
            item(.plan, "fork.knife", "Рацион")
        }
        .padding(6)
        .background(
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color(hex: 0x1E1E1B, alpha: 0.65)))
        )
        .overlay(Capsule().stroke(Theme.line2, lineWidth: 1))
        .shadow(color: .black.opacity(0.75), radius: 24, y: 12)
        .padding(.bottom, 6)
    }

    private func item(_ t: AppTab, _ icon: String, _ title: String) -> some View {
        let on = tab == t
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.3)) { tab = t }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                if on {
                    Text(title).font(.system(size: 15, weight: .bold))
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
                if t == .food && count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(Theme.accentInk)
                }
            }
            .foregroundStyle(on ? Theme.bg : Theme.muted)
            .padding(.horizontal, on ? 18 : 15)
            .frame(height: 48)
            .background { if on { Capsule().fill(Theme.text) } }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
