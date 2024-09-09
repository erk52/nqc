import Foundation

enum SemanticsError: Error {
    case variableDeclaredTwice(msg: String)
    case undeclaredVariable(msg: String)
    case unrecognizedStatementType(msg: String)
    case invaldLValue(msg: String)
}


class SemanticAnalysis {
    var varCounters: [String: Int] = [:]
    
    func validate(_ ast: ASTProgram) -> ASTProgram {
        let fun = ast.function
        return try! ASTProgram(function: ASTFunction(name: fun.name, body: resolveBlock(ast.function.body, variableMap: [:])))
    }
    
    func makeName(_ name: String) -> String {
        if varCounters[name] == nil {
            varCounters[name] = 1
            return "\(name)_._0"
        } else {
            varCounters[name]! += 1
            return "\(name)_._\(varCounters[name]!)"
        }
    }
    
    func resolveDeclaration(dec: ASTDeclaration, variableMap: inout [String: (String, Bool)]) throws -> ASTDeclaration {
        //var variableMap = variableMap
        if variableMap[dec.identifier] != nil && variableMap[dec.identifier]!.1 {
            throw SemanticsError.variableDeclaredTwice(msg: "Variable \(dec.identifier) already declared!")
        }
        let unique = makeName(dec.identifier)
        variableMap[dec.identifier] = (unique, true)
        if dec.init_val != nil {
            let ival = try! resolveExp(dec.init_val!, variableMap: variableMap)
            return ASTDeclaration(identifier: unique, init_val: ival)
        } else {
            return ASTDeclaration(identifier: unique)
        }
    }
    
    func resolveStatement(_ stmt: ASTStatement, variableMap: [String: (String, Bool)]) throws -> ASTStatement {
        switch stmt {
        case is ASTReturnStatement:
            let r_stmt = stmt as! ASTReturnStatement
            return ASTReturnStatement(exp: try! resolveExp(r_stmt.exp, variableMap: variableMap))
        case is ASTExpressionStatement:
            let e_stmt = stmt as! ASTExpressionStatement
            return ASTExpressionStatement(exp: try! resolveExp(e_stmt.exp, variableMap: variableMap))
        case is ASTNullStatement:
            return stmt
        case is ASTIfStatement:
            let i_stmt = stmt as! ASTIfStatement
            let cond = try! resolveExp(i_stmt.condition, variableMap: variableMap)
            let then = try! resolveStatement(i_stmt.then, variableMap: variableMap)
            if i_stmt.els != nil {
                let els = try! resolveStatement(i_stmt.els!, variableMap: variableMap)
                return ASTIfStatement(condition: cond, then: then, els: els)
            }
            return ASTIfStatement(condition: cond, then: then)
        case is ASTCompoundStatement:
            let c_stmt = stmt as! ASTCompoundStatement
            return ASTCompoundStatement(body: try! resolveBlock(c_stmt.body, variableMap: copyNewVarMap(variableMap)))
        default:
            throw SemanticsError.unrecognizedStatementType(msg: "\(stmt)")
        }
    }
    
    func resolveBlock(_ block: ASTBlock, variableMap: [String: (String, Bool)]) throws -> ASTBlock {
        var new_body: [ASTBlockItem] = []
        var vmap = variableMap
        for item in block.body {
            switch item {
            case is ASTBlockStatement:
                let it = item as! ASTBlockStatement
                new_body.append(ASTBlockStatement(statement: try! resolveStatement(it.statement, variableMap: vmap)))
            case is ASTBlockDeclaration:
                let it = item as! ASTBlockDeclaration
                new_body.append(ASTBlockDeclaration(declaration: try! resolveDeclaration(dec: it.declaration, variableMap: &vmap)))
            default:
                throw SemanticsError.unrecognizedStatementType(msg: item.toString())
            }
        }
        return ASTBlock(body: new_body)
    }
    
    func copyNewVarMap(_ oldVarMap: [String: (String, Bool)]) -> [String: (String, Bool)] {
        var newMap: [String: (String, Bool)] = [:]
        for k in oldVarMap.keys {
            let entry = oldVarMap[k]!
            newMap[k] = (entry.0, false)
        }
        return newMap
    }
    
    func resolveExp(_ exp: ASTExpr, variableMap: [String: (String, Bool)]) throws -> ASTExpr {
        switch exp {
        case is ASTAssignmentExpr:
            print("Resolving assignment: \(exp.toString())")
            print("With vmap: \(variableMap)")
            let a_exp = exp as! ASTAssignmentExpr
            if !(a_exp.left is ASTVarExpr) {
                throw SemanticsError.invaldLValue(msg: "Invalid lval in assignment: \(a_exp.left) is not a Var")
            }
            return ASTAssignmentExpr(
                left: try! resolveExp(a_exp.left, variableMap: variableMap),
                right: try! resolveExp(a_exp.right, variableMap: variableMap))
        case is ASTCompoundAssignmentExpr:
            let ca_exp = exp as! ASTCompoundAssignmentExpr
            if !(ca_exp.left is ASTVarExpr) {
                throw SemanticsError.invaldLValue(msg: "Invalid lval in assignment: \(ca_exp.left) is not a Var")
            }
            var newvariableMap = copyNewVarMap(variableMap)
            return ASTCompoundAssignmentExpr(
                left: try! resolveExp(ca_exp.left, variableMap: newvariableMap),
                right: try! resolveExp(ca_exp.right, variableMap: newvariableMap),
                op: ca_exp.op
            )
        case is ASTVarExpr:
            let v_exp = exp as! ASTVarExpr
            if variableMap[v_exp.identifier] != nil {
                return ASTVarExpr(identifier: variableMap[v_exp.identifier]!.0)
            } else {
                throw SemanticsError.undeclaredVariable(msg: "\(exp)")
            }
        case is ASTBinaryExpr:
            let bin_ex = exp as! ASTBinaryExpr
            return ASTBinaryExpr(
                left: try! resolveExp(bin_ex.left, variableMap: variableMap),
                right: try! resolveExp(bin_ex.right, variableMap: variableMap),
                op: bin_ex.op)
        case is ASTUnaryFactor:
            let unar = exp as! ASTUnaryFactor
            return ASTUnaryFactor(op: unar.op, right: try! resolveExp(unar.right, variableMap: variableMap))
        case is ASTConstantFactor:
            return exp
        case is ASTConditionalExpr:
            let c = exp as! ASTConditionalExpr
            return ASTConditionalExpr(
                cond: try! resolveExp(c.cond, variableMap: variableMap),
                exp1: try! resolveExp(c.exp1, variableMap: variableMap),
                exp2: try! resolveExp(c.exp2, variableMap: variableMap)
            )
        default:
            throw SemanticsError.unrecognizedStatementType(msg: "\(exp.toString())")
            //return exp
        }
    }
}
