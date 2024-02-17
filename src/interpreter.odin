package main

import "core:strings"
import "core:os"
import "core:fmt"

import "log"
import "parser"
import "ast"

Interpret_Result_Type :: enum {
    Success,
    Parse_Error,
    File_Error,
}

Interpret_Result :: struct {
    kind: Interpret_Result_Type,
    
    parse_result: parser.Result,
    file_error: os.Errno,
}

Interpreter :: struct {
    // TODO: This is a dumb hack for now
    values: map[string]string,
}

// Read and run input line by line
run_interpreter :: proc() {
    interpreter: Interpreter
    interpreter.values = make(map[string]string)

    chunk := strings.builder_make(0, 256)
    defer strings.builder_destroy(&chunk)

    line_builder := strings.builder_make(0, 256)
    defer strings.builder_destroy(&line_builder)
    
    for {
        line, err := get_line_input(&line_builder)
        if err != os.ERROR_NONE {
            fmt.printf("Unable to read input: Errno %d\n", err)
            return
        }

        // TODO: This should come from an exit() call instead
        if line == "quit" || line == "stop" || line == "exit" {
            break
        }

        strings.write_string(&chunk, line)
        result: Interpret_Result
        interpret_chunk(line, &result, &interpreter)

        strings.builder_reset(&line_builder)
    }
}

interpret_chunk :: proc(
    line: string, result: ^Interpret_Result, 
    interpreter: ^Interpreter,
) {
    res := parser.parse_chunk(line)
    if len(res.errors) > 0 {
        for err in res.errors {
            fmt.println(err.text)
        }
     }
    else {
        ast.print_ast(res.ast)
        //run_ast(res.ast, interpreter)
    }
}

run_ast :: proc(program: ast.AST, interpreter: ^Interpreter) {
    
}