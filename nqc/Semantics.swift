import Foundation

enum SemanticsError: Error {
    case variableDeclaredTwice(msg: String)
    case undeclaredVariable(msg: String)
    case unrecognizedStatementType(msg: String)
    case invaldLValue(msg: String)
}

class SemanticAnalysis {
    var variableMap:[String: String] = [:]
    var varCounters: [String: Int] = [:]
    
    func validate(_ ast: ASTProgram) -> ASTProgram {
        let fun = ast.function
        var new_body: [ASTBlockItem] = []
        for item in fun.body {
            switch item {
            case is ASTBlockStatement:
                let it = item as! ASTBlockStatement
                new_body.append(ASTBlockStatement(statement: try! resolveStatement(it.statement)))
            case is ASTBlockDeclaration:
                let it = item as! ASTBlockDeclaration
                new_body.append(ASTBlockDeclaration(declaration: try! resolveDeclaration(dec: it.declaration)))
            default:
                continue
            }
        }
        return ASTProgram(function: ASTFunction(name: fun.name, body: new_body))
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
    
    func resolveDeclaration(dec: ASTDeclaration) throws -> ASTDeclaration {
        if variableMap[dec.identifier] != nil {
            throw SemanticsError.variableDeclaredTwice(msg: "Variable \(dec.identifier) already declared!")
        }
        let unique = makeName(dec.identifier)
        variableMap[dec.identifier] = unique
        if dec.init_val != nil {
            let ival = try! resolveExp(dec.init_val!)
            return ASTDeclaration(identifier: unique, init_val: ival)
        } else {
            return ASTDeclaration(identifier: unique)
        }
    }
    
    func resolveStatement(_ stmt: ASTStatement) throws -> ASTStatement {
        switch stmt {
        case is ASTReturnStatement:
            let r_stmt = stmt as! ASTReturnStatement
            return ASTReturnStatement(exp: try! resolveExp(r_stmt.exp))
        case is ASTExpressionStatement:
            let e_stmt = stmt as! ASTExpressionStatement
            return ASTExpressionStatement(exp: try! resolveExp(e_stmt.exp))
        case is ASTNullStatement:
            return stmt
        case is ASTIfStatement:
            let i_stmt = stmt as! ASTIfStatement
            let cond = try! resolveExp(i_stmt.condition)
            let then = try! resolveStatement(i_stmt.then)
            if i_stmt.els != nil {
                let els = try! resolveStatement(i_stmt.els!)
                return ASTIfStatement(condition: cond, then: then, els: els)
            }
            return ASTIfStatement(condition: cond, then: then)
        default:
            throw SemanticsError.unrecognizedStatementType(msg: "\(stmt)")
        }
    }
    
    func resolveExp(_ exp: ASTExpr) throws -> ASTExpr {
        switch exp {
        case is ASTAssignmentExpr:
            let a_exp = exp as! ASTAssignmentExpr
            if !(a_exp.left is ASTVarExpr) {
                throw SemanticsError.invaldLValue(msg: "Invalid lval in assignment: \(a_exp.left) is not a Var")
            }
            return ASTAssignmentExpr(
                left: try! resolveExp(a_exp.left),
                right: try! resolveExp(a_exp.right))
        case is ASTCompoundAssignmentExpr:
            let ca_exp = exp as! ASTCompoundAssignmentExpr
            if !(ca_exp.left is ASTVarExpr) {
                throw SemanticsError.invaldLValue(msg: "Invalid lval in assignment: \(ca_exp.left) is not a Var")
            }
            return ASTCompoundAssignmentExpr(
                left: try! resolveExp(ca_exp.left),
                right: try! resolveExp(ca_exp.right),
                op: ca_exp.op
            )
        case is ASTVarExpr:
            let v_exp = exp as! ASTVarExpr
            if variableMap[v_exp.identifier] != nil {
                return ASTVarExpr(identifier: variableMap[v_exp.identifier]!)
            } else {
                throw SemanticsError.undeclaredVariable(msg: "\(exp)")
            }
        case is ASTBinaryExpr:
            let bin_ex = exp as! ASTBinaryExpr
            return ASTBinaryExpr(
                left: try! resolveExp(bin_ex.left),
                right: try! resolveExp(bin_ex.right),
                op: bin_ex.op)
        case is ASTUnaryFactor:
            let unar = exp as! ASTUnaryFactor
            return ASTUnaryFactor(op: unar.op, right: try! resolveExp(unar.right))
        case is ASTConstantFactor:
            return exp
        case is ASTConditionalExpr:
            let c = exp as! ASTConditionalExpr
            return ASTConditionalExpr(cond: try! resolveExp(c.cond), exp1: try! resolveExp(c.exp1), exp2: try! resolveExp(c.exp2))
        default:
            throw SemanticsError.unrecognizedStatementType(msg: "\(exp.toString())")
            //return exp
        }
    }
}
