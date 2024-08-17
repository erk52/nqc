//
//  Assembly.swift
//  nqc
//
//  Created by Edward Kish on 8/16/24.
//

import Foundation

protocol Assembly {
    
}

struct AsmProgram: Assembly {
    var function_definition: AsmFunction
    
    func emitCode() -> String {
        return function_definition.emitCode()
    }
}

struct AsmFunction: Assembly{
    var name: ASTIdentifier
    var instructions: [AsmInstr]
    func emitCode() -> String {
        var output = "\t.globl _\(name.identifier.lexeme)\n"
        output += "_\(name.identifier.lexeme):\n"
        for inst in instructions {
            output += "\t" + inst.emitCode() + "\n"
        }
        return output
    }
}

protocol AsmInstr: Assembly {
    func emitCode() -> String
    
}
struct Mov: AsmInstr, Assembly {
    var src: AsmOperand
    var dest: AsmOperand
    func emitCode() -> String {
        return "movl \(src.code()), \(dest.code())"
    }
}

struct Ret: AsmInstr, Assembly {
    func emitCode() -> String {
        return "ret"
    }
    
}

protocol AsmOperand: Assembly {
    func code() -> String
}

struct Imm: AsmOperand {
    var int: Int
    func code() -> String {
        return "$<\(int)>"
    }
    
}

struct Register: AsmOperand {
    var name = "%eax"
    func code() -> String {
        return name
    }
}

