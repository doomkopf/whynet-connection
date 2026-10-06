import Testing

@testable import WhynetConnection

struct connectionTests {
    @Test
    func testStringToTerminatedBuffer() throws {
        let buf = stringToTerminatedBuffer("teøst")

        #expect(buf.readableBytes == 7)
        #expect(buf.getNullTerminatedString(at: 0) == "teøst")
    }
}
