package main

import "core:strings"
import "core:os"
import "core:fmt"

import "log"

Interpret_Result_Type :: enum {
    Success,
    Parse_Error,
    File_Error,
}

Interpret_Result :: struct {
    kind: Interpret_Result_Type,
    
    parse_result: Parse_Result,
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
    interpreter: ^Interpreter
) {
    res := parse_chunk(line)
    if len(res.errors) > 0 {
        for err in res.errors {
            fmt.println(err.text)
        }
     }
    else {
        run_ast(res.ast, interpreter)
    }
}

run_ast :: proc(program: AST, interpreter: ^Interpreter) {
    log.trace("run_ast")
    for statement in program.statements {
        run_statement(statement, interpreter)
    }
    for value in interpreter.values {
        fmt.println(value)
    }
}

run_statement :: proc(statement: ^AST_Statement, interpreter: ^Interpreter) {
    log.trace("run_statement")
    base := cast(^AST_Base)statement
    if base.type == .Assignment {
        run_assignment(cast(^AST_Assignment)statement, interpreter)
    }
}

run_assignment :: proc(statement: ^AST_Assignment, interpreter: ^Interpreter) {
    log.trace("run_assignment")
    variable_name := statement.identifier.name_token.text
    arg := statement.expression
    val := get_expression_value(arg, interpreter)
    fmt.printf("Assign: \"%s\" to \"%s\"\n", val, variable_name)
    interpreter.values[variable_name] = val
    // fmt.printf("Assigning value to %s: %s\n", variable_name, val)
}

get_expression_value :: proc(
    expression: ^AST_Expression, 
    interpreter: ^Interpreter,
) -> string 
{   
    log.trace("get_expression_value")
    base := cast(^AST_Base)expression
    if base.type == .NumberLiteral {
        num := cast(^AST_NumberLiteral)expression
        return num.number.text
    }
    else if base.type == .Identifier {
        identifier := cast(^AST_Identifier)expression
        val, ok := interpreter.values[identifier.name_token.text]
        fmt.printf("Lookup: \"%s\" -> \"%s\"\n", 
            identifier.name_token.text, 
            (val if ok else "nil")
        )
        if ok {
            return val
        }
        return "nil"
    }
    return "nil"
}