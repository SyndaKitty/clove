package main

import "core:strings"
import "core:os"
import "core:fmt"

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

// Read and run input line by line
run_interpreter :: proc() {
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
        interpret_chunk(line, &result)

        strings.builder_reset(&line_builder)
    }
}

interpret_chunk :: proc(line: string, result: ^Interpret_Result) {
    res := parse_chunk(line)
}