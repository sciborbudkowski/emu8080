import Foundation

class Memory {
    var ram: [UInt8]

    init(size: Int) {
        self.ram = Array(repeating: UInt8(0), count: size)
    }
}

class I8080 {
    var memory: Memory

    init(memory capacity: Int) {
        memory = Memory(size: capacity)
    }

    func readByte(address: UInt16) -> UInt8 {
        return memory.ram[address.asInt()]
    }

    func writeByte(address: UInt16, value: UInt8) {
        memory.ram[address.asInt()] = value
    }

    func readWord(address: UInt16) -> UInt16 {
        let high: UInt16 = UInt16(readByte(address: address + 1))
        let low: UInt16 = UInt16(readByte(address: address))
        return high << 8 | low
    }

    func writeWord(address: UInt16, value: UInt16) {
        writeByte(address: address, value: UInt8(value & 0xFF))
        writeByte(address: address + 1, value: UInt8(value >> 8))
    }

    func portIn(port: UInt8) -> UInt8 {
        return 0
    }

    func portOut(port: UInt8, value: UInt8) {
        if port == 0 {
            print("test finished")
        } else if port == 1 {
            let operation: UInt8 = registers.c

            if operation == 2 {
                print("\(registers.e)")
            } else if operation == 9 {
                let high: UInt16 = UInt16(registers.d)
                let low: UInt16 = UInt16(registers.e)
                var address = high << 8 | low
                var data: Data = Data()
                repeat {
                    let c = readByte(address: address)
                    data.append(c)
                    address += 1
                } while readByte(address: address) != 0x24 // "$"
                print(String(data: data, encoding: .ascii) ?? "no data")
            }

        }
    }

    var cycleCounter: UInt32 = 0

    var pc: UInt16 = 0
    var sp: UInt16 = 0

    struct Registers {
        var a: UInt8 = 0
        var b: UInt8 = 0
        var c: UInt8 = 0
        var d: UInt8 = 0
        var e: UInt8 = 0
        var h: UInt8 = 0
        var l: UInt8 = 0
    }
    var registers = Registers()

    struct Flags {
        var sf: Bool = false
        var zf: Bool = false
        var hf: Bool = false
        var pf: Bool = false
        var cf: Bool = false
        var iff: Bool = false
    }
    var flags = Flags()

    var halted: Bool = true

    var interruptPending: Bool = true
    var interruptVector: UInt8 = 0
    var interruptDelay: UInt8 = 0

    func reset() {
        cycleCounter = 0

        pc = 0
        sp = 0

        registers.a = 0
        registers.b = 0
        registers.c = 0
        registers.d = 0
        registers.e = 0
        registers.h = 0
        registers.l = 0

        flags.sf = false
        flags.zf = false
        flags.hf = false
        flags.pf = false
        flags.cf = false
        flags.iff = false

        halted = false
        interruptPending = false
        interruptVector = 0
        interruptDelay = 0
    }

    func step() {
        if interruptPending && flags.iff && interruptDelay == 0 {
            interruptPending = false
            flags.iff = false
            halted = false
            execute(opcode: interruptVector)
        } else if (!halted) {
            execute(opcode: nextByte())
        }
    }

    func interrupt(opcode: UInt8) {
        interruptPending = true
        interruptVector = opcode
    }

    func debugOutput() {
        let stringPc = String(pc, radix: 16)
        
        var f: UInt8 = 0
        f |= flags.sf.asUInt8() << 7
        f |= flags.zf.asUInt8() << 6
        f |= flags.hf.asUInt8() << 4
        f |= flags.pf.asUInt8() << 2
        f |= 1 << 1
        f |= flags.cf.asUInt8() << 0

        let curPc = pc

        let hex0 = String(readByte(address: curPc), radix: 16)
        let hex1 = String(readByte(address: curPc + 1), radix: 16)
        let hex2 = String(readByte(address: curPc + 2), radix: 16)
        let hex3 = String(readByte(address: curPc + 3), radix: 16)
        let flagValues = "\(flags.cf.asInt()) \(flags.hf.asInt()) \(flags.iff.asInt()) \(flags.pf.asInt()) \(flags.sf.asInt()) \(flags.zf.asInt())"

        print("PC: \(stringPc), AF: \(registers.a << 8 | f), BC: \(bc), DE: \(de), HL: \(hl), SP: \(sp), CYCLES: \(cycleCounter) (\(hex0), \(hex1), \(hex2), \(hex3)) [\(flagValues)] - \(OPCODES[readByte(address: curPc)])")
    }

