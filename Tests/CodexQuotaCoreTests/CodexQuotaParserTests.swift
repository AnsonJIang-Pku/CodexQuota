import XCTest
@testable import CodexQuotaCore

final class CodexQuotaParserTests: XCTestCase {
    func testParsesNestedRateLimits() throws {
        let response: [String: Any] = [
            "result": [
                "rateLimits": [
                    "primary": [
                        "usedPercent": 28,
                        "windowDurationMins": 300,
                        "resetsAt": 1_780_000_000
                    ],
                    "secondary": [
                        "usedPercent": 59,
                        "windowDurationMins": 10_080,
                        "resetsAt": 1_780_500_000
                    ]
                ]
            ]
        ]

        let snapshot = try CodexQuotaParser.parse(response: response)
        XCTAssertEqual(snapshot.primary?.remainingPercent, 72)
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 41)
        XCTAssertEqual(snapshot.primary?.label, "5h")
        XCTAssertEqual(snapshot.secondary?.label, "Weekly")
    }

    func testParsesDirectRateLimitsAndMissingSecondary() throws {
        let response: [String: Any] = [
            "result": [
                "primary": [
                    "used_percent": "12.5",
                    "window_duration_mins": 300
                ]
            ]
        ]

        let snapshot = try CodexQuotaParser.parse(response: response)
        XCTAssertEqual(snapshot.primary?.remainingPercent, 87.5)
        XCTAssertNil(snapshot.secondary)
    }

    func testRejectsMissingRateLimits() {
        XCTAssertThrowsError(try CodexQuotaParser.parse(response: ["result": [:]]))
    }
}
