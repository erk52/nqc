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
        return "\(op)(\(src.toString()), \(dst.toString())"
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
    var instructions: [TACInstruction] = []
    

    func makeTempName() -> String {
        counter += 1
        return "tmp.\(counter)"
    }
    
    func emitTacky(exp: ASTExpr) throws -> TACValue {
        switch exp {
        case is ASTConstantExpr:
            let const = exp as! ASTConstantExpr
            return TACConstant(value: const.value)
        case is ASTUnaryExpr:
            let rt = exp as! ASTUnaryExpr
            var src = try! emitTacky(exp: rt.right)
            var dst = TACVar(identifier: makeTempName())
            instructions.append(TACUnaryInstruction(op: rt.op, src: src, dst: dst))
            return dst
        default:
            throw TackyError.wrongValueType(found: exp.toString())
        }
    }
    
    func convertAST(program: ASTProgram) -> TACProgram {
        var ast_fun = program.function
        var ast_stmt = ast_fun.body as! ASTReturnStatement
        
        var return_instr = TACReturnInstruction(value: try! emitTacky(exp: ast_stmt.exp))
        instructions.append(return_instr)
        
        let tac_func = TACFunction(name: ast_fun.name, body: instructions)
        return TACProgram(function: tac_func)
    }
}
