import Foundation

class Machine {
    static let shared: Machine = Machine()
    static let cpu: I8080 = I8080(memory: 0x10000)

    static func loadBinaryFile(with name: String, to address: UInt16) {

        if let path = Bundle.main.path(forResource: name, ofType: "COM") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let byteArray = [UInt8](data)
                let arraySize = byteArray.count
                print("loaded \(arraySize) bytes")
                cpu.memory.initialize(repeating: 0, count: 0x10000)
                for index in 0..<arraySize {
                    let currentAddress = Int(address) + index
                    print("Inserting opcode \(byteArray[index]) into address \(currentAddress) which is \(OPCODES[byteArray[index]])")
                    cpu.memory[currentAddress] = byteArray[index]
                }
                sleep(1)
            } catch {
                print("Error reading file \(name)")
            }
        } else {
            print("File \(name) not found")
        }
    }

    static func test(filename: String, expectedCycles: UInt32) {
        cpu.reset()
        loadBinaryFile(with: filename, to: 0x100)
        print("*** TEST: \(filename)")

        cpu.pc = 0xFF

        cpu.memory[0x0000] = 0xD3
        cpu.memory[0x0001] = 0x00

        cpu.memory[0x0005] = 0xD3
        cpu.memory[0x0006] = 0x01
        cpu.memory[0x0007] = 0xC9

        var nbInstructions: UInt32 = 0
        var testFinished = false

        while(!testFinished) {
            nbInstructions += 1
            print("instructions executed: \(nbInstructions)")
            cpu.step() { test in
                print("test status: \(test)")
                if test {
                    testFinished = true
                }
            }
            sleep(1)
        }

        let diff = expectedCycles - nbInstructions
        print("\(nbInstructions) instructions executed on \(cpu.cycleCounter) cycles, diff=\(diff)")
    }
}
