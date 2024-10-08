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
    var body: ASTBlock
    func toString() -> String {
        let out = "Function(name=\(name), body=\(body.toString()))"
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

struct ASTBlock: ASTNode {
    var body: [ASTBlockItem]
    func toString() -> String {
        var out = "CompoundStatement(body = ["
        for it in body {
            out += it.toString() + ", "
        }
        out += "])"
        return out
    }
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

struct ASTCompoundStatement: ASTStatement {
    var body: ASTBlock
    func toString() -> String {
        return "CompoundStatement(body=\(body.toString()))"
    }
}

struct ASTBreakStatement: ASTStatement {
    var label: String?
    func toString() -> String {
        return "BreakStatement(\(label ?? "")"
    }
}

struct ASTContinueStatement: ASTStatement {
    var label: String?
    func toString() -> String {
        return "ContinueStatement(\(label ?? "")"
    }
}

struct ASTWhileStatement: ASTStatement {
    var label: String?
    var cond: ASTExpr
    var body: ASTStatement
    func toString() -> String {
        return "While(cond=\(cond.toString()), body=\(body.toString())"
    }
}

struct ASTDoWhileStatement: ASTStatement {
    var label: String?
    var cond: ASTExpr
    var body: ASTStatement
    func toString() -> String {
        return "DoWhile(cond=\(cond.toString()), body=\(body.toString())"
    }
}

protocol ASTForInit: ASTNode {}

struct ASTForStatement: ASTStatement {
    var label: String?
    var initializer: ASTForInit
    var cond: ASTExpr?
    var post: ASTExpr?
    var body: ASTStatement
    func toString() -> String {
        var out = "For("
        if label != nil { out += "label=(\(label!)), "}
        out += "init=\(initializer.toString()), "
        if cond != nil { out += "cond=\(cond!.toString()), "}
        if post != nil { out += "post=\(post!.toString()), "}
        out += "body=\(body.toString()))"
        return out
    }
}

struct ASTForInitDecl: ASTForInit {
    var init_decl: ASTDeclaration
    func toString() -> String {
        return "ForInitDecl(dec=(\(init_decl.toString())))"
    }
}

struct ASTForInitExpr: ASTForInit {
    var init_exp: ASTExpr?
    func toString() -> String {
        if init_exp != nil {
            return "ForInitExp(exp=(\(init_exp!.toString())))"
        } else {
            return "ForInitExp(exp=())"
        }
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

    func expectAndConsumeToken(ttype: TokenType) throws {
        if tokens[current].type != ttype {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "\(ttype)")
        }
        current += 1
    }
    func expectAndDontConsumeToken(ttype: TokenType) throws -> Token {
        if tokens[current].type != ttype {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "\(ttype)")
        }
        return tokens[current]
    }

    func parse() throws -> ASTProgram {
        
        let p = ASTProgram(function: try! parseFunction())
        if current < tokens.count {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "EOF")
        }
        return p
    }
    
    func parseFunction() throws -> ASTFunction {
        // Expect "int <identifier> ( void ) <block>
        var name: String
        var body: ASTBlock
        
        try! expectAndConsumeToken(ttype: .KeywordInt)
        name = try!expectAndDontConsumeToken(ttype: .Identifier).lexeme
        current += 1
        try! expectAndConsumeToken(ttype: .OpenParen)
        try! expectAndConsumeToken(ttype: .KeywordVoid)
        try! expectAndConsumeToken(ttype: .CloseParen)
        
        body = try! parseBlock()
        
        return ASTFunction(name: name, body: body)
    }
    
    func parseBlock() throws -> ASTBlock {
        // "{" {<block-item>} "}"
        var items: [ASTBlockItem] = []
        try! expectAndConsumeToken(ttype: .OpenBrace)
        while tokens[current].type != .CloseBrace {
            print("Try to parse block item: \(tokens[current].lexeme)")
            items.append(try! parseBlockItem())
        }
        try! expectAndConsumeToken(ttype: .CloseBrace)
        return ASTBlock(body: items)
    }
    
    func parseBlockItem() throws -> ASTBlockItem {
        // <block-item> ::= <statement> | <declaration>
        if tokens[current].type == .KeywordInt {
            return ASTBlockDeclaration(declaration: try! parseDeclaration())
        } else {
            return ASTBlockStatement(statement: try! parseStatement())
        }
    }
    
    func parseForInit() throws -> ASTForInit {
        // “<for-init> ::= <declaration> | [<exp>] ;
        if tokens[current].type == .KeywordInt {
            return ASTForInitDecl(init_decl: try! parseDeclaration())
        } else if tokens[current].type == .Semicolon {
            try! expectAndConsumeToken(ttype: .Semicolon)
            return ASTForInitExpr()
        } else {
            let ex = try! parseExpr(precedence: 0)
            try! expectAndConsumeToken(ttype: .Semicolon)
            return ASTForInitExpr(init_exp: ex)
        }
    }
    
    func parseStatement() throws -> ASTStatement {
        // statement = Return(exp) | Expression(exp) | Null | If(exp condition, statement then, statement? else) | Compound(block)
        print("Parse statement. Current token: \(tokens[current].lexeme)")
        if tokens[current].type == TokenType.KeywordReturn {
            current += 1
            let stmt = ASTReturnStatement(exp: try! parseExpr(precedence: 0))
            try! expectAndConsumeToken(ttype: .Semicolon)
            return stmt
        } else if tokens[current].type == .Semicolon {
            current += 1
            return ASTNullStatement()
        } else if tokens[current].type == .KeywordIf {
            //“if" "(" <exp> ")" <statement> ["else" <statement>]
            current += 1
            try! expectAndConsumeToken(ttype: .OpenParen)
            let cond = try! parseExpr(precedence: 0)
            try! expectAndConsumeToken(ttype: .CloseParen)
            let stmt = try! parseStatement()
            if tokens[current].type != .KeywordElse {
                return ASTIfStatement(condition: cond, then: stmt)
            } else {
                current += 1
                let els = try! parseStatement()
                return ASTIfStatement(condition: cond, then: stmt, els: els)
            }
        } else if tokens[current].type == .OpenBrace {
            return ASTCompoundStatement(body: try! parseBlock())
        } else if tokens[current].type == .KeywordBreak {
            try! expectAndConsumeToken(ttype: .KeywordBreak)
            try! expectAndConsumeToken(ttype: .Semicolon)
            return ASTBreakStatement()
        } else if tokens[current].type == .KeywordContinue {
            try! expectAndConsumeToken(ttype: .KeywordContinue)
            try! expectAndConsumeToken(ttype: .Semicolon)
            return ASTContinueStatement()
        } else if tokens[current].type == .KeywordWhile {
            try! expectAndConsumeToken(ttype: .KeywordWhile)
            try! expectAndConsumeToken(ttype: .OpenParen)
            let ex = try! parseExpr(precedence: 0)
            try! expectAndConsumeToken(ttype: .CloseParen)
            let bod = try! parseStatement()
            return ASTWhileStatement(cond: ex, body: bod)
        } else if tokens[current].type == .KeywordDo {
            try! expectAndConsumeToken(ttype: .KeywordDo)
            let bod = try! parseStatement()
            try! expectAndConsumeToken(ttype: .KeywordWhile)
            try! expectAndConsumeToken(ttype: .OpenParen)
            let ex = try! parseExpr(precedence: 0)
            try! expectAndConsumeToken(ttype: .CloseParen)
            try! expectAndConsumeToken(ttype: .Semicolon)
            return ASTDoWhileStatement(cond: ex, body: bod)
        } else if tokens[current].type == .KeywordFor {
            try! expectAndConsumeToken(ttype: .KeywordFor)
            try! expectAndConsumeToken(ttype: .OpenParen)
            print("Parsing For initializer")
            let finit = try! parseForInit()
            print("Found \(finit.toString())")
            
            var cond: ASTExpr?
            var post: ASTExpr?
            if tokens[current].type != .Semicolon {
                print("Parsing middle For Condition")
                cond = try? parseExpr(precedence: 0)
                print("Found \(cond!.toString())")
            }
            try! expectAndConsumeToken(ttype: .Semicolon)
            if tokens[current].type != .CloseParen {
                print("Parsing post condition")
                post = try! parseExpr(precedence: 0)
                print("Found \(post!.toString())")
            }
            try! expectAndConsumeToken(ttype: .CloseParen)
            let bod = try! parseStatement()
            return ASTForStatement(initializer: finit, cond: cond, post: post, body: bod)
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