    func execute(opcode: UInt8) {
        let cycles = OPCODE_CYCLES[opcode]
        cycleCounter += UInt32(cycles)

        switch(opcode) {
        case 0x7F: registers.a = registers.a; break // MOV A,A
        case 0x78: registers.a = registers.b; break // MOV A,B
        case 0x79: registers.a = registers.c; break // MOV A,C
        case 0x7A: registers.a = registers.d; break // MOV A,D
        case 0x7B: registers.a = registers.e; break // MOV A,E
        case 0x7C: registers.a = registers.h; break // MOV A,H
        case 0x7D: registers.a = registers.l; break // MOV A,L
        case 0x7E: registers.a = readByte(address: hl); break // MOV A,MEM

        case 0x0A: registers.a = readByte(address: bc); break // LDAX B
        case 0x1A: registers.a = readByte(address: de); break // LDAX D
        case 0x3A: registers.a = readByte(address: nextWord()); break // LDA word

        case 0x47: registers.b = registers.a; break // MOV B,A
        case 0x40: registers.b = registers.b; break // MOV B,B
        case 0x41: registers.b = registers.c; break // MOV B,C
        case 0x42: registers.b = registers.d; break // MOV B,D
        case 0x43: registers.b = registers.e; break // MOV B,E
        case 0x44: registers.b = registers.h; break // MOV B,H
        case 0x45: registers.b = registers.l; break // MOV B,L
        case 0x46: registers.b = readByte(address: hl); break // MOV B,MEM

        case 0x4F: registers.c = registers.a; break // MOV B,A
        case 0x48: registers.c = registers.b; break // MOV B,B
        case 0x49: registers.c = registers.c; break // MOV B,C
        case 0x4A: registers.c = registers.d; break // MOV B,D
        case 0x4B: registers.c = registers.e; break // MOV B,E
        case 0x4C: registers.c = registers.h; break // MOV B,H
        case 0x4D: registers.c = registers.l; break // MOV B,L
        case 0x4E: registers.c = readByte(address: hl); break // MOV B,MEM

        case 0x57: registers.d = registers.a; break // MOV B,A
        case 0x50: registers.d = registers.b; break // MOV B,B
        case 0x51: registers.d = registers.c; break // MOV B,C
        case 0x52: registers.d = registers.d; break // MOV B,D
        case 0x53: registers.d = registers.e; break // MOV B,E
        case 0x54: registers.d = registers.h; break // MOV B,H
        case 0x55: registers.d = registers.l; break // MOV B,L
        case 0x56: registers.d = readByte(address: hl); break // MOV B,MEM

        case 0x5F: registers.e = registers.a; break // MOV B,A
        case 0x58: registers.e = registers.b; break // MOV B,B
        case 0x59: registers.e = registers.c; break // MOV B,C
        case 0x5A: registers.e = registers.d; break // MOV B,D
        case 0x5B: registers.e = registers.e; break // MOV B,E
        case 0x5C: registers.e = registers.h; break // MOV B,H
        case 0x5D: registers.e = registers.l; break // MOV B,L
        case 0x5E: registers.e = readByte(address: hl); break // MOV B,MEM

        case 0x67: registers.h = registers.a; break // MOV B,A
        case 0x60: registers.h = registers.b; break // MOV B,B
        case 0x61: registers.h = registers.c; break // MOV B,C
        case 0x62: registers.h = registers.d; break // MOV B,D
        case 0x63: registers.h = registers.e; break // MOV B,E
        case 0x64: registers.h = registers.h; break // MOV B,H
        case 0x65: registers.h = registers.l; break // MOV B,L
        case 0x66: registers.h = readByte(address: hl); break // MOV B,MEM

        case 0x6F: registers.l = registers.a; break // MOV B,A
        case 0x68: registers.l = registers.b; break // MOV B,B
        case 0x69: registers.l = registers.c; break // MOV B,C
        case 0x6A: registers.l = registers.d; break // MOV B,D
        case 0x6B: registers.l = registers.e; break // MOV B,E
        case 0x6C: registers.l = registers.h; break // MOV B,H
        case 0x6D: registers.l = registers.l; break // MOV B,L
        case 0x6E: registers.l = readByte(address: hl); break // MOV B,MEM

        case 0x77: writeByte(address: hl, value: registers.a); break // MOV MEM,A
        case 0x70: writeByte(address: hl, value: registers.b); break // MOV MEM,B
        case 0x71: writeByte(address: hl, value: registers.c); break // MOV MEM,C
        case 0x72: writeByte(address: hl, value: registers.d); break // MOV MEM,D
        case 0x73: writeByte(address: hl, value: registers.e); break // MOV MEM,E
        case 0x74: writeByte(address: hl, value: registers.h); break // MOV MEM,H
        case 0x75: writeByte(address: hl, value: registers.l); break // MOV MEM,L

        case 0x3E: registers.a = nextByte(); break // MVI A,byte
        case 0x06: registers.b = nextByte(); break // MVI B,byte
        case 0x0E: registers.c = nextByte(); break // MVI C,byte
        case 0x16: registers.d = nextByte(); break // MVI D,byte
        case 0x1E: registers.e = nextByte(); break // MVI E,byte
        case 0x26: registers.h = nextByte(); break // MVI H,byte
        case 0x2E: registers.l = nextByte(); break // MVI L,byte
        case 0x36: writeByte(address: hl, value: nextByte()); break // MVI MEM,byte

        case 0x02: writeByte(address: bc, value: registers.a); break // STAX B
        case 0x12: writeByte(address: de, value: registers.a); break // STAX D
        case 0x32: writeByte(address: nextWord(), value: registers.a); break // STA word

        case 0x01: bc = nextWord(); break // LXI B,word
        case 0x11: de = nextWord(); break // LXI D,word
        case 0x21: hl = nextWord(); break // LXI H,word
        case 0x31: sp = nextWord(); break // LXI SP,word
        case 0x2A: hl = readWord(address: nextWord()); break // LHLD
        case 0x22: writeWord(address: nextWord(), value: hl); break // SHLD
        case 0xF9: sp = hl // SPHL

        case 0xEB: xchg(); break // XCHG
        case 0xE3: xthl(); break // XTHL

        case 0x87: add(register: registers.a, value: registers.a, cy: false); break // ADD A
        case 0x80: add(register: registers.a, value: registers.b, cy: false); break // ADD B
        case 0x81: add(register: registers.a, value: registers.c, cy: false); break // ADD C
        case 0x82: add(register: registers.a, value: registers.d, cy: false); break // ADD D
        case 0x83: add(register: registers.a, value: registers.e, cy: false); break // ADD E
        case 0x84: add(register: registers.a, value: registers.h, cy: false); break // ADD H
        case 0x85: add(register: registers.a, value: registers.l, cy: false); break // ADD L
        case 0x86: add(register: registers.a, value: readByte(address: hl), cy: false); break // ADD mem
        case 0xC6: add(register: registers.a, value: nextByte(), cy: false); break // ADI byte

        case 0x8F: add(register: registers.a, value: registers.a, cy: flags.cf); break // ADC A
        case 0x88: add(register: registers.a, value: registers.b, cy: flags.cf); break // ADC B
        case 0x89: add(register: registers.a, value: registers.c, cy: flags.cf); break // ADC C
        case 0x8A: add(register: registers.a, value: registers.d, cy: flags.cf); break // ADC D
        case 0x8B: add(register: registers.a, value: registers.e, cy: flags.cf); break // ADC E
        case 0x8C: add(register: registers.a, value: registers.h, cy: flags.cf); break // ADC H
        case 0x8D: add(register: registers.a, value: registers.l, cy: flags.cf); break // ADC L
        case 0x8E: add(register: registers.a, value: readByte(address: hl), cy: flags.cf); break // ADC MEM
        case 0xCE: add(register: registers.a, value: nextByte(), cy: flags.cf); break // ACI byte

        case 0x97: sub(register: registers.a, value: registers.a, cy: false); break // SUB A
        case 0x90: sub(register: registers.a, value: registers.b, cy: false); break // SUB B
        case 0x91: sub(register: registers.a, value: registers.c, cy: false); break // SUB C
        case 0x92: sub(register: registers.a, value: registers.d, cy: false); break // SUB D
        case 0x93: sub(register: registers.a, value: registers.e, cy: false); break // SUB E
        case 0x94: sub(register: registers.a, value: registers.h, cy: false); break // SUB H
        case 0x95: sub(register: registers.a, value: registers.l, cy: false); break // SUB L
        case 0x96: sub(register: registers.a, value: readByte(address: hl), cy: false); break // SUB MEM
        case 0xD6: sub(register: registers.a, value: nextByte(), cy: false); break // SUI byte

        case 0x9F: sub(register: registers.a, value: registers.a, cy: flags.cf); break // SBB A
        case 0x98: sub(register: registers.a, value: registers.b, cy: flags.cf); break // SBB B
        case 0x99: sub(register: registers.a, value: registers.c, cy: flags.cf); break // SBB C
        case 0x9A: sub(register: registers.a, value: registers.d, cy: flags.cf); break // SBB D
        case 0x9B: sub(register: registers.a, value: registers.e, cy: flags.cf); break // SBB E
        case 0x9C: sub(register: registers.a, value: registers.h, cy: flags.cf); break // SBB H
        case 0x9D: sub(register: registers.a, value: registers.l, cy: flags.cf); break // SBB L
        case 0x9E: sub(register: registers.a, value: readByte(address: hl), cy: flags.cf); break // SBB MEM
        case 0xDE: sub(register: registers.a, value: nextByte(), cy: flags.cf); break // SBI byte

        case 0x09: dad(value: bc); break // DAD B
        case 0x19: dad(value: de); break // DAD D
        case 0x29: dad(value: hl); break // DAD H
        case 0x39: dad(value: sp); break // DAD SP

        case 0xF3: flags.iff = false; break // DI
        case 0xFB: flags.iff = true; interruptDelay = 1; break // EI
        case 0x00: break // NOP
        case 0x76: halted = true; break // HLT

        case 0x3C: registers.a = inc(value: registers.a); break // INC A
        case 0x04: registers.b = inc(value: registers.b); break // INC B
        case 0x0C: registers.c = inc(value: registers.c); break // INC C
        case 0x14: registers.d = inc(value: registers.d); break // INC D
        case 0x1C: registers.e = inc(value: registers.e); break // INC E
        case 0x24: registers.h = inc(value: registers.h); break // INC H
        case 0x2C: registers.l = inc(value: registers.l); break // INC L
        case 0x34: writeByte(address: hl, value: inc(value: readByte(address: hl))); break // INC MEM

        case 0x3D: registers.a = dec(value: registers.a); break // DEC A
        case 0x05: registers.b = dec(value: registers.b); break // DEC B
        case 0x0D: registers.c = dec(value: registers.c); break // DEC C
        case 0x15: registers.d = dec(value: registers.d); break // DEC D
        case 0x1D: registers.e = dec(value: registers.e); break // DEC E
        case 0x25: registers.h = dec(value: registers.h); break // DEC H
        case 0x2D: registers.l = dec(value: registers.l); break // DEC L
        case 0x35: writeByte(address: hl, value: dec(value: readByte(address: hl))); break // DEC MEM

        case 0x03: bc += 1; break // INX B
        case 0x13: de += 1; break // INX D
        case 0x23: hl += 1; break // INX H
        case 0x33: sp += 1; break // INX SP

        case 0x0B: bc -= 1; break // DCX B
        case 0x1B: de -= 1; break // DCX D
        case 0x2B: hl -= 1; break // DCX H
        case 0x3B: sp -= 1; break // DCX SP

        case 0x27: daa(); break // DAA
        case 0x2F: registers.a = ~registers.a; break // CMA
        case 0x37: flags.cf = true; break // STC
        case 0x3F: flags.cf.toggle(); break // CMC

        case 0x07: rlc(); break // RLC
        case 0x0F: rrc(); break // RRC
        case 0x17: ral(); break // RAL
        case 0x1F: rar(); break // RAR

        case 0xA7: anda(value: registers.a); break // ANA A
        case 0xA0: anda(value: registers.b); break // ANA B
        case 0xA1: anda(value: registers.c); break // ANA C
        case 0xA2: anda(value: registers.d); break // ANA D
        case 0xA3: anda(value: registers.e); break // ANA E
        case 0xA4: anda(value: registers.h); break // ANA H
        case 0xA5: anda(value: registers.l); break // ANA L
        case 0xA6: anda(value: readByte(address: hl)); break  // ANA MEM
        case 0xE6: anda(value: nextByte()); break // ANI byte

        case 0xAF: xora(value: registers.a); break // XRA A
        case 0xA8: xora(value: registers.b); break // XRA B
        case 0xA9: xora(value: registers.c); break // XRA C
        case 0xAA: xora(value: registers.d); break // XRA D
        case 0xAB: xora(value: registers.e); break // XRA E
        case 0xAC: xora(value: registers.h); break // XRA H
        case 0xAD: xora(value: registers.l); break // XRA L
        case 0xAE: xora(value: readByte(address: hl)); break // XRA MEM
        case 0xEE: xora(value: nextByte()); break // XRI byte

        case 0xB7: ora(value: registers.a); break // ORA A
        case 0xB0: ora(value: registers.b); break // ORA B
        case 0xB1: ora(value: registers.c); break // ORA C
        case 0xB2: ora(value: registers.d); break // ORA D
        case 0xB3: ora(value: registers.e); break // ORA E
        case 0xB4: ora(value: registers.h); break // ORA H
        case 0xB5: ora(value: registers.l); break // ORA L
        case 0xB6: ora(value: readByte(address: hl)); break // ORA MEM
        case 0xF6: ora(value: nextByte()); break // ORI byte

        case 0xBF: cmp(value: registers.a); break // CMP A
        case 0xB8: cmp(value: registers.b); break // CMP B
        case 0xB9: cmp(value: registers.c); break // CMP C
        case 0xBA: cmp(value: registers.d); break // CMP D
        case 0xBB: cmp(value: registers.e); break // CMP E
        case 0xBC: cmp(value: registers.h); break // CMP H
        case 0xBD: cmp(value: registers.l); break // CMP L
        case 0xBE: cmp(value: readByte(address: hl)); break // CMP MEM
        case 0xFE: cmp(value: nextByte()); break // CPI byte

        case 0xC3: jump(address: nextWord()); break // JMP
        case 0xC2: conditionalJump(condition: flags.zf == false); break // JNZ
        case 0xCA: conditionalJump(condition: flags.zf == true); break // JZ
        case 0xD2: conditionalJump(condition: flags.cf == false); break // JNC
        case 0xDA: conditionalJump(condition: flags.cf == true); break // JC
        case 0xE2: conditionalJump(condition: flags.pf == false); break // JPO
        case 0xEA: conditionalJump(condition: flags.pf == true); break // JPE
        case 0xF2: conditionalJump(condition: flags.sf == false); break // JP
        case 0xFA: conditionalJump(condition: flags.sf == true); break // JM

        case 0xE9: pc = hl; break // PCHL

        case 0xCD: call(address: nextWord()); break // CALL
        case 0xC4: conditionalCall(condition: flags.zf == false); break // CNZ
        case 0xCC: conditionalCall(condition: flags.zf == true); break // CZ
        case 0xD4: conditionalCall(condition: flags.cf == false); break // CNC
        case 0xDC: conditionalCall(condition: flags.cf == true); break // CC
        case 0xE4: conditionalCall(condition: flags.pf == false); break // CPO
        case 0xEC: conditionalCall(condition: flags.pf == true); break // CPE
        case 0xF4: conditionalCall(condition: flags.sf == false); break // CP
        case 0xFC: conditionalCall(condition: flags.sf == true); break // CM

        case 0xC9: ret(); break // RET
        case 0xC0: conditionalRet(condition: flags.zf == false); break //RNZ
        case 0xC8: conditionalRet(condition: flags.zf == true); break // RZ
        case 0xD0: conditionalRet(condition: flags.cf == false); break //RNC
        case 0xD8: conditionalRet(condition: flags.cf == true); break // RC
        case 0xE0: conditionalRet(condition: flags.pf == false); break // RPO
        case 0xE8: conditionalRet(condition: flags.pf == true); break // RPE
        case 0xF0: conditionalRet(condition: flags.sf == false); break // RP
        case 0xF8: conditionalRet(condition: flags.sf == true); break // RM

        case 0xC7: call(address: 0x00); break // RST 0
        case 0xCF: call(address: 0x08); break // RST 1
        case 0xD7: call(address: 0x10); break // RST 2
        case 0xDF: call(address: 0x18); break // RST 3
        case 0xE7: call(address: 0x20); break // RST 4
        case 0xEF: call(address: 0x28); break // RST 5
        case 0xF7: call(address: 0x30); break // RST 6
        case 0xFF: call(address: 0x38); break // RST 7

        case 0xC5: push(value: bc); break // PUSH B
        case 0xD5: push(value: de); break // PUSH D
        case 0xE5: push(value: hl); break // PUSH H
        case 0xF5: pushf(); break // PUSH PSW
        case 0xC1: bc = pop(); break // POP B
        case 0xD1: de = pop(); break // POP D
        case 0xE1: hl = pop(); break // POP H
        case 0xF1: popf(); break // POP PSW

        case 0xDB: registers.a = portIn(port: nextByte()); break // IN
        case 0xD3: portOut(port: nextByte(), value: registers.a)

        case 0x08: nop()
        case 0x10: nop()
        case 0x18: nop()
        case 0x20: nop()
        case 0x28: nop()
        case 0x30: nop()
        case 0x38: break // undocumented NOPs

        case 0xD9: ret(); break // undocumented RET

        case 0xDD: nop()
        case 0xED: nop()
        case 0xFD: call(address: nextWord()); break // undocumented CALLs
        case 0xCB: jump(address: nextWord()); break // undocumented JMP

        default: break
        }
    }

