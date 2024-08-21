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
            output += instr.emitCode() + "\n"
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
        return "\t" + "movl" + "\t" + src.emitCode() + ", \t" + dst.emitCode()
    }
}

struct ASMMovBInstr: ASMInstruction {
    var src: ASMOperand
    var dst: ASMOperand
    func emitCode() -> String {
        return "\t" + "movb" + "\t" + src.emitCode() + ", \t" + dst.emitCode()
    }
}


struct ASMUnaryInstr: ASMInstruction {
    var op: String
    var operand: ASMOperand
    
    let opmap = ["-": "negl", "~": "notl"]
    func emitCode() -> String {
        return "\t" + opmap[op]! + "\t" + operand.emitCode()
    }
}

struct ASMAllocateStackInstr: ASMInstruction {
    var value: Int
    func emitCode() -> String {
        return "\t" + "subq" + "\t" + "$\(value)," + "\t" + "%rsp"
    }
}

struct ASMReturnInstr: ASMInstruction {
    //var value: ASMOperand
    func emitCode() -> String {
        let line1 = "\t" + "movq" + "\t" + "%rbp," + "\t" + "%rsp\n"
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
        return "\t" + op_map[op]! + "\t\(s),\t\(d)"
    }
}

struct ASMIdivInstruction: ASMInstruction {
    var operand: ASMOperand
    
    func emitCode() -> String {
        return "\t" + "idivl" + "\t" + operand.emitCode()
    }
}

struct ASMCdqInstruction: ASMInstruction {
    func emitCode() -> String {
        return "\t" + "cdq"
    }
}

struct ASMCmpInstruction: ASMInstruction {
    var operand1: ASMOperand
    var operand2: ASMOperand
    func emitCode() -> String {
        return "\t" + "cmpl" + "\t" + operand1.emitCode() + ",\t" + operand2.emitCode()
    }
}

struct ASMJmpInstruction: ASMInstruction {
    var identifier: String
    func emitCode() -> String {
        return "\t" + "jmp \t" + identifier
    }
}

struct ASMJumpCCInstruction: ASMInstruction {
    var cond_code: String
    var identifier: String
    func emitCode() -> String {
        return "\t" + "j" + cond_code + "\t" + identifier
    }
}

struct ASMSetCCInstruction: ASMInstruction {
    var cond_code: String
    var operand: ASMOperand
    func emitCode() -> String {
        return "\t" + "set" + cond_code + "\t" + operand.emitOneByte()
    }
}

struct ASMLabelInstruction: ASMInstruction {
    var identifier: String
    func emitCode() -> String {
        return identifier + ":"
    }
}

protocol ASMOperand: ASM {
    func emitOneByte() -> String
    func emitFourByte() -> String
}

struct ASMImm: ASMOperand {
    var value: Int
    func emitCode() -> String {
        return "$\(value)"
    }
    func emitOneByte() -> String {
        return "$\(value)"
    }
    func emitFourByte() -> String {
        return "$\(value)"
    }
}

struct ASMReg: ASMOperand {
    var register: String
    let reg_codes_four = ["AX": "%eax", "R10": "%r10d", "DX": "%edx", "CL": "%cl", "R11" : "%r11d"]
    let reg_codes_one = ["AX": "%al", "R10": "%r10b", "DX": "%dl", "CL": "%cl", "R11" : "%r11b"]
    func emitCode() -> String {
        return reg_codes_four[register]!
    }
    
    func emitOneByte() -> String {
        return reg_codes_one[register]!
    }
    func emitFourByte() -> String {
        return reg_codes_four[register]!
    }
}

struct ASMPseudo: ASMOperand {
    var identifier: String
    func emitCode() -> String {
        return "PSEUDO(\(identifier))"
    }
    func emitOneByte() -> String {
        return emitCode()
    }
    func emitFourByte() -> String {
        return emitCode()
    }
}

