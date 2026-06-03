import SwiftUI

// Reads data written by the main app via App Groups (group.TheClassified.Balance-X)
private let sharedDefaults = UserDefaults(suiteName: "group.TheClassified.Balance-X")

struct BXWatchContentView: View {
    @State private var tab = 0
    @State private var income: Double = sharedDefaults?.double(forKey: "bx_widget_income") ?? 0
    @State private var expenses: Double = sharedDefaults?.double(forKey: "bx_widget_expenses") ?? 0
    @State private var currency: String = sharedDefaults?.string(forKey: "bx_widget_currency") ?? "USD"

    var net: Double { income - expenses }

    var body: some View {
        TabView(selection: $tab) {
            balanceTab.tag(0)
            quickAddTab.tag(1)
        }
        .tabViewStyle(.page)
    }

    // MARK: - Balance Tab

    private var balanceTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Balance X")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 2) {
                    Text(net >= 0 ? "+" : "")
                    + Text(net, format: .currency(code: currency))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(net >= 0 ? Color(red: 0.06, green: 0.92, blue: 0.53) : Color(red: 1, green: 0.29, blue: 0.39))
                }

                HStack(spacing: 16) {
                    statPill(label: "In", value: income, color: Color(red: 0.06, green: 0.92, blue: 0.53))
                    statPill(label: "Out", value: expenses, color: Color(red: 1, green: 0.29, blue: 0.39))
                }

                Button("+ Add") { tab = 1 }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(8)
        }
    }

    private func statPill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value, format: .currency(code: currency).precision(.fractionLength(0)))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Quick Add Tab

    @State private var amount = ""
    @State private var saved = false

    private var quickAddTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Quick Add")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                if saved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(red: 0.06, green: 0.92, blue: 0.53))
                        .transition(.scale.combined(with: .opacity))
                    Text("Saved!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                } else {
                    // Amount display
                    Text(amount.isEmpty ? "0" : amount)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 1, green: 0.29, blue: 0.39))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)

                    // Compact keypad
                    VStack(spacing: 4) {
                        ForEach([["1","2","3"],["4","5","6"],["7","8","9"],[".",  "0","⌫"]], id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(row, id: \.self) { key in
                                    Button {
                                        handleKey(key)
                                    } label: {
                                        Text(key)
                                            .font(.system(size: 16, weight: .semibold))
                                            .frame(maxWidth: .infinity, minHeight: 30)
                                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Button("Save Expense") {
                        saveExpense()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .font(.system(size: 12, weight: .bold))
                    .disabled(amount.isEmpty || amount == "0")
                }
            }
            .padding(6)
            .animation(.spring(response: 0.3), value: saved)
        }
    }

    private func handleKey(_ key: String) {
        if key == "⌫" {
            if !amount.isEmpty { amount.removeLast() }
            return
        }
        if key == "." && amount.contains(".") { return }
        if amount == "0" && key != "." { amount = key; return }
        if amount.count < 8 { amount += key }
    }

    private func saveExpense() {
        guard let value = Double(amount), value > 0 else { return }
        // Deduct from expenses balance and persist via App Groups
        let newExpenses = expenses + value
        sharedDefaults?.set(newExpenses, forKey: "bx_widget_expenses")
        expenses = newExpenses
        amount = ""
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { saved = false; tab = 0 }
        }
    }
}
