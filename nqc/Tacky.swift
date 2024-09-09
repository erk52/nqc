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
    var postfixes: [TACInstruction] = []
    

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
        case is ASTVarExpr:
            let v = exp as! ASTVarExpr
            return TACVar(identifier: v.identifier)
        case is ASTAssignmentExpr:
            let ass = exp as! ASTAssignmentExpr
            let v = ass.left as! ASTVarExpr
            let tac_var = TACVar(identifier: v.identifier)
            let result = try! emitTacky(exp: ass.right)
            instructions.append(TACCopyInstruction(src: result, dst: tac_var))
            return tac_var
        case is ASTCompoundAssignmentExpr:
            let ass = exp as! ASTCompoundAssignmentExpr
            let v = ass.left as! ASTVarExpr
            let tac_var = TACVar(identifier: v.identifier)
            let result = try! emitTacky(exp: ass.right)
            
            instructions.append(
                TACBinaryInstruction(op: ass.op.replacingOccurrences(of: "=", with: ""), src1: tac_var, src2: result, dst: tac_var))
            return tac_var
        case is ASTBinaryExpr:
            let binex = exp as! ASTBinaryExpr
            switch binex.op {
            case "+", "-","/", "*", "%", ">", "<", ">=", "<=", "==", "!=", ">>", "<<", "|", "^", "&":
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
        case is ASTConditionalExpr:
            let cexp = exp as! ASTConditionalExpr
            let c = try! emitTacky(exp: cexp.cond)
            let result = TACVar(identifier: makeTempName())
            let targ = makeLabel(base: "ternary_true")
            let endl = makeLabel(base: "end_ternary")
            instructions.append(TACJumpIfZeroInstruction(condition: c, target: targ))
            let v1 = try! emitTacky(exp: cexp.exp1)
            instructions.append(TACCopyInstruction(src: v1, dst: result))
            instructions.append(TACJumpInstruction(target: endl))
            instructions.append(TACLabel(identifier: targ))
            let v2 = try! emitTacky(exp: cexp.exp2)
            instructions.append(TACCopyInstruction(src: v2, dst: result))
            instructions.append(TACLabel(identifier: endl))
            return result
        default:
            throw TackyError.wrongValueType(found: exp.toString())
        }
    }
    
    func convertStatement(_ stmt: ASTStatement) {
        switch stmt {
            case is ASTNullStatement:
                return
            case is ASTReturnStatement:
                let ret = stmt as! ASTReturnStatement
                instructions.append(TACReturnInstruction(value: try! emitTacky(exp: ret.exp)))
            case is ASTExpressionStatement:
                let ex = stmt as! ASTExpressionStatement
                try! emitTacky(exp: ex.exp)
            case is ASTBlockStatement:
                let b_stmt = stmt as! ASTBlockStatement
                convertStatement(b_stmt.statement)
            case is ASTIfStatement:
                let i_stmt = stmt as! ASTIfStatement
                let c = try! emitTacky(exp: i_stmt.condition)
                let endlab = makeLabel(base: "ifend")
                if i_stmt.els == nil {
                    instructions.append(TACJumpIfZeroInstruction(condition: c, target: endlab))
                    convertStatement(i_stmt.then)
                    instructions.append(TACLabel(identifier: endlab))
                } else {
                    let else_lab = makeLabel(base: "else")
                    instructions.append(TACJumpIfZeroInstruction(condition: c, target: else_lab))
                    convertStatement(i_stmt.then)
                    instructions.append(TACJumpInstruction(target: endlab))
                    instructions.append(TACLabel(identifier: else_lab))
                    convertStatement(i_stmt.els!)
                    instructions.append(TACLabel(identifier: endlab))
                }
            case is ASTCompoundStatement:
                let cstmt = stmt as! ASTCompoundStatement
                convertBlock(cstmt.body)
            default:
                return
            }
        
    }
    
    func convertBlock(_ block: ASTBlock) {
        for item in block.body {
            switch item {
            case is ASTBlockDeclaration:
                let dec = item as! ASTBlockDeclaration
                if dec.declaration.init_val != nil {
                    let declared = try! emitTacky(exp: dec.declaration.init_val!)
                    instructions.append(TACCopyInstruction(src: declared, dst: TACVar(identifier: dec.declaration.identifier)))
                }
            case is ASTBlockStatement:
                let block = item as! ASTBlockStatement
                convertStatement(block.statement)
            default:
                continue
            }
        }
    }
    
    func convertAST(program: ASTProgram) -> TACProgram {
        let ast_fun = program.function
        let ast_stmts = ast_fun.body.body
        for st in ast_stmts {
            switch st {
            case is ASTBlockDeclaration:
                let dec = st as! ASTBlockDeclaration
                if dec.declaration.init_val != nil {
                    let declared = try! emitTacky(exp: dec.declaration.init_val!)
                    instructions.append(TACCopyInstruction(src: declared, dst: TACVar(identifier: dec.declaration.identifier)))
                }
            case is ASTBlockStatement:
                let block = st as! ASTBlockStatement
                convertStatement(block.statement)
            default:
                continue
            }
        }
        
        if !(instructions.last is TACReturnInstruction){
            instructions.append(TACReturnInstruction(value: TACConstant(value: 0)))
        }
        
        let tac_func = TACFunction(name: ast_fun.name, body: instructions)
        return TACProgram(function: tac_func)
    }

}
