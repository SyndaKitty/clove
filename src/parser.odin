package main

import "core:fmt"

Parse_Result_Type :: enum {
    Success,
    Error,
}

Parse_Error_Type :: enum {
    Expecting_Newline,
    Incomplete_Production,
}

Parse_Error :: struct {
    type: Parse_Error_Type,
    text: string,
}

Parse_Result :: struct {
    errors: [dynamic]Parse_Error,
    ast: AST,
}

Parser :: struct {
    result: ^Parse_Result,
    tokens: [dynamic]Token,
    token_count: int,
    current: int,
}

parse_chunk :: proc(chunk: string) -> Parse_Result {
    tokenize_result := tokenize_chunk(chunk)
    defer free_tokenize_result(tokenize_result)

    print_tokenize_results(tokenize_result)

    parser := Parser {
        result = new(Parse_Result),
        tokens = tokenize_result.tokens,
        token_count = len(tokenize_result.tokens)
    }

    // _parse_program(&parser)

    return {}
}

@(private="file")
_parse_program :: proc(parser: ^Parser) {
    for _match_statement(parser) {}
    token := parser.tokens[parser.current]
    if token.type != .EOF {
        
    }
}

@(private="file")
_match_statement :: proc(parser: ^Parser) -> bool {
    return false
}

@(private="file")
_advance :: proc(parser: ^Parser) -> Token {
    res := parser.tokens[parser.current]
    parser.current += 1
    return res
}

@(private="file")
_is_at_end :: proc(parser: ^Parser) -> bool {
    return parser.current >= parser.token_count
}

@(private="file")
_add_error :: proc(parser: ^Parser, error: Parse_Error) {
    append(&parser.result.errors, error)
}