    func nop() {}

    var hl: UInt16 {
        get { return (UInt16(registers.h) << 8) | UInt16(registers.l) }
        set {
            registers.h = UInt8(newValue >> 8)
            registers.l = UInt8(newValue & 0xFF)
        }
    }

    var bc: UInt16 {
        get { return (UInt16(registers.b) << 8) | UInt16(registers.e) }
        set {
            registers.b = UInt8(newValue >> 8)
            registers.c = UInt8(newValue & 0xFF)
        }
    }

    var de: UInt16 {
        get { return (UInt16(registers.d) << 8) | UInt16(registers.l) }
        set {
            registers.d = UInt8(newValue >> 8)
            registers.e = UInt8(newValue & 0xFF)
        }
    }

    func nextByte() -> UInt8 {
        let value = readByte(address: pc)
        pc += 1
        return value
    }

    func nextWord() -> UInt16 {
        let value = readWord(address: pc)
        pc += 2
        return value
    }

    func xchg() {
        let old: UInt16 = de
        de = hl
        hl = old
    }

    func xthl() {
        let val: UInt16 = readWord(address: sp)
        writeWord(address: sp, value: hl)
        hl = val
    }

    func carry(bit: Int, a: UInt8, b: UInt8, cy: Bool) -> Bool {
        let cyy: UInt16 = cy == true ? 1 : 0
        let result: UInt16 = UInt16(a) + UInt16(b) + cyy
        let carry: UInt16 = result ^ UInt16(a) ^ UInt16(b)
        return carry & (1 << bit) == 0 ? false : true
    }

