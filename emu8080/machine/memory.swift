import Foundation

class Memory {
    var ram: [UInt8]

    init(size: Int) {
        self.ram = Array(repeating: UInt8(0), count: size)
    }
}
