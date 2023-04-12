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

    func asHex() -> String {
        if self < 10 {
            return "000" + String(self, radix: 16)
        }
        return String(self, radix: 16)
    }
}

extension UInt8 {
    func asHex() -> String {
        if self < 10 {
            return "0" + String(self, radix: 16)
        }
        return String(self, radix: 16)
    }
}

extension Bool {
    func asInt() -> Int {
        if self {
            return 1
        }
        return 0
    }
}
