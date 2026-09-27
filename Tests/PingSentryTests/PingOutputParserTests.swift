import Foundation
import Testing
@testable import PingSentry

@Suite("PingOutputParser Tests")
struct PingOutputParserTests {

    @Test("Parse standard macOS ping output line")
    func testParseSuccessLine() {
        let line = "64 bytes from 1.1.1.1: icmp_seq=0 ttl=58 time=14.234 ms"
        let result = PingOutputParser.parseLine(line)
        #expect(result == .success(seq: 0, latencyMs: 14.234))
    }

    @Test("Parse higher sequence number and rounded latency")
    func testParseHigherSeqLine() {
        let line = "64 bytes from 8.8.8.8: icmp_seq=123 ttl=117 time=25 ms"
        let result = PingOutputParser.parseLine(line)
        #expect(result == .success(seq: 123, latencyMs: 25.0))
    }

    @Test("Parse request timeout line")
    func testParseTimeoutLine() {
        let line = "Request timeout for icmp_seq 4"
        let result = PingOutputParser.parseLine(line)
        #expect(result == .timeout(seq: 4))
    }

    @Test("Ignore ping header and summary lines")
    func testIgnoreNonPingLines() {
        let headers = [
            "PING 1.1.1.1 (1.1.1.1): 56 data bytes",
            "--- 1.1.1.1 ping statistics ---",
            "5 packets transmitted, 5 packets received, 0.0% packet loss",
            "round-trip min/avg/max/stddev = 13.811/14.502/15.309/0.512 ms",
            "random unformatted text",
            ""
        ]

        for line in headers {
            #expect(PingOutputParser.parseLine(line) == .ignored)
        }
    }

    @Test("Consume stream chunks split across multiple calls")
    func testChunkedStreamConsumption() {
        var parser = PingOutputParser()

        // Feed first chunk without newline
        let firstChunk = "64 bytes from 1.1.1.1: icmp_seq=0 ttl=58 "
        let results1 = parser.consume(chunk: firstChunk)
        #expect(results1.isEmpty)

        // Feed second chunk completing the line
        let secondChunk = "time=12.5 ms\n"
        let results2 = parser.consume(chunk: secondChunk)
        #expect(results2.count == 1)
        #expect(results2[0].success == true)
        #expect(results2[0].latencyMs == 12.5)
    }

    @Test("Consume multiple lines in a single chunk")
    func testMultipleLinesInChunk() {
        var parser = PingOutputParser()
        let chunk = "64 bytes from 1.1.1.1: icmp_seq=0 ttl=58 time=10.0 ms\nRequest timeout for icmp_seq 1\n"
        let results = parser.consume(chunk: chunk)

        #expect(results.count == 2)
        #expect(results[0].success == true)
        #expect(results[0].latencyMs == 10.0)
        #expect(results[1].success == false)
        #expect(results[1].latencyMs == nil)
    }

    @Test("Detect missing packet gap and inject synthetic failures")
    func testMissingPacketGapDetection() {
        var parser = PingOutputParser()

        // First packet seq 0
        let r0 = parser.consume(chunk: "64 bytes from 1.1.1.1: icmp_seq=0 ttl=58 time=10.0 ms\n")
        #expect(r0.count == 1)
        #expect(r0[0].success == true)

        // Next packet seq 3 (meaning 1 and 2 were dropped without explicit timeout lines)
        let r3 = parser.consume(chunk: "64 bytes from 1.1.1.1: icmp_seq=3 ttl=58 time=15.0 ms\n")
        #expect(r3.count == 3) // 2 synthetic drops + 1 success
        #expect(r3[0].success == false)
        #expect(r3[1].success == false)
        #expect(r3[2].success == true)
        #expect(r3[2].latencyMs == 15.0)
    }

    @Test("Cap maximum missing packets to avoid memory explosion")
    func testMaxMissingPacketsCapped() {
        var parser = PingOutputParser(maxMissingPackets: 10)

        _ = parser.consume(chunk: "64 bytes from 1.1.1.1: icmp_seq=0 ttl=58 time=10.0 ms\n")
        let rHuge = parser.consume(chunk: "64 bytes from 1.1.1.1: icmp_seq=500 ttl=58 time=12.0 ms\n")

        // 10 capped missing failures + 1 success = 11 items
        #expect(rHuge.count == 11)
        #expect(rHuge.prefix(10).allSatisfy { !$0.success })
        #expect(rHuge.last?.success == true)
    }

    @Test("Sequence reset does not trigger gap failures")
    func testSequenceReset() {
        var parser = PingOutputParser()

        _ = parser.consume(chunk: "64 bytes from 1.1.1.1: icmp_seq=10 ttl=58 time=10.0 ms\n")
        parser.reset()

        let rReset = parser.consume(chunk: "64 bytes from 1.1.1.1: icmp_seq=0 ttl=58 time=12.0 ms\n")
        #expect(rReset.count == 1)
        #expect(rReset[0].success == true)
    }
}
