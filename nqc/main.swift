//
//  main.swift
//  nqc
//
//  Created by Edward Kish on 8/15/24.
//

import Foundation

func readFile(path: String) -> String {
    return try! String(contentsOfFile: path)
}

func main() {
    
    var program: String
    print(CommandLine.arguments)
    if CommandLine.arguments.count > 1 {
        program = readFile(path: CommandLine.arguments[1])
    } else {
        program = "int main(void) {\n// test case w/ multi-digit constant\nreturn 100;\n}"          //int main(void) { return 42; }"
    }
    program = readFile(path: "/Users/ekish/dev/c_comp/writing-a-c-compiler-tests/tests/chapter_2/valid/bitwise.c")
    
    let reg = try! tokenizeRegex(input: program)
    //print(reg)
    //print(program)
    //print(tks)
    //print("========")
    var parser = Parser(tokens: reg)
    let ast = try! parser.parse()
    //print(ast.toString())
    //print("=========")
    let asm = ast.toAsm()
    //print(asm)
    //print("=========")
    print(asm.emitCode())
}


main()