    func add(register: UInt8, value: UInt8, cy: Bool) {
        let cyy: UInt8 = cy == true ? 1 : 0
        print(UInt16(register &+ value &+ cyy))
        let result = register &+ value &+ cyy
        flags.cf = carry(bit: 8, a: registers.a, b: value, cy: cy)
        flags.hf = carry(bit: 4, a: registers.a, b: value, cy: cy)
        zsp(value: result)
        registers.a = result
    }

    func sub(register: UInt8, value: UInt8, cy: Bool) {
        add(register: register, value: ~value, cy: !flags.cf)
        flags.cf = !flags.cf
    }

    func dad(value: UInt16) {
        flags.cf = (hl + value >> 16) & 1 == 0 ? true : false
        hl += value
    }

    func inc(value: UInt8) -> UInt8 {
        let result: UInt8 = value + 1
        flags.hf = (result & 0xF) == 0
        zsp(value: result)
        return result
    }

    func dec(value: UInt8) -> UInt8 {
        let result: UInt8 = value - 1
        flags.hf = !((result & 0xF) == 0xF)
        zsp(value: result)
        return result
    }

    func anda(value: UInt8) {
        let result: UInt8 = registers.a & value
        flags.cf = false
        flags.hf = ((registers.a | value) & 0x08) != 0
        zsp(value: result)
        registers.a = result
    }

