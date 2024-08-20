//
//  Assembly.swift
//  nqc
//
//  Created by Edward Kish on 8/16/24.
//

import Foundation

enum AssemblyError: Error {
    case wrongValueType(found: String)
}

protocol ASM {
    
    func emitCode() -> String
    
}

struct ASMProgram: ASM {
    var function: ASMFunction
    func emitCode() -> String {
        return function.emitCode()
    }
}

struct ASMFunction: ASM {
    var name: String
    var body: [ASMInstruction]
    func emitCode() -> String {
        var output = "\t.globl _\(name)\n"
        output += "_\(name):\n"
        output += "\tpushq" + "\t" + "%rbp\n"
        output += "\tmovq" + "\t" + "%rsp," + "\t" + "%rbp\n"
        for instr in body {
            output += "\t" + instr.emitCode() + "\n"
        }
        return output
    }
}

protocol ASMInstruction: ASM {
    
}

struct ASMMovInstr: ASMInstruction {
    var src: ASMOperand
    var dst: ASMOperand
    
    func emitCode() -> String {
        return "movl" + "\t" + src.emitCode() + ", \t" + dst.emitCode()
    }
}

struct ASMUnaryInstr: ASMInstruction {
    var op: String
    var operand: ASMOperand
    
    let opmap = ["-": "negl", "~": "notl"]
    func emitCode() -> String {
        return opmap[op]! + "\t" + operand.emitCode()
    }
}

struct ASMAllocateStackInstr: ASMInstruction {
    var value: Int
    func emitCode() -> String {
        return "subq" + "\t" + "$\(value)," + "\t" + "%rsp"
    }
}

struct ASMReturnInstr: ASMInstruction {
    //var value: ASMOperand
    func emitCode() -> String {
        let line1 = "movq" + "\t" + "%rbp," + "\t" + "%rsp\n"
        let line2 = "\t" + "popq" + "\t" + "%rbp\n"
        let line3 = "\t" + "ret"
        return line1 + line2 + line3
    }
}

protocol ASMOperand: ASM {
    
}

struct ASMImm: ASMOperand {
    var value: Int
    func emitCode() -> String {
        return "$\(value)"
    }
}

struct ASMReg: ASMOperand {
    var register: String
    let reg_codes = ["AX": "%eax", "r10d": "%r10d"]
    func emitCode() -> String {
        return reg_codes[register]!
    }
}

struct ASMPseudo: ASMOperand {
    var identifier: String
    func emitCode() -> String {
        return "PSEUDO(\(identifier))"
    }
}

struct ASMStack: ASMOperand {
    var value: Int
    func emitCode() -> String {
        return "\(value)(%rbp)"
    }
}

func convertValue(tac: TACValue) throws -> ASMOperand {
    switch tac {
    case is TACConstant: 
        let v = tac as! TACConstant
        return ASMImm(value: v.value)
    case is TACVar:
        let v = tac as! TACVar
        return ASMPseudo(identifier: v.identifier)
    default:
        throw AssemblyError.wrongValueType(found: tac.toString())
    }
}


func convertInstruction(tac: TACInstruction) throws -> [ASMInstruction] {
    switch tac {
    case is TACReturnInstruction:
        let tac_v = tac as! TACReturnInstruction
        return [ASMMovInstr(src: try! convertValue(tac: tac_v.value), dst: ASMReg(register: "AX")), ASMReturnInstr()]
    case is TACUnaryInstruction:
        let tac_u = tac as! TACUnaryInstruction
        let src = try! convertValue(tac: tac_u.src)
        let dst = try! convertValue(tac: tac_u.dst)
        return [ASMMovInstr(src: src, dst: dst), ASMUnaryInstr(op: tac_u.op, operand: dst)]
    default:
        throw AssemblyError.wrongValueType(found: tac.toString())
    }
}

func emitAssembly(program: TACProgram) -> ASMProgram {
    let tacfun = program.function
    var asm_instr: [ASMInstruction] = []
    for instr in tacfun.body {
        asm_instr.append(contentsOf: try! convertInstruction(tac: instr))
    }
    asm_instr = replacePseudoRegisters(instructions: asm_instr)
    asm_instr = fixMovOperations(instructions: asm_instr)
    
    return ASMProgram(
        function: ASMFunction(
            name: tacfun.name, body: asm_instr))
}

func replacePseudoRegisters(instructions: [ASMInstruction]) -> [ASMInstruction] {
    var offset = -4
    var identifiers: [String: Int] = [:]
    var new_instr: [ASMInstruction] = []
    for instr in instructions {
        switch instr {
        case is ASMMovInstr:
            var mv = instr as! ASMMovInstr
            if mv.src is ASMPseudo {
                let oldsrc = mv.src as! ASMPseudo
                var newsrc: ASMStack
                if identifiers[oldsrc.identifier] == nil {
                    identifiers[oldsrc.identifier] = offset
                    offset -= 4
                }
                newsrc = ASMStack(value: identifiers[oldsrc.identifier]!)
                mv.src = newsrc
            }
            if mv.dst is ASMPseudo {
                let olddst = mv.dst as! ASMPseudo
                var newdst: ASMStack
                if identifiers[olddst.identifier] == nil {
                    identifiers[olddst.identifier] = offset
                    offset -= 4
                }
                newdst = ASMStack(value: identifiers[olddst.identifier]!)
                mv.dst = newdst
            }
            new_instr.append(mv)
        case is ASMAllocateStackInstr:
            new_instr.append(instr)
        case is ASMUnaryInstr:
            var unary = instr as! ASMUnaryInstr
            if unary.operand is ASMPseudo {
                let old = unary.operand as! ASMPseudo
                if identifiers[old.identifier] == nil {
                    identifiers[old.identifier] = offset
                    offset -= 4
                }
                unary.operand = ASMStack(value: identifiers[old.identifier]!)
            }
            new_instr.append(unary)
        case is ASMReturnInstr:
            var ret = instr as! ASMReturnInstr
            /*if ret.value is ASMPseudo {
                let old = ret.value as! ASMPseudo
                if identifiers[old.identifier] == nil {
                    identifiers[old.identifier] = offset
                    offset -= 4
                }
                ret.value = ASMStack(value: identifiers[old.identifier]!)
            }*/
            new_instr.append(ret)
        default:
            continue
        }
    }
    if offset + 4 != 0 {
        new_instr.insert(ASMAllocateStackInstr(value: 0 - (offset + 4)), at: 0)
    }
    return new_instr
}

func fixMovOperations(instructions: [ASMInstruction]) -> [ASMInstruction] {
    var new_instr: [ASMInstruction] = []
    for instr in instructions {
        switch instr {
        case is ASMMovInstr:
            let mv = instr as! ASMMovInstr
            if mv.src is ASMStack && mv.dst is ASMStack {
                new_instr.append(ASMMovInstr(src: mv.src, dst: ASMReg(register: "r10d")))
                new_instr.append(ASMMovInstr(src: ASMReg(register: "r10d"), dst: mv.dst))
            } else {
                new_instr.append(instr)
            }
        default:
            new_instr.append(instr)
        }
    }
    return new_instr
}
