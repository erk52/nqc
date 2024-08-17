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

protocol ASTValueNode: ASTNode {
    var value: any ASTValueNode {get set}
}

func add_tabs(to s: String) -> String {
    var out = ""
    for line in s.lines {
        out += "\t" + line
    }
    return out
}

struct ASTProgram: ASTNode {
    var function: ASTFunction
    func toString() -> String {
        var out = "Program (\n"
        for line in function.toString().lines {
            out += "\t" + line
        }
        out += ")"
        return out
    }
    
    func toAsm() -> AsmProgram {
        return AsmProgram(function_definition: function.toAsm())
    }
}

struct ASTFunction: ASTNode {
    var name: ASTIdentifier
    var body: ASTStatement
    func toString() -> String {
        var out = "Function(\n"
        out += "\tname=\(name.toString())\n"
        out += "\tbody=\n\(body.toString())\n"
        out += ")"
        return out
    }
    
    func toAsm() -> AsmFunction {
        return AsmFunction(name: name, instructions: body.toAsm())
    }
}

struct ASTStatement: ASTNode {
    var exp: ASTNode
    func toString() -> String {
        return "Statement(\n\texp=\(exp.toString())\n)"
    }
    
    func toAsm() -> [AsmInstr] {
        var expn = exp
        while (type(of: expn) is ASTInt) {
            expn = expn.value
        }
        return [Mov(src: Imm(int: Int(expn.value.value.lexeme)!), dest: Register()), Ret()]
    }
    
}

struct ASTExp: ASTValueNode {
    var value: ASTValueNode
    func toString() -> String {
        return "Exp(\n\t\(value.toString())\n)"
    }
}

struct ASTUnary: ASTNode {
    var op: Token
    var right: ASTNode
    func toString() -> String {
        return "Unary(\n\toperator=\(op.lexeme)\n\tright=\(right.toString())\n)"
    }
}

struct ASTIdentifier: ASTNode {
    var identifier: Token
    func toString() -> String {
        return "Identifier(\(identifier.lexeme))"
    }
}

struct ASTInt: ASTValueNode {
    var value: Token
    func toString() -> String {
        return "Int(\(value))"
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
        return ASTProgram(function: try! parseFunction())
    }
    
    func parseFunction() throws -> ASTFunction {
        // Expect "int <identifier> ( void ) { <stmt> }
        var name: ASTIdentifier
        var body: ASTStatement
        if tokens[current].type == .KeywordInt{
            current += 1
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "int keyword at function start")
        }
        if tokens[current].type == .Identifier {
            name = ASTIdentifier(identifier: tokens[current])
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
            let stmt = ASTStatement(exp: try! parseExp())
            if tokens[current].type == TokenType.Semicolon {
                current += 1
                return stmt
            } else {
                throw ParsingError.unexpectedToken(found: tokens[current], expected: "Semicolon to end Statement")
            }
        }
        throw ParsingError.unexpectedToken(found: tokens[current], expected: "return keyword to start Statement")
    }
    
    func parseExp() throws -> ASTNode {
        // <int> | <unop> <exp> | ( <exp> )
        if tokens[current].type == .Constant {
            current += 1
            return ASTExp(value: ASTInt(value: tokens[current-1]))
        } else if tokens[current].type == .BitwiseComplement || tokens[current].type == .Negation {
            let op: Token = tokens[current]
            current += 1
            var rt = try! parseExp()
            return ASTUnary(op: op, right: rt)
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
    
    func parseIdentifier() throws -> ASTIdentifier {
        // Expect identifier
        if tokens[current].type == .Identifier {
            current += 1
            return ASTIdentifier(identifier: tokens[current - 1])
        } else {
            throw ParsingError.unexpectedToken(found: tokens[current], expected: "Identifier token")
        }
    }
    

}
