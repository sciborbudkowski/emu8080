import Foundation

extension Array {
    subscript(i: UInt8) -> Element {
        get { return self[Int(i)] }
        set { self[Int(i)] = newValue }
    }

    subscript(i: UInt16) -> Element {
        get { return self[Int(i)] }
        set { self[Int(i)] = newValue }
    }
}

extension Bool {
    func asUInt8() -> UInt8 {
        return self ? UInt8(1) : UInt8(0)
    }
}

extension UInt16 {
    func asInt() -> Int {
        return Int(self)
    }
}
