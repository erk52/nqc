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

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    return output
}

func main() {
    
    var program: String
    var filename: String
    //print(CommandLine.arguments)
    if CommandLine.arguments.count > 1 {
        let p = CommandLine.arguments[1]
        filename = p//.components(separatedBy: "/").last!
        
        //PREPROCESS FILE
        shell("arch -x86_64 gcc -E -P \(filename) -o \(filename.replacingOccurrences(of: ".c", with: ".pc"))")
        program = readFile(path: filename.replacingOccurrences(of: ".c", with: ".pc"))
    } else {
        filename = "/Users/ekish/dev/c_comp/writing-a-c-compiler-tests/tests/chapter_7/valid/use_in_inner_scope.c"
        shell("arch -x86_64 gcc -E -P \(filename) -o \(filename.replacingOccurrences(of: ".c", with: ".pc"))")
        program = readFile(path: filename.replacingOccurrences(of: ".c", with: ".pc"))
    }
    print(program)
    //print("=====")
    let reg = try! tokenizeRegex(input: program)
    //print(reg)
    let parser = Parser(tokens: reg)
    let ast = try! parser.parse()
    print("========")
    for ln in ast.function.body.body {
        print(ln.toString())
    }
    print("========")
    let validator = SemanticAnalysis()
    let validated = validator.validate(ast)
    print(validated.toString())
    print("========")
    let tachometer = TACEmitter()
    let tac = tachometer.convertAST(program: validated)
    for ln in tac.function.body {
        print(ln)
    }
    let asem = emitAssembly(program: tac)
    for item in asem.function.body {
        print(item)
    }
    let final = asem.emitCode()
    let assembly_file = filename.replacingOccurrences(of: ".c", with: ".s")
    let exec_file = filename.replacingOccurrences(of: ".c", with: "")
    try! final.write(toFile: assembly_file, atomically: false, encoding: String.Encoding.utf8)
    let s = shell("arch -x86_64 gcc \(assembly_file) -o \(exec_file)")
    print(s)
}

main()
