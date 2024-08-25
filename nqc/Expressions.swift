//
//  Expressions.swift
//  nqc
//
//  Created by Edward Kish on 8/15/24.
//

import Foundation

extension StringProtocol {
    var lines: [SubSequence] { split(whereSeparator: \.isNewline) }
}

enum ParsingError: Error {
    case unexpectedToken(found: Token, expected: String)
}

protocol ASTNode {
    func toString() -> String
}

struct ASTProgram: ASTNode {
    var function: ASTFunction
    func toString() -> String {
        return "Program(function=\(function.toString()))"
    }
}

struct ASTFunction: ASTNode {
    var name: String
    var body: [ASTBlockItem]
    func toString() -> String {
        var out = "Function(name=\(name), body=["
        for line in body {
            out += line.toString() + ", "
        }
        out += "])"
        return out
    }
}

protocol ASTBlockItem: ASTStatement {
    
}

struct ASTBlockStatement: ASTBlockItem {
    var statement: ASTStatement
    
    func toString() -> String {
        return "ASTBlockItem(statement=\(statement.toString()))"
    }
}

struct ASTBlockDeclaration: ASTBlockItem {
    var declaration: ASTDeclaration
    func toString() -> String {
        return "ASTBlockItem(declaration=\(declaration.toString()))"
    }
}

struct ASTDeclaration: ASTNode {
    var identifier: String
    var init_val: ASTExpr?
    
    func toString() -> String {
        let ival = init_val?.toString() ?? "null"
        return "Declaration(\(identifier), init=\(ival))"
    }
}

protocol ASTStatement: ASTNode {
    
}

struct ASTReturnStatement: ASTStatement {
    var exp: ASTExpr
    func toString() -> String {
        return "Return(\(exp.toString()))"
    }
}

struct ASTExpressionStatement: ASTStatement {
    var exp: ASTExpr
    func toString() -> String {
        return "ExpressionStmt(\(exp.toString()))"
    }
}

struct ASTNullStatement: ASTStatement {
    func toString() -> String {
        return "NullStatement()"
    }
}

struct ASTIfStatement: ASTStatement {
    var condition: ASTExpr
    var then: ASTStatement
    var els: ASTStatement?
    
    func toString() -> String {
        var out = "IfStatement(cond=\(condition.toString()), then=\(then.toString())"
        if els != nil {
            out += ", else=\(els!.toString())"
        }
        return out + ")"
    }
}

protocol ASTExpr: ASTNode {}

struct ASTBinaryExpr: ASTExpr {
    var left: ASTExpr
    var right: ASTExpr
    var op: String
    func toString() -> String {
        return "Binary(\(left.toString()), \(op), \(right.toString()))"
    }
}
protocol ASTFactor: ASTNode {
    
}

struct ASTConstantFactor: ASTExpr {
    var value: Int
    func toString() -> String {
        return "Constant(\(value))"
    }
}

struct ASTUnaryFactor: ASTExpr {
    var op: String
    var right: ASTExpr
    
    func toString() -> String {
        return "Unary(\(op), \(right.toString()))"
    }
}

struct ASTPrefixOpExpr: ASTExpr {
    var op: String
    var right: ASTExpr
    func toString() -> String {
        return "PrefixOp(\(op)\(right.toString()))"
    }
}

struct ASTPostfixOpExpr: ASTExpr {
    var op: String
    var left: ASTExpr
    func toString() -> String {
        return "PostfixOp(\(left.toString())\(op))"
    }
}


struct ASTVarExpr: ASTExpr {
    var identifier: String
    
    func toString() -> String {
        return "Var(\(identifier))"
    }
}

struct ASTAssignmentExpr: ASTExpr {
    var left: ASTExpr
    var right: ASTExpr
    
    func toString() -> String {
        return "Assignment(\(left.toString()) = \(right.toString()))"
    }
}

struct ASTCompoundAssignmentExpr: ASTExpr {
    var left: ASTExpr
    var right: ASTExpr
    var op: String
    
    func toString() -> String {
        return "CompoundAssignment(\(left.toString()) \(op) \(right.toString()))"
    }
}

struct ASTConditionalExpr: ASTExpr {
    var cond: ASTExpr
    var exp1: ASTExpr
    var exp2: ASTExpr
    func toString() -> String {
        return "Conditional(\(cond.toString()) ? \(exp1.toString()) : \(exp2.toString()))"
    }
}