struct ASMStack: ASMOperand {
    var value: Int
    func emitCode() -> String {
        return "\(value)(%rbp)"
    }
    func emitOneByte() -> String {
        return emitCode()
    }
    func emitFourByte() -> String {
        return emitCode()
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

let BINOP_COND_CODES = [">": "g", ">=": "ge", "==": "e", "!=": "ne", "<": "l", "<=": "le"]

func convertInstruction(tac: TACInstruction) throws -> [ASMInstruction] {
    switch tac {
    case is TACReturnInstruction:
        let tac_v = tac as! TACReturnInstruction
        return [ASMMovInstr(src: try! convertValue(tac: tac_v.value), dst: ASMReg(register: "AX")), ASMReturnInstr()]
    case is TACUnaryInstruction:
        let tac_u = tac as! TACUnaryInstruction
        let src = try! convertValue(tac: tac_u.src)
        let dst = try! convertValue(tac: tac_u.dst)
        if tac_u.op == "!" {
            return [
                ASMCmpInstruction(operand1: ASMImm(value: 0), operand2: src),
                ASMMovInstr(src: ASMImm(value: 0), dst: dst),
                ASMSetCCInstruction(cond_code: "e", operand: dst)
            ]
        } else {
            return [ASMMovInstr(src: src, dst: dst), ASMUnaryInstr(op: tac_u.op, operand: dst)]
        }
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
        } else if let cond = BINOP_COND_CODES[tac_b.op] {
            return [
                ASMCmpInstruction(operand1: src2, operand2: src1),
                ASMMovInstr(src: ASMImm(value: 0), dst: dst),
                ASMSetCCInstruction(cond_code: cond, operand: dst)
            ]
        } else {
            throw AssemblyError.wrongValueType(found: tac_b.op)
        }
    case is TACJumpIfZeroInstruction:
        let tac_j = tac as! TACJumpIfZeroInstruction
        return [
            ASMCmpInstruction(operand1: ASMImm(value: 0), operand2: try!convertValue(tac: tac_j.condition)),
            ASMJumpCCInstruction(cond_code: "e", identifier: tac_j.target)
        ]
    case is TACJumpIfNotZeroInstruction:
        let tac_j = tac as! TACJumpIfNotZeroInstruction
        return [
            ASMCmpInstruction(operand1: ASMImm(value: 0), operand2: try!convertValue(tac: tac_j.condition)),
            ASMJumpCCInstruction(cond_code: "ne", identifier: tac_j.target)
        ]
    case is TACJumpInstruction:
        let tac_j = tac as! TACJumpInstruction
        return [ASMJmpInstruction(identifier: tac_j.target)]
    case is TACLabel:
        let tac_l = tac as! TACLabel
        return [ASMLabelInstruction(identifier: tac_l.identifier)]
    case is TACCopyInstruction:
        let tac_c = tac as! TACCopyInstruction
        let src = try! convertValue(tac: tac_c.src)
        let dst = try! convertValue(tac: tac_c.dst)
        return [ASMMovInstr(src: src, dst: dst)]
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
        case is ASMCmpInstruction:
            var cmp = instr as! ASMCmpInstruction
            if cmp.operand1 is ASMPseudo {
                let old1 = cmp.operand1 as! ASMPseudo
                if identifiers[old1.identifier] == nil {
                    identifiers[old1.identifier] = offset
                    offset -= 4
                }
                cmp.operand1 = ASMStack(value: identifiers[old1.identifier]!)
            }
            if cmp.operand2 is ASMPseudo {
                let old2 = cmp.operand2 as! ASMPseudo
                if identifiers[old2.identifier] == nil {
                    identifiers[old2.identifier] = offset
                    offset -= 4
                }
                cmp.operand2 = ASMStack(value: identifiers[old2.identifier]!)
            }
            new_instr.append(cmp)
        case is ASMSetCCInstruction:
            var setcc = instr as! ASMSetCCInstruction
            if setcc.operand is ASMPseudo {
                let old = setcc.operand as! ASMPseudo
                if identifiers[old.identifier] == nil {
                    identifiers[old.identifier] = offset
                    offset -= 4
                }
                setcc.operand = ASMStack(value: identifiers[old.identifier]!)
            }
            new_instr.append(setcc)
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
                new_instr.append(ASMMovInstr(src: idiv.operand, dst: ASMReg(register: "R10")))
                new_instr.append(ASMIdivInstruction(operand: ASMReg(register: "R10")))
            } else {
                new_instr.append(instr)
            }
        case is ASMMovInstr:
            let mv = instr as! ASMMovInstr
            if mv.src is ASMStack && mv.dst is ASMStack {
                new_instr.append(ASMMovInstr(src: mv.src, dst: ASMReg(register: "R10")))
                new_instr.append(ASMMovInstr(src: ASMReg(register: "R10"), dst: mv.dst))
            } else {
                new_instr.append(instr)
            }
        case is ASMBinaryInstruction:
            let bn = instr as! ASMBinaryInstruction
            if bn.op == "+" || bn.op == "-" || bn.op == "&" || bn.op == "|" || bn.op == "^" {
                if bn.dst is ASMStack && bn.src is ASMStack {
                    new_instr.append(ASMMovInstr(src: bn.src, dst: ASMReg(register: "R10")))
                    new_instr.append(ASMBinaryInstruction(src: ASMReg(register: "R10"), dst: bn.dst, op: bn.op))
                } else {
                    new_instr.append(instr)
                }
            } else if bn.op == ">>" || bn.op == "<<" {
                // src >> dst means shift src by d bits
                new_instr.append(ASMMovInstr(src: bn.dst, dst: ASMReg(register: "R10")))
                new_instr.append(ASMMovBInstr(src: bn.src, dst: ASMReg(register: "CL")))
                new_instr.append(ASMBinaryInstruction(src: ASMReg(register: "CL"), dst: ASMReg(register: "R10"), op: bn.op))
                new_instr.append(ASMMovInstr(src: ASMReg(register: "R10"), dst: bn.dst))
            } else if bn.op == "*" {
                new_instr.append(ASMMovInstr(src: bn.dst, dst: ASMReg(register: "R11")))
                new_instr.append(ASMBinaryInstruction(src: bn.src, dst: ASMReg(register: "R11"), op: "*"))
                new_instr.append(ASMMovInstr(src: ASMReg(register: "R11"), dst: bn.dst))
            } else {
                new_instr.append(instr)
            }
        case is ASMCmpInstruction:
            let cmp = instr as! ASMCmpInstruction
            // Can't use memory addresses for both operands
            var fixed: [ASMInstruction] = []
            if cmp.operand1 is ASMStack && cmp.operand2 is ASMStack {
                fixed.append(ASMMovInstr(src: cmp.operand1, dst: ASMReg(register: "R10")))
                fixed.append(ASMCmpInstruction(operand1: ASMReg(register: "R10"), operand2: cmp.operand2))
            } else {
                fixed.append(instr)
            }
            // Second operand of CMP cannot be a constant
            for fixed_instr in fixed {
                if fixed_instr is ASMCmpInstruction {
                    let fx = fixed_instr as! ASMCmpInstruction
                    if fx.operand2 is ASMImm {
                        new_instr.append(ASMMovInstr(src: fx.operand2, dst: ASMReg(register: "R11")))
                        new_instr.append(ASMCmpInstruction(operand1: fx.operand1, operand2: ASMReg(register: "R11")))
                    }
                    else {
                        new_instr.append(fx)
                    }
                } else {
                    new_instr.append(fixed_instr)
                }
            }
        default:
            new_instr.append(instr)
        }
    }
    return new_instr
}