    func xora(value: UInt8) {
        registers.a ^= value
        flags.cf = false
        flags.hf = false
        zsp(value: registers.a)
    }

    func ora(value: UInt8) {
        registers.a |= value
        flags.cf = false
        flags.hf = false
        zsp(value: registers.a)
    }

    func cmp(value: UInt8) {
        //let result: UInt8 = registers.a &- value
        let result: Int16 = Int16(registers.a) - Int16(value)
        print(result)
        flags.cf = result >> 8 == 0 ? false : true
        flags.hf = ~(Int16(registers.a) ^ result ^ Int16(value)) & 0x10 == 0 ? false : true
        zsp(value: result & 0xFF)
    }

    func jump(address: UInt16) {
        pc = address
    }

    func conditionalJump(condition: Bool) {
        let address: UInt16 = nextWord()
        if(condition) {
            pc = address
        }
    }

    func call(address: UInt16) {
        push(value: pc)
        jump(address: address)
    }

    func conditionalCall(condition: Bool) {
        let address: UInt16 = nextWord()
        if(condition) {
            call(address: address)
            cycleCounter += 6
        }
    }

    func ret() {
        pc = pop()
    }

    func conditionalRet(condition: Bool) {
        if(condition) {
            ret()
            cycleCounter += 6
        }
    }

