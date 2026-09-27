import Foundation
import Testing
@testable import PingSentry

@Suite("PingStats Tests")
struct PingStatsTests {

    @Test("Default stats are empty")
    func testEmptyStats() {
        let stats = PingStats()
        #expect(stats.totalCount == 0)
        #expect(stats.successCount == 0)
        #expect(stats.failureCount == 0)
        #expect(stats.successPercent == 0)
        #expect(stats.failurePercent == 0)
        #expect(stats.averageLatency == nil)
        #expect(stats.minLatency == nil)
        #expect(stats.maxLatency == nil)
    }

    @Test("Record successful results")
    func testSuccessfulRecords() {
        var stats = PingStats()
        let now = Date()

        stats.record(PingResult(timestamp: now, success: true, latencyMs: 10.0))
        stats.record(PingResult(timestamp: now, success: true, latencyMs: 20.0))
        stats.record(PingResult(timestamp: now, success: true, latencyMs: 30.0))

        #expect(stats.totalCount == 3)
        #expect(stats.successCount == 3)
        #expect(stats.failureCount == 0)
        #expect(stats.successPercent == 100.0)
        #expect(stats.failurePercent == 0.0)
        #expect(stats.minLatency == 10.0)
        #expect(stats.maxLatency == 30.0)
        #expect(stats.averageLatency == 20.0)
    }

    @Test("Record mixed successes and failures")
    func testMixedRecords() {
        var stats = PingStats()
        let now = Date()

        stats.record(PingResult(timestamp: now, success: true, latencyMs: 15.0))
        stats.record(PingResult(timestamp: now, success: false, latencyMs: nil))
        stats.record(PingResult(timestamp: now, success: true, latencyMs: 25.0))
        stats.record(PingResult(timestamp: now, success: false, latencyMs: nil))

        #expect(stats.totalCount == 4)
        #expect(stats.successCount == 2)
        #expect(stats.failureCount == 2)
        #expect(stats.successPercent == 50.0)
        #expect(stats.failurePercent == 50.0)
        #expect(stats.minLatency == 15.0)
        #expect(stats.maxLatency == 25.0)
        #expect(stats.averageLatency == 20.0)
    }

    @Test("Record only failures")
    func testFailureOnlyRecords() {
        var stats = PingStats()
        let now = Date()

        stats.record(PingResult(timestamp: now, success: false, latencyMs: nil))
        stats.record(PingResult(timestamp: now, success: false, latencyMs: nil))

        #expect(stats.totalCount == 2)
        #expect(stats.successCount == 0)
        #expect(stats.failureCount == 2)
        #expect(stats.successPercent == 0.0)
        #expect(stats.failurePercent == 100.0)
        #expect(stats.averageLatency == nil)
        #expect(stats.minLatency == nil)
        #expect(stats.maxLatency == nil)
    }
}
