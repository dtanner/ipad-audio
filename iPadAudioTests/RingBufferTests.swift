import XCTest
@testable import iPadAudio

final class RingBufferTests: XCTestCase {

    func testPushAndAccess() {
        var buf = RingBuffer<Int>(capacity: 4, defaultValue: 0)
        buf.push(1)
        buf.push(2)
        buf.push(3)

        XCTAssertEqual(buf.count, 3)
        XCTAssertEqual(buf[0], 1)
        XCTAssertEqual(buf[1], 2)
        XCTAssertEqual(buf[2], 3)
    }

    func testWrapsAroundWhenFull() {
        var buf = RingBuffer<Int>(capacity: 3, defaultValue: 0)
        buf.push(1)
        buf.push(2)
        buf.push(3)
        buf.push(4) // overwrites 1

        XCTAssertEqual(buf.count, 3)
        XCTAssertEqual(buf[0], 2)
        XCTAssertEqual(buf[1], 3)
        XCTAssertEqual(buf[2], 4)
    }

    func testArrayReturnsCorrectOrder() {
        var buf = RingBuffer<Int>(capacity: 3, defaultValue: 0)
        buf.push(10)
        buf.push(20)
        buf.push(30)
        buf.push(40)

        XCTAssertEqual(buf.array, [20, 30, 40])
    }

    func testArrayWhenNotFull() {
        var buf = RingBuffer<Int>(capacity: 5, defaultValue: 0)
        buf.push(1)
        buf.push(2)

        XCTAssertEqual(buf.array, [1, 2])
    }

    func testEmptyBuffer() {
        let buf = RingBuffer<Int>(capacity: 3, defaultValue: 0)
        XCTAssertEqual(buf.count, 0)
        XCTAssertEqual(buf.array, [])
    }

    func testReset() {
        var buf = RingBuffer<Int>(capacity: 3, defaultValue: 0)
        buf.push(1)
        buf.push(2)
        buf.push(3)

        buf.reset(defaultValue: 0)
        XCTAssertEqual(buf.count, 0)
        XCTAssertEqual(buf.array, [])
    }

    func testCapacityOne() {
        var buf = RingBuffer<Int>(capacity: 1, defaultValue: 0)
        buf.push(42)
        XCTAssertEqual(buf.count, 1)
        XCTAssertEqual(buf[0], 42)

        buf.push(99)
        XCTAssertEqual(buf.count, 1)
        XCTAssertEqual(buf[0], 99)
    }

    func testManyWrapArounds() {
        var buf = RingBuffer<Int>(capacity: 3, defaultValue: 0)
        for i in 0..<100 {
            buf.push(i)
        }
        XCTAssertEqual(buf.count, 3)
        XCTAssertEqual(buf.array, [97, 98, 99])
    }

    func testOptionalType() {
        var buf = RingBuffer<Double?>(capacity: 3, defaultValue: nil)
        buf.push(1.0)
        buf.push(nil)
        buf.push(3.0)

        XCTAssertEqual(buf.count, 3)
        XCTAssertEqual(buf[0], 1.0)
        XCTAssertNil(buf[1])
        XCTAssertEqual(buf[2], 3.0)
    }
}