    func zsp(value: UInt8) {
        repeat {
            flags.zf = value == 0
            flags.sf = value >> 7 == 0 ? false : true
            flags.pf = parity(value: value)
        } while(false)
    }

    func zsp(value: Int16) {
        repeat {
            flags.zf = value == 0
            flags.sf = value >> 7 == 0 ? false : true
            flags.pf = parity(value: value)
        } while(false)
    }

    func parity(value: UInt8) -> Bool {
        var b: UInt8 = 0
        for i in 0..<8 {
            b += ((value >> i) & 1)
        }
        return (b & 1) == 0
    }

    func parity(value: Int16) -> Bool {
        var b: Int16 = 0
        for i in 0..<8 {
            b += ((value >> i) & 1)
        }
        return (b & 1) == 0
    }

    func push(value: UInt16) {
        sp -= 2
        writeWord(address: sp, value: value)
    }

    func pushf() {
        var psw: UInt8 = 0
        psw |= flags.sf.asUInt8() << 7
        psw |= flags.zf.asUInt8() << 6
        psw |= flags.hf.asUInt8() << 4
        psw |= flags.pf.asUInt8() << 2
        psw |= 1 << 1
        psw |= flags.cf.asUInt8() << 0
        push(value: UInt16(registers.a) << 8 | UInt16(psw))
    }

