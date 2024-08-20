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
    case KeywordVoid
    case KeywordReturn
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
}

let keywords = ["int": TokenType.KeywordInt, "return":TokenType.KeywordReturn, "void": TokenType.KeywordVoid]

struct Token {
    var type: TokenType
    var lexeme: String
}

func tokenize(_ input: String) throws -> [Token] {
    var output: [Token] = []
    
    var i = 0
    while i < input.count {
        let cur = input.index(input.startIndex, offsetBy: i)
        
        if input[cur].isWhitespace {
            //print(i, input[cur], "Whitespace")
            i += 1
            continue
        } else if input[cur] == "/" && input.getChar(at: i+1) == "/" {
            while input.getChar(at: i) != "\n" {
                i += 1
            }
            continue
        } else if input[cur] == "/" && input.getChar(at: i+1) == "*" {
            while input.substring(from: i, to: i + 2) != "*/" {
                i += 1
            }
            i += 2
            continue
        } else if input[cur] == ";" {
            //print(i, input[cur], "Semicolon")
            output.append(Token(type: .Semicolon, lexeme: ";"))
            i += 1
        } else if input[cur] == "{" {
            //print(i, input[cur], "OpenBrace")
            output.append(Token(type: .OpenBrace, lexeme: "{"))
            i += 1
        } else if input[cur] == "}" {
            //print(i, input[cur], "CloseBrace")
            output.append(Token(type: .CloseBrace, lexeme: "{"))
            i += 1
        } else if input[cur] == "(" {
            //print(i, input[cur], "OParen")
            output.append(Token(type: .OpenParen, lexeme: "("))
            i += 1
        } else if input[cur] == ")" {
            //print(i, input[cur], "CParen")
            output.append(Token(type: .CloseParen, lexeme: ")"))
            i += 1
        } else if input[cur].isNumber {
            //print(i, input[cur], "Number start")
            let start = cur
            while i < input.count - 1 && ( i == input.count - 1 || input[input.index(input.startIndex, offsetBy: i+1)].isNumber) {
                i += 1
            }
            let value = input[start..<input.index(input.startIndex, offsetBy: i+1)]
            output.append(Token(type: .Constant, lexeme: String(value)))
            //print("Got num: \(value)")
            i += 1
        } else if input[cur].isLetter {
            //print(i, input[cur], "Word?")
            let start = cur
            while i < input.count - 1 && ( i == input.count - 1 || id_chars.contains(input[input.index(input.startIndex, offsetBy: i+1)])) {
                i += 1
            }
            let value = String(input[start..<input.index(input.startIndex, offsetBy: i+1)])
            
            //print("Got word \(value)")
            
            switch value {
            case "int":
                output.append(Token(type: .KeywordInt, lexeme: value))
                i += 1
            case "void":
                output.append(Token(type: .KeywordInt, lexeme: value))
                i += 1
            case "return":
                output.append(Token(type: .KeywordReturn, lexeme: value))
                i += 1
            default:
                output.append(Token(type: .Identifier, lexeme: value))
                i += 1
            }
        } else {
            throw LexerError.unidentifiedToken(found: String(input[cur]))
        }
    }
    return output
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
    TokenType.Semicolon: /^;/,
    TokenType.BitwiseComplement: /^~/,
    TokenType.Negation: /^-/,
    TokenType.Decrement: /^--/,
    TokenType.Identifier: /^[a-zA-Z_]\w*\b/,
]

func tokenizeRegex(input: String) throws -> [Token] {
    var output: [Token] = []
    
    var i = 0
    while i < input.count {
        let cur = input.index(input.startIndex, offsetBy: i)
        if input[cur].isWhitespace {
            i += 1
            continue
        } else if input[cur] == "/" && input.getChar(at: i+1) == "/" {
            while input.getChar(at: i) != "\n" {
                i += 1
            }
            continue
        } else if input[cur] == "/" && input.getChar(at: i+1) == "*" {
            while input.substring(from: i, to: i + 2) != "*/" {
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
            output.append(Token(type: keywords[longest]!, lexeme: longest))
        } else {
            output.append(Token(type: longest_type!, lexeme: longest))
        }
        i += longest.count
    }
    return output
    
}

