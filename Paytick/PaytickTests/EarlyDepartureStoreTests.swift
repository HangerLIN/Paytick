import Foundation
import Testing
@testable import Paytick

struct EarlyDepartureStoreTests {
    @Test func settlesOnceAndPersistsByMonth() throws {
        let suite = "Paytick.EarlyDepartureTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let first = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)))
        let second = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 3)))
        let nextMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let store = EarlyDepartureStore(defaults: defaults, calendar: calendar)

        #expect(store.settle(on: first, dailyIncome: 300, earnedIncome: 120) == 180)
        #expect(store.settle(on: first, dailyIncome: 300, earnedIncome: 200) == 180)
        #expect(store.settle(on: second, dailyIncome: 300, earnedIncome: 350) == 0)
        #expect(store.settle(on: nextMonth, dailyIncome: 200, earnedIncome: 50) == 150)
        let reloaded = EarlyDepartureStore(defaults: defaults, calendar: calendar)
        #expect(reloaded.amount(on: first) == 180)
        #expect(reloaded.monthlyTotal(on: second) == 180)
        #expect(reloaded.monthlyTotal(on: nextMonth) == 150)
    }
}
