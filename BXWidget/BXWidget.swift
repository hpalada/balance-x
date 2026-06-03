import WidgetKit
import SwiftUI

private let groupSuite = "group.TheClassified.Balance-X"

struct BXWidgetEntry: TimelineEntry {
    let date: Date
    let income: Double
    let expenses: Double
    let currency: String
}

struct BXWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BXWidgetEntry {
        BXWidgetEntry(date: .now, income: 3200, expenses: 1800, currency: "USD")
    }

    func getSnapshot(in context: Context, completion: @escaping (BXWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BXWidgetEntry>) -> Void) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .atEnd))
    }

    private func currentEntry() -> BXWidgetEntry {
        let defaults = UserDefaults(suiteName: groupSuite)
        let income = defaults?.double(forKey: "bx_widget_income") ?? 0
        let expenses = defaults?.double(forKey: "bx_widget_expenses") ?? 0
        let currency = defaults?.string(forKey: "bx_widget_currency") ?? "USD"
        return BXWidgetEntry(date: .now, income: income, expenses: expenses, currency: currency)
    }
}

private func formatted(_ amount: Double, currency: String) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = currency
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: amount)) ?? "\(currency) \(Int(amount))"
}

struct BXWidgetSmallView: View {
    let entry: BXWidgetEntry
    private var net: Double { entry.income - entry.expenses }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Text("BALANCE X")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .kerning(0.5)
            }
            Spacer()
            Text("Este mes")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
            Text(formatted(abs(net), currency: entry.currency))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(net >= 0 ? Color(red: 0.29, green: 0.87, blue: 0.50) : Color(red: 0.97, green: 0.44, blue: 0.44))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(net >= 0 ? "Ganancia" : "Perdida")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(net >= 0 ? Color(red: 0.29, green: 0.87, blue: 0.50) : Color(red: 0.97, green: 0.44, blue: 0.44))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color(red: 0.051, green: 0.051, blue: 0.059), for: .widget)
    }
}

struct BXWidgetMediumView: View {
    let entry: BXWidgetEntry
    private var net: Double { entry.income - entry.expenses }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("BALANCE X")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .kerning(0.5)
                }
                Spacer()
                Text("Neto del mes")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
                Text(formatted(abs(net), currency: entry.currency))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(net >= 0 ? Color(red: 0.29, green: 0.87, blue: 0.50) : Color(red: 0.97, green: 0.44, blue: 0.44))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ingresos")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(formatted(entry.income, currency: entry.currency))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.29, green: 0.87, blue: 0.50))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gastos")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(formatted(entry.expenses, currency: entry.currency))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.97, green: 0.44, blue: 0.44))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(red: 0.051, green: 0.051, blue: 0.059), for: .widget)
    }
}

struct BXWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: BXWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            BXWidgetMediumView(entry: entry)
        default:
            BXWidgetSmallView(entry: entry)
        }
    }
}

@main
struct BXWidget: Widget {
    let kind = "BXWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BXWidgetProvider()) { entry in
            BXWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Balance X")
        .description("Resumen financiero del mes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
