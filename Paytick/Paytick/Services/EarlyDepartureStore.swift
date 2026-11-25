import Foundation

/// Stores one fixed settlement per local calendar day.
final class EarlyDepartureStore {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let key = "earlyDepartureDailyAmounts"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    private func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private var records: [String: Double] {
        (defaults.dictionary(forKey: key) ?? [:]).compactMapValues { ($0 as? NSNumber)?.doubleValue }
    }

    func amount(on date: Date) -> Double? { records[dayKey(date)] }

    func monthlyTotal(on date: Date) -> Double {
        let prefix = String(dayKey(date).prefix(7)) + "-"
        return records.filter { $0.key.hasPrefix(prefix) }.values.reduce(0, +)
    }

    func yearlyTotal(on date: Date) -> Double {
        let prefix = String(dayKey(date).prefix(4)) + "-"
        return records.filter { $0.key.hasPrefix(prefix) }.values.reduce(0, +)
    }

    @discardableResult
    func settle(on date: Date, dailyIncome: Double, earnedIncome: Double) -> Double {
        var saved = records
        let day = dayKey(date)
        if let existing = saved[day] { return existing }
        let amount = max(0, dailyIncome - earnedIncome)
        saved[day] = amount
        defaults.set(saved, forKey: key)
        return amount
    }
}