let PRECEDENCE_ORDER = ["*": 500, "/": 500, "%": 500,
                        "+": 450, "-": 450,
                        ">>": 400, "<<": 400,
                        ">=": 370, ">": 370,
                        "<=": 370, "<": 370,
                        "==": 360, "!=": 360,
                        "&": 350, "^": 325, "|": 300,
                        "&&": 290, "||": 280,
                        "?": 50,
                        "=": 1, "+=": 1, "-=": 1, "*=":1, "/=": 1, "%=":1, ">>=": 1, "<<=": 1, "^=": 1, "&=": 1, "|=": 1,
]

// ----- NOW PARSE

class Parser {
    var tokens: [Token]
    var current = 0
    
    init(tokens: [Token]) {
        self.tokens = tokens
    }

    func parse() throws -> ASTProgram {
        
        let p = ASTProgram(function: try! parseFunction())
        if current < tokens.count {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "EOF")
        }
        return p
    }
    
    func parseFunction() throws -> ASTFunction {
        // Expect "int <identifier> ( void ) { <block-items> }
        var name: String
        var body: [ASTBlockItem] = []
        if tokens[current].type == .KeywordInt{
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "int keyword at function start")
        }
        if tokens[current].type == .Identifier {
            name = tokens[current].lexeme
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Identifier for function name")
        }
        if tokens[current].type == .OpenParen {
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Open paren for function args")
        }
        if tokens[current].type == .KeywordVoid {
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "void keyword at function args")
        }
        if tokens[current].type == .CloseParen {
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Close paren for function args")
        }
        if tokens[current].type == .OpenBrace {
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Open brace for func body")
        }
        
        while tokens[current].type != .CloseBrace {
            let next_item = try! parseBlockItem()
            body.append(next_item)
        }
        
        if tokens[current].type == .CloseBrace {
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Close brace to end func body")
        }
        return ASTFunction(name: name, body: body)
    }
    
    func parseBlockItem() throws -> ASTBlockItem {
        // <block-item> ::= <statement> | <declaration>
        if tokens[current].type == .KeywordInt {
            return ASTBlockDeclaration(declaration: try! parseDeclaration())
        } else {
            return ASTBlockStatement(statement: try! parseStatement())
        }
    }
    
    func expectAndConsumeToken(ttype: TokenType) throws {
        if tokens[current].type != ttype {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "\(ttype)")
        }
        current += 1
    }
    
    func parseStatement() throws -> ASTStatement {
        // statement = Return(exp) | Expression(exp) | Null | If(exp condition, statement then, statement? else)
        if tokens[current].type == TokenType.KeywordReturn {
            current += 1
            let stmt = ASTReturnStatement(exp: try! parseExpr(precedence: 0))
            if tokens[current].type == TokenType.Semicolon {
                current += 1
                return stmt
            } else {
                throw ParsingError.unexpectedToken(found: tokens[current], expected: "Semicolon to end Statement")
            }
        } else if tokens[current].type == .Semicolon {
            current += 1
            return ASTNullStatement()
        } else if tokens[current].type == .KeywordIf {
            //“if" "(" <exp> ")" <statement> ["else" <statement>]
            current += 1
            if tokens[current].type != .OpenParen { throw ParsingError.unexpectedToken(found: tokens[current], expected: "open paren") }
            current += 1
            let cond = try! parseExpr(precedence: 0)
            if tokens[current].type != .CloseParen { throw ParsingError.unexpectedToken(found: tokens[current], expected: "close paren") }
            current += 1
            let stmt = try! parseStatement()
            if tokens[current].type != .KeywordElse {
                return ASTIfStatement(condition: cond, then: stmt)
            } else {
                current += 1
                let els = try! parseStatement()
                return ASTIfStatement(condition: cond, then: stmt, els: els)
            }
        } else {
            let exp_stmt = ASTExpressionStatement(exp: try! parseExpr(precedence: 0))
            try! expectAndConsumeToken(ttype: .Semicolon)
            return exp_stmt
        }
    }
    
    func parseDeclaration() throws -> ASTDeclaration {
        // “<declaration> ::= "int" <identifier> ["=" <exp>] ";
        if tokens[current].type != .KeywordInt {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "int keyword to start declaration")
        }
        current += 1 // Consume 'int'
        if tokens[current].type != .Identifier {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "identifier for declaration")
        }
        let identifier = tokens[current]
        current += 1 // Consume identifier
        
        if tokens[current].type == .Semicolon {
            current += 1 
            return ASTDeclaration(identifier: identifier.lexeme)
        } else if tokens[current].type == .Assignment {
            current += 1
            let initval = try! parseExpr(precedence: 0)
            if tokens[current].type == .Semicolon {
                current += 1
            } else {
                throw ParsingError.unexpectedToken(found: tokens[current], expected: "Semicolon to end assignment")
            }
            return ASTDeclaration(identifier: identifier.lexeme, init_val: initval)
        }
        throw ParsingError.unexpectedToken(found: tokens[current], expected: "Either ; or initial value assignment")
    }
    
    func parseExpr(precedence: Int) throws -> ASTExpr {
        // <exp> ::= <factor> | <exp> <binop> <exp>
        
        var left = try! parseFactor()
        if tokens[current].type == .Increment || tokens[current].type == .Decrement {
            let op = tokens[current].lexeme
            current += 1
            return ASTPostfixOpExpr(op: op, left: left)
        }
        while PRECEDENCE_ORDER[tokens[current].lexeme] != nil && PRECEDENCE_ORDER[tokens[current].lexeme]! >= precedence  {
            let op = tokens[current].lexeme
            if op == "=" {
                current += 1
                let right = try! parseExpr(precedence: PRECEDENCE_ORDER[op]!)
                left = ASTAssignmentExpr(left: left, right: right)
            } else if op == "?" {
                let middle = try! parseConditionalMiddle()
                let right = try! parseExpr(precedence: PRECEDENCE_ORDER[op]!)
                left = ASTConditionalExpr(cond: left, exp1: middle, exp2: right)
            } else if op == "+=" || op == "-=" || op == "*=" || op == "/=" || op == "%=" || op == "|=" || op == "&=" || op == "<<=" || op == ">>=" || op == "^=" {
                current += 1
                let right = try! parseExpr(precedence: PRECEDENCE_ORDER[op]!)
                left = ASTCompoundAssignmentExpr(left: left, right: right, op: op)
            } else {
                current += 1
                let right = try! parseExpr(precedence: PRECEDENCE_ORDER[op]! + 1)
                left = ASTBinaryExpr(left: left, right:right, op: op)
            }
        }
        return left
    }
    
    func parseConditionalMiddle() throws -> ASTExpr {
        current += 1
        let mid = try! parseExpr(precedence: 0)
        if tokens[current].type != .Colon {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: ": for ternary expr")
        }
        current += 1
        return mid
    }
    
    func parseFactor() throws -> ASTExpr {
        // <factor> ::= <int> | <identifier> | <unop> <factor> | "(" <exp> ")
        if tokens[current].type == .Constant {
            current += 1
            return ASTConstantFactor(value: Int(tokens[current-1].lexeme)!)
        } else if tokens[current].type == .BitwiseComplement || tokens[current].type == .Negation || tokens[current].type == .LogicalNot {
            let op: Token = tokens[current]
            current += 1
            let rt = try! parseFactor()
            return ASTUnaryFactor(op: op.lexeme, right: rt)
        } else if tokens[current].type == .Increment || tokens[current].type == .Decrement {
            let op: Token = tokens[current]
            current += 1
            let rt = try! parseFactor()
            return ASTPrefixOpExpr(op: op.lexeme, right: rt)
        } else if tokens[current].type == .OpenParen {
            current += 1
            let inner_exp = try! parseExpr(precedence: 0)
            if tokens[current].type != .CloseParen {
                throw ParsingError.unexpectedToken(found: tokens[current], expected: ")")
            }
            current += 1
            return inner_exp
        } else if tokens[current].type == .Identifier {
            let variable = ASTVarExpr(identifier: tokens[current].lexeme)
            current += 1
            return variable
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Constant Int token")
        }
    }
    
    func parseIdentifier() throws -> String {
        // Expect identifier
        if tokens[current].type == .Identifier {
            current += 1
            return tokens[current - 1].lexeme
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Identifier token")
        }
    }
    

}
