import Foundation

/// Fixed-capacity ring buffer. Oldest elements are overwritten when full.
struct RingBuffer<T> {
    private var storage: [T]
    private var writeIndex = 0
    private(set) var count = 0
    let capacity: Int

    init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.storage = Array(repeating: defaultValue, count: capacity)
    }

    /// Push a new element, overwriting the oldest if full.
    mutating func push(_ element: T) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    /// Access elements in order from oldest (0) to newest (count-1).
    subscript(index: Int) -> T {
        precondition(index >= 0 && index < count)
        let start = count < capacity ? 0 : writeIndex
        return storage[(start + index) % capacity]
    }

    /// Return all elements in order from oldest to newest.
    var array: [T] {
        guard count > 0 else { return [] }
        let start = count < capacity ? 0 : writeIndex
        var result = [T]()
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(storage[(start + i) % capacity])
        }
        return result
    }

    /// Iterate elements oldest-to-newest without allocating a copy.
    func forEach(_ body: (Int, T) -> Void) {
        let start = count < capacity ? 0 : writeIndex
        for i in 0..<count {
            body(i, storage[(start + i) % capacity])
        }
    }

    /// Remove all elements, keeping capacity.
    mutating func reset(defaultValue: T) {
        storage = Array(repeating: defaultValue, count: capacity)
        writeIndex = 0
        count = 0
    }
}
