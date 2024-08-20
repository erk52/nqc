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
        return "Program(function=\(function.toString())"
    }
}

struct ASTFunction: ASTNode {
    var name: String
    var body: ASTStatement
    func toString() -> String {
        return "Function(name=\(name), body=\(body.toString()))"
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

protocol ASTExpr: ASTNode {
    
}

struct ASTConstantExpr: ASTExpr {
    var value: Int
    func toString() -> String {
        return "Constant(\(value))"
    }
}

struct ASTUnaryExpr: ASTExpr {
    var op: String
    var right: ASTExpr
    
    func toString() -> String {
        return "Unary(\(op), \(right.toString())"
    }
}


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
        // Expect "int <identifier> ( void ) { <stmt> }
        var name: String
        var body: ASTStatement
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
        
        body = try! parseStatement()
        
        if tokens[current].type == .CloseBrace {
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Close brace to end func body")
        }
        return ASTFunction(name: name, body: body)
    }
    
    func parseStatement() throws -> ASTStatement {
        // Expect 'return' token
        if tokens[current].type == TokenType.KeywordReturn {
            current += 1
            let stmt = ASTReturnStatement(exp: try! parseExp())
            if tokens[current].type == TokenType.Semicolon {
                current += 1
                return stmt
            } else {
                throw ParsingError.unexpectedToken(found: tokens[current], expected: "Semicolon to end Statement")
            }
        }
        throw ParsingError.unexpectedToken(found: tokens[current], expected: "return keyword to start Statement")
    }
    
    func parseExp() throws -> ASTExpr {
        // <int> | <unop> <exp> | ( <exp> )
        if tokens[current].type == .Constant {
            current += 1
            return ASTConstantExpr(value: Int(tokens[current-1].lexeme)!)
        } else if tokens[current].type == .BitwiseComplement || tokens[current].type == .Negation {
            let op: Token = tokens[current]
            current += 1
            let rt = try! parseExp()
            return ASTUnaryExpr(op: op.lexeme, right: rt)
        } else if tokens[current].type == .OpenParen {
            current += 1
            let inner_exp = try! parseExp()
            if tokens[current].type != .CloseParen {
                throw ParsingError.unexpectedToken(found: tokens[current], expected: ")")
            }
            current += 1
            return inner_exp
        }else {
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
