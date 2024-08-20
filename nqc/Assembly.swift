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

struct ASMMovBInstr: ASMInstruction {
    var src: ASMOperand
    var dst: ASMOperand
    func emitCode() -> String {
        return "movb" + "\t" + src.emitCode() + ", \t" + dst.emitCode()
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

struct ASMBinaryInstruction: ASMInstruction {
    var src: ASMOperand
    var dst: ASMOperand
    var op: String
    let op_map = ["+": "addl", "-": "subl", "*": "imull", "&": "andl", "|": "orl ", "^": "xorl", "<<": "sall", ">>": "sarl"]
    func emitCode() -> String {
        let s = src.emitCode()
        let d = dst.emitCode()
        return op_map[op]! + "\t\(s),\t\(d)"
    }
}

struct ASMIdivInstruction: ASMInstruction {
    var operand: ASMOperand
    
    func emitCode() -> String {
        return "idivl" + "\t" + operand.emitCode()
    }
}

struct ASMCdqInstruction: ASMInstruction {
    func emitCode() -> String {
        return "cdq"
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
    let reg_codes = ["AX": "%eax", "r10d": "%r10d", "DX": "%edx", "CL": "%cl", "r11d" : "%r10d"]
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
    case is TACBinaryInstruction:
        let tac_b = tac as! TACBinaryInstruction
        let src1 = try! convertValue(tac: tac_b.src1)
        let src2 = try! convertValue(tac: tac_b.src2)
        let dst = try! convertValue(tac: tac_b.dst)
        if tac_b.op == "+" || tac_b.op == "-" || tac_b.op == "*" || tac_b.op == "&" || tac_b.op == "|" || tac_b.op == "^" || tac_b.op == "<<" || tac_b.op == ">>" {
            return [ASMMovInstr(src: src1, dst: dst), ASMBinaryInstruction(src: src2, dst: dst, op: tac_b.op)]
        } else if tac_b.op == "/"{
            return [
                ASMMovInstr(src: src1, dst: ASMReg(register: "AX")),
                ASMCdqInstruction(),
                ASMIdivInstruction(operand: src2),
                ASMMovInstr(src: ASMReg(register: "AX"), dst: dst)
            ]
        } else if tac_b.op == "%" {
            return [
                ASMMovInstr(src: src1, dst: ASMReg(register: "AX")),
                ASMCdqInstruction(),
                ASMIdivInstruction(operand: src2),
                ASMMovInstr(src: ASMReg(register: "DX"), dst: dst)
            ]
        } else {
            throw AssemblyError.wrongValueType(found: tac_b.op)
        }
    default:
        throw AssemblyError.wrongValueType(found: tac.toString())
    }
}

func emitAssembly(program: TACProgram) -> ASMProgram {
    let tacfun = program.function
    var asm_instr: [ASMInstruction] = []
    for instr in tacfun.body {
        asm_instr.append(contentsOf: try! convertInstruction(tac: instr))
    }/*
    print("=====First Pass ASM")
    for instr in asm_instr{
        print(instr.emitCode())
    }
    print("=====Replace Pseudo")*/
    asm_instr = replacePseudoRegisters(instructions: asm_instr)
    //for instr in asm_instr{
    //    print(instr.emitCode())
    //}
    //print("=====Final Pass")
    asm_instr = fixInvalidInstructions(instructions: asm_instr)
    //for instr in asm_instr{
    //    print(instr.emitCode())
    //}
    
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
            let ret = instr as! ASMReturnInstr
            new_instr.append(ret)
        case is ASMBinaryInstruction:
            var binary = instr as! ASMBinaryInstruction
            if binary.src is ASMPseudo {
                let old1 = binary.src as! ASMPseudo
                if identifiers[old1.identifier] == nil {
                    identifiers[old1.identifier] = offset
                    offset -= 4
                }
                binary.src = ASMStack(value: identifiers[old1.identifier]!)
            }
            if binary.dst is ASMPseudo {
                let old2 = binary.dst as! ASMPseudo
                if identifiers[old2.identifier] == nil {
                    identifiers[old2.identifier] = offset
                    offset -= 4
                }
                binary.dst = ASMStack(value: identifiers[old2.identifier]!)
            }
            new_instr.append(binary)
        case is ASMIdivInstruction:
            var idiv = instr as! ASMIdivInstruction
            if idiv.operand is ASMPseudo {
                let old = idiv.operand as! ASMPseudo
                if identifiers[old.identifier] == nil {
                    identifiers[old.identifier] = offset
                    offset -= 4
                }
                idiv.operand = ASMStack(value: identifiers[old.identifier]!)
            }
            new_instr.append(idiv)
        default:
            new_instr.append(instr)
        }
    }
    if offset + 4 != 0 {
        new_instr.insert(ASMAllocateStackInstr(value: 0 - (offset + 4)), at: 0)
    }
    return new_instr
}

func fixInvalidInstructions(instructions: [ASMInstruction]) -> [ASMInstruction] {
    var new_instr: [ASMInstruction] = []
    for instr in instructions {
        switch instr {
        case is ASMIdivInstruction:
            // First, we need to fix idiv instructions that take constant operands.
            // Whenever idiv needs to operate on a constant, we copy that constant into our scratch register first.
            let idiv = instr as! ASMIdivInstruction
            if idiv.operand is ASMImm {
                new_instr.append(ASMMovInstr(src: idiv.operand, dst: ASMReg(register: "r10d")))
                new_instr.append(ASMIdivInstruction(operand: ASMReg(register: "r10d")))
            } else {
                new_instr.append(instr)
            }
        case is ASMMovInstr:
            let mv = instr as! ASMMovInstr
            if mv.src is ASMStack && mv.dst is ASMStack {
                new_instr.append(ASMMovInstr(src: mv.src, dst: ASMReg(register: "r10d")))
                new_instr.append(ASMMovInstr(src: ASMReg(register: "r10d"), dst: mv.dst))
            } else {
                new_instr.append(instr)
            }
        case is ASMBinaryInstruction:
            let bn = instr as! ASMBinaryInstruction
            if bn.op == "+" || bn.op == "-" || bn.op == "&" || bn.op == "|" || bn.op == "^" {
                if bn.dst is ASMStack && bn.src is ASMStack {
                    new_instr.append(ASMMovInstr(src: bn.src, dst: ASMReg(register: "r10d")))
                    new_instr.append(ASMBinaryInstruction(src: ASMReg(register: "r10d"), dst: bn.dst, op: bn.op))
                } else {
                    new_instr.append(instr)
                }
            } else if bn.op == ">>" || bn.op == "<<" {
                // src >> dst means shift src by d bits
                new_instr.append(ASMMovInstr(src: bn.dst, dst: ASMReg(register: "r10d")))
                new_instr.append(ASMMovBInstr(src: bn.src, dst: ASMReg(register: "CL")))
                new_instr.append(ASMBinaryInstruction(src: ASMReg(register: "CL"), dst: ASMReg(register: "r10d"), op: bn.op))
                new_instr.append(ASMMovInstr(src: ASMReg(register: "r10d"), dst: bn.dst))
            } else if bn.op == "*" {
                new_instr.append(ASMMovInstr(src: bn.dst, dst: ASMReg(register: "r11d")))
                new_instr.append(ASMBinaryInstruction(src: bn.src, dst: ASMReg(register: "r11d"), op: "*"))
                new_instr.append(ASMMovInstr(src: ASMReg(register: "r11d"), dst: bn.dst))
            } else {
                new_instr.append(instr)
            }
        default:
            new_instr.append(instr)
        }
    }
    return new_instr
}
