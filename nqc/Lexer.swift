//
//  Lexer.swift
//  nqc
//
//  Created by Edward Kish on 8/16/24.
//

import Foundation

enum LexerError: Error {
    case unidentifiedToken(found: String)
}

extension String {
    func getChar(at index: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: index)
        let end = self.index(self.startIndex, offsetBy: index + 1)
        return String(self[start..<end])
    }
    
    func substring(from: Int, to: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: from)
        let end = self.index(self.startIndex, offsetBy: to)
        return String(self[start..<end])
    }
}

let id_chars = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_")

enum TokenType {
    case KeywordInt
    case KeywordIf
    case KeywordElse
    case KeywordVoid
    case KeywordReturn
    case KeywordDo
    case KeywordBreak
    case KeywordWhile
    case KeywordContinue
    case KeywordFor
    case Question
    case Colon
    case Identifier
    case OpenParen
    case CloseParen
    case OpenBrace
    case CloseBrace
    case Constant
    case Semicolon
    case BitwiseComplement
    case Negation
    case Decrement
    case Increment
    case Plus
    case Star
    case Slash
    case Percent
    case BitwiseAnd
    case BitwiseOr
    case BitwiseXOr
    case LeftShift
    case RightShift
    case LogicalNot
    case LogicalAnd
    case LogicalOr
    case Assignment
    case PlusAssignment
    case MinusAssignment
    case MultAssignment
    case DivAssignment
    case ModAssignment
    case AndAssign
    case OrAssign
    case XOrAssign
    case SHLAssign
    case SHRAssign
    case Equal
    case NotEqual
    case LessThan
    case GreaterThan
    case LessEqual
    case GreaterEqual
}

let keywords: [String: TokenType] = [
    "int": TokenType.KeywordInt, "return":TokenType.KeywordReturn, "void": TokenType.KeywordVoid,
    "if": TokenType.KeywordIf, "else": TokenType.KeywordElse, "for": TokenType.KeywordFor,
    "do": TokenType.KeywordDo, "while": TokenType.KeywordWhile, "break": TokenType.KeywordBreak,
    "continue": TokenType.KeywordContinue,
]

struct Token {
    var type: TokenType
    var lexeme: String
    var line: Int
}

let regexMap = [
    TokenType.Constant: /^[0-9]+\b/,
    TokenType.OpenParen: /^\(/,
    TokenType.CloseParen: /^\)/,
    TokenType.OpenBrace: /^\{/,
    TokenType.CloseBrace: /^\}/,
    TokenType.KeywordReturn: /^return\b/,
    TokenType.KeywordInt: /^int\b/,
    TokenType.KeywordVoid: /^void\b/,
    TokenType.KeywordIf: /^if\b/,
    TokenType.KeywordElse: /^else\b/,
    TokenType.KeywordDo: /^do\b/,
    TokenType.KeywordFor: /^for\b/,
    TokenType.KeywordBreak: /^break\b/,
    TokenType.KeywordContinue: /^continue\b/,
    TokenType.KeywordWhile: /^while\b/,
    TokenType.Semicolon: /^;/,
    TokenType.BitwiseComplement: /^~/,
    TokenType.Negation: /^-/,
    TokenType.Decrement: /^--/,
    TokenType.Increment: /^\+\+/,
    TokenType.Plus: /^\+/,
    TokenType.Star: /^\*/,
    TokenType.Slash: /^\//,
    TokenType.Percent: /^%/,
    TokenType.BitwiseOr: /^\|/,
    TokenType.BitwiseXOr: /^\^/,
    TokenType.LeftShift: /^<</,
    TokenType.RightShift: /^>>/,
    TokenType.LogicalAnd: /^\&\&/,
    TokenType.LogicalOr: /^\|\|/,
    TokenType.LogicalNot: /^\!/,
    TokenType.Assignment: /^\=/,
    TokenType.PlusAssignment: /^\+\=/,
    TokenType.MinusAssignment: /^-\=/,
    TokenType.MultAssignment: /^\*\=/,
    TokenType.DivAssignment: /^\/\=/,
    TokenType.ModAssignment: /^\%\=/,
    TokenType.AndAssign: /^\&\=/,
    TokenType.OrAssign: /^\|\=/,
    TokenType.XOrAssign: /^\^\=/,
    TokenType.SHLAssign: /^<<\=/,
    TokenType.SHRAssign: /^>>\=/,
    TokenType.Equal: /^\==/,
    TokenType.NotEqual: /^\!\=/,
    TokenType.LessThan: /^</,
    TokenType.GreaterThan: /^>/,
    TokenType.LessEqual: /^<\=/,
    TokenType.GreaterEqual: /^>\=/,
    TokenType.Question: /^\?/,
    TokenType.Colon: /^\:/,
    TokenType.Identifier: /^[a-zA-Z_]\w*\b/,
]

func tokenizeRegex(input: String) throws -> [Token] {
    var output: [Token] = []
    var line = 1
    var i = 0
    while i < input.count {
        let cur = input.index(input.startIndex, offsetBy: i)
        if input[cur].isWhitespace {
            if input[cur] == "\n" { line += 1}
            i += 1
            continue
        } else if input[cur] == "/" && input.getChar(at: i+1) == "/" {
            while input.getChar(at: i) != "\n" {
                i += 1
            }
            continue
        } else if input[cur] == "/" && input.getChar(at: i+1) == "*" {
            while input.substring(from: i, to: i + 2) != "*/" {
                if input[cur] == "\n" { line += 1}
                i += 1
            }
            i += 2
            continue
        }
        var longest = ""
        var longest_type: TokenType? = nil
        for (tok_type, regex) in regexMap {
            if let this_match = try? regex.firstMatch(in: input.substring(from: i, to: input.count)) {
                if this_match.0.count > longest.count {
                    longest = String(this_match.0)
                    longest_type = tok_type
                }
            } else {
                continue
            }
        }
        if longest == "" {
            throw LexerError.unidentifiedToken(found: input.substring(from: i, to: input.count))
        }
        if keywords.keys.contains(longest){
            output.append(Token(type: keywords[longest]!, lexeme: longest, line: line))
        } else {
            output.append(Token(type: longest_type!, lexeme: longest, line: line))
        }
        i += longest.count
    }
    return output
    
}

