import Foundation

class Machine {
    
    static let shared: Machine = Machine()
    static let cpu: I8080 = I8080(memory: 0x10000)

    static func loadBinaryFile(with name: String, to address: UInt16, dumpMemory: Bool = false) {

        if let path = Bundle.main.path(forResource: name, ofType: "COM") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let byteArray = [UInt8](data)
                let arraySize = byteArray.count
                cpu.memory.ram.replaceSubrange(address.asInt()..<arraySize, with: byteArray)
            } catch {
                print("Error reading file \(name)")
            }
        } else {
            print("File \(name) not found")
        }
    }

    static func dumpMemory() {
        //print(cpu.memory.ram)
        cpu.memory.ram.forEach {
            print($0.asHex(), separator: ", ", terminator: ", ")
        }
    }

    static func test(filename: String, expectedCycles: UInt32) {
        cpu.reset()
        loadBinaryFile(with: filename, to: 0x100)
        print("*** TEST: \(filename)")

        cpu.pc = 0x100

        cpu.memory.ram[0x0000] = 0xD3
        cpu.memory.ram[0x0001] = 0x00

        cpu.memory.ram[0x0005] = 0xD3
        cpu.memory.ram[0x0006] = 0x01
        cpu.memory.ram[0x0007] = 0xC9

        var nbInstructions: UInt32 = 0

        while(true) {
            nbInstructions += 1
            cpu.step()
            cpu.debugOutput()
            sleep(1)
        }

        let diff = expectedCycles - nbInstructions
        print("\(nbInstructions) instructions executed on \(cpu.cycleCounter) cycles, diff=\(diff)")
    }
}
