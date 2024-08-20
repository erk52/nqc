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
    print(CommandLine.arguments)
    shell("arch -x86_64 zsh")
    if CommandLine.arguments.count > 1 {
        var p = CommandLine.arguments[1]
        filename = p//.components(separatedBy: "/").last!
        
        //PREPROCESS FILE
        shell("gcc -E -P \(filename) -o \(filename.replacingOccurrences(of: ".c", with: ".pc"))")
        program = readFile(path: filename.replacingOccurrences(of: ".c", with: ".pc"))
    } else {
        program = "int main(void) {\n// test case w/ multi-digit constant\nreturn 100;\n}"          //int main(void) { return 42; }"
        filename = "test.c"
    }
    
    let reg = try! tokenizeRegex(input: program)
    print(reg)
    var parser = Parser(tokens: reg)
    let ast = try! parser.parse()
    print(ast.toString())
    var tachometer = TACEmitter()
    let tac = tachometer.convertAST(program: ast)
    print(tac.toString())
    
    let asem = emitAssembly(program: tac)
    let final = asem.emitCode()
    let assembly_file = filename.replacingOccurrences(of: ".c", with: ".s")
    let exec_file = filename.replacingOccurrences(of: ".c", with: "")
    try! final.write(toFile: assembly_file, atomically: false, encoding: String.Encoding.utf8)
    s = shell("gcc \(assembly_file) -o \(exec_file)")
    print(s)
}


main()
