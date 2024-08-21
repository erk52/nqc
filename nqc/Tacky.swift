//
//  Tacky.swift
//  nqc
//
//  Created by Edward Kish on 8/18/24.
//

import Foundation

enum TackyError: Error {
    case wrongValueType(found: String)
}

protocol TAC {
    func toString() -> String
}

struct TACProgram: TAC {
    var function: TACFunction
    func toString() -> String {
        return "TACProgram(function=(\(function.toString()))"
    }
}

struct TACFunction: TAC {
    var name: String
    var body: [TACInstruction]
    func toString() -> String {
        var out = "TACFunction(name=\(name), body=["
        for instr in body{
            out += instr.toString()
            out += ", "
        }
        out += "]"
        return out
    }
}

protocol TACInstruction: TAC {
    
}

struct TACReturnInstruction: TACInstruction {
    var value: TACValue
    func toString() -> String {
        return "TACReturn(\(value.toString())"
    }
}

struct TACUnaryInstruction: TACInstruction {
    var op: String
    var src: TACValue
    var dst: TACValue
    func toString() -> String {
        return "Unary(\(op) \(src.toString()) -> \(dst.toString())"
    }
}

struct TACBinaryInstruction: TACInstruction {
    var op: String
    var src1: TACValue
    var src2: TACValue
    var dst: TACValue
    
    func toString() -> String {
        return "Bin(\(src1.toString()) \(op) \(src2.toString()) -> \(dst.toString()))"
    }
}

struct TACCopyInstruction: TACInstruction {
    var src: TACValue
    var dst: TACValue
    
    func toString() -> String {
        return "Copy(\(src.toString()), \(dst.toString())"
    }
}

struct TACJumpInstruction: TACInstruction {
    var target: String
    func toString() ->String {
        return "Jump(\(target))"
    }
}

struct TACJumpIfZeroInstruction: TACInstruction {
    var condition: TACValue
    var target: String
    func toString() -> String {
        return "JumpIfZero(cond=\(condition.toString()), target=\(target)"
    }
}

struct TACJumpIfNotZeroInstruction: TACInstruction {
    var condition: TACValue
    var target: String
    func toString() -> String {
        return "JumpIfNotZero(cond=\(condition.toString()), target=\(target)"
    }
}

struct TACLabel: TACInstruction {
    var identifier: String
    func toString() -> String {
        return "Label(\(identifier)"
    }
}

protocol TACValue: TAC {
    
}

struct TACConstant: TACValue {
    var value: Int
    func toString() -> String {
        return "TACConstant(\(value))"
    }
}

struct TACVar: TACValue {
    var identifier: String
    func toString() -> String {
        return "TACVar(\(identifier))"
    }
}

class TACEmitter {
    var counter: Int = 0
    var labelCounters: [String: Int] = [:]
    var instructions: [TACInstruction] = []
    

    func makeTempName() -> String {
        counter += 1
        return "tmp.\(counter)"
    }
    
    func makeLabel(base: String) -> String {
        if labelCounters[base] == nil {
            labelCounters[base] = 0
        } else {
            labelCounters[base] = labelCounters[base]! + 1
        }
        return "L\(base)_\(labelCounters[base]!)"
    }
    
    func emitTacky(exp: ASTExpr) throws -> TACValue {
        switch exp {
        case is ASTConstantFactor:
            let const = exp as! ASTConstantFactor
            return TACConstant(value: const.value)
        case is ASTUnaryFactor:
            let rt = exp as! ASTUnaryFactor
            let src = try! emitTacky(exp: rt.right)
            let dst = TACVar(identifier: makeTempName())
            instructions.append(TACUnaryInstruction(op: rt.op, src: src, dst: dst))
            return dst
        case is ASTBinaryExpr:
            let binex = exp as! ASTBinaryExpr
            switch binex.op {
            case "+", "-","/", "*", "%", ">", "<", ">=", "<=", "==", "!=":
                let v1 = try! emitTacky(exp: binex.left)
                let v2 = try! emitTacky(exp: binex.right)
                let dst = TACVar(identifier: makeTempName())
                instructions.append(TACBinaryInstruction(op: binex.op, src1: v1, src2: v2, dst: dst))
                return dst
            case "&&":
                let false_label = makeLabel(base: "and_false")
                let v1 = try! emitTacky(exp: binex.left)
                instructions.append(TACJumpIfZeroInstruction(condition: v1, target:false_label))
                let v2 = try! emitTacky(exp: binex.right)
                instructions.append(TACJumpIfZeroInstruction(condition: v2, target: false_label))
                let result = TACVar(identifier: makeTempName())
                instructions.append(TACCopyInstruction(src: TACConstant(value: 1), dst: result))
                let end_label = makeLabel(base: "and_end")
                instructions.append(TACJumpInstruction(target: end_label))
                instructions.append(TACLabel(identifier: false_label))
                instructions.append(TACCopyInstruction(src: TACConstant(value: 0), dst: result))
                instructions.append(TACLabel(identifier: end_label))
                return result
            case "||":
                let true_label = makeLabel(base: "or_true")
                let v1 = try! emitTacky(exp: binex.left)
                instructions.append(TACJumpIfNotZeroInstruction(condition: v1, target:true_label))
                let v2 = try! emitTacky(exp: binex.right)
                instructions.append(TACJumpIfNotZeroInstruction(condition: v2, target: true_label))
                let result = TACVar(identifier: makeTempName())
                instructions.append(TACCopyInstruction(src: TACConstant(value: 0), dst: result))
                let end_label = makeLabel(base: "or_end")
                instructions.append(TACJumpInstruction(target: end_label))
                instructions.append(TACLabel(identifier: true_label))
                instructions.append(TACCopyInstruction(src: TACConstant(value: 1), dst: result))
                instructions.append(TACLabel(identifier: end_label))
                return result
            default:
                throw TackyError.wrongValueType(found: "Binary operator \(binex.op) not implemented.")
            }
            
        default:
            throw TackyError.wrongValueType(found: exp.toString())
        }
    }
    
    func convertAST(program: ASTProgram) -> TACProgram {
        let ast_fun = program.function
        let ast_stmt = ast_fun.body as! ASTReturnStatement
        
        let return_instr = TACReturnInstruction(value: try! emitTacky(exp: ast_stmt.exp))
        instructions.append(return_instr)
        
        let tac_func = TACFunction(name: ast_fun.name, body: instructions)
        return TACProgram(function: tac_func)
    }

}