    func popf() {
        let af: UInt16 = pop()
        registers.a = UInt8(af >> 8)
        let psw: UInt8 = UInt8(af & 0xFF)

        flags.sf = (psw >> 7) & 1 == 0 ? true : false
        flags.zf = (psw >> 6) & 1 == 0 ? true : false
        flags.hf = (psw >> 4) & 1 == 0 ? true : false
        flags.pf = (psw >> 3) & 1 == 0 ? true : false
        flags.cf = (psw >> 0) & 1 == 0 ? true : false
    }

    func pop() -> UInt16 {
        let result: UInt16 = readWord(address: sp)
        sp += 2
        return result
    }

    func daa() {
        var cy: Bool = flags.cf
        var correction: UInt8 = 0

        let lsb: UInt8 = registers.a & 0x0F
        let msb: UInt8 = registers.a >> 4

        if flags.hf || lsb > 9 {
            correction += 0x06
        }

        if flags.cf || msb > 9 || (msb >= 9 && lsb > 9) {
            correction += 0x60
            cy = true
        }

        add(register: registers.a, value: correction, cy: false)
        flags.cf = cy
    }

    func rlc() {
        flags.cf = registers.a >> 7 == 0 ? true : false
        registers.a = (registers.a << 1) | flags.cf.asUInt8()
    }

    func rrc() {
        flags.cf = registers.a & 1 == 0 ? true : false
        registers.a = (registers.a >> 1) | (flags.cf.asUInt8() << 7)
    }

    func ral() {
        let cy: Bool = flags.cf
        flags.cf = registers.a >> 7 == 0 ? true : false
        registers.a = (registers.a << 1) | cy.asUInt8()
    }

    func rar() {
        let cy: Bool = flags.cf
        flags.cf = registers.a & 1 == 0 ? true : false
        registers.a = (registers.a >> 1) | (cy.asUInt8() << 7)
    }
}
