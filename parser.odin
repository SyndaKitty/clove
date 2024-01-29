package main

import "core:fmt"

Parse_Result_Type :: enum {
    Success,
    Error,
}

Parse_Result_Error_Type :: enum {
    Expecting_Newline,
    Incomplete_Production,
}

Parse_Result :: struct {
    type: Parse_Result_Type,
    error: Parse_Result_Error_Type,
    ast: Ast,
}

parse_chunk :: proc(chunk: string) -> Parse_Result {
    tokenize_result := tokenize_chunk(chunk)
    defer free_tokenize_result(tokenize_result)

    print_tokenize_results(tokenize_result)
    fmt.println()

    return {}
}