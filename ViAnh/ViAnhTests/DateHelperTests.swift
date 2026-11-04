import XCTest
@testable import ViAnh

final class DateHelperTests: XCTestCase {

    func testRelativeDayStringToday() {
        let now = Date.now
        let str = DateHelpers.relativeDayString(from: now)
        XCTAssertEqual(str, "Hôm nay")
    }

    func testRelativeDayStringYesterday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        let today = Date.now
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Failed to compute yesterday")
            return
        }

        let str = DateHelpers.relativeDayString(from: yesterday, calendar: cal)
        XCTAssertEqual(str, "Hôm qua")
    }

    func testRelativeDayStringPastDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 5
        comp.day = 20
        let date = cal.date(from: comp)!

        let str = DateHelpers.relativeDayString(from: date, calendar: cal)
        XCTAssertEqual(str, "20/05/2026")
    }

    func testFormatFullDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 11
        comp.day = 2
        let date = cal.date(from: comp)!

        let formatted = DateHelpers.formatFullDate(date)
        XCTAssertEqual(formatted, "02/11/2026")
    }

    func testFormatMonthYear() {
        let str = DateHelpers.formatMonthYear(year: 2026, month: 11)
        XCTAssertTrue(str.contains("2026"))
        XCTAssertTrue(str.contains("11") || str.lowercased().contains("tháng"))
    }

    func testMonthRange() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!

        guard let range = DateHelpers.monthRange(year: 2026, month: 11, calendar: cal) else {
            XCTFail("Failed to compute month range")
            return
        }

        let startMonth = cal.component(.month, from: range.start)
        let startDay = cal.component(.day, from: range.start)
        let endMonth = cal.component(.month, from: range.end)
        let endDay = cal.component(.day, from: range.end)

        XCTAssertEqual(startMonth, 11)
        XCTAssertEqual(startDay, 1)
        XCTAssertEqual(endMonth, 12)
        XCTAssertEqual(endDay, 1)
    }
}

