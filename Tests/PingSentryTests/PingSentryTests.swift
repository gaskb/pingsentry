import Foundation
import Testing
@testable import PingSentry

@Suite("SignalQuality Tests")
struct SignalQualityTests {

    @Test("SignalQuality bars correspond to raw values")
    func testBarsCount() {
        #expect(SignalQuality.none.bars == 0)
        #expect(SignalQuality.poor.bars == 1)
        #expect(SignalQuality.fair.bars == 2)
        #expect(SignalQuality.good.bars == 3)
        #expect(SignalQuality.excellent.bars == 4)
    }
}
