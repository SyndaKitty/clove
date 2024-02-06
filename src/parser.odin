package main

import "core:fmt"
import "core:strings"

Parse_Result_Type :: enum {
    Success,
    Error,
}

Parse_Error_Type :: enum {
    Unexpected_Token,
    Expected_Newline,
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

EOF_Token := Token {
    type = .EOF,
}

parse_chunk :: proc(chunk: string) -> ^Parse_Result {
    tokenize_result := tokenize_chunk(chunk)

    print_tokenize_tokens(tokenize_result)
    // TODO: These should be passed on as parser errors
    print_tokenize_errors(tokenize_result)

    parser := Parser {
        result = new(Parse_Result),
        tokens = tokenize_result.tokens,
        token_count = len(tokenize_result.tokens),
    }

    _parse_program(&parser)

    return parser.result
}

print_parse_errors :: proc(results: ^Parse_Result) {
    for error in results.errors {
        fmt.println(error.text)
    }
}

@(private="file")
_parse_program :: proc(parser: ^Parser) {
    for {
        statement, ok := _statement(parser)
        if !ok {
            break
        }
        append(&parser.result.ast.statements, statement)
    }
    
    if !_is_at_end(parser) {
        t := _peek(parser, 0)
        _add_error(parser, Parse_Error {
            type = .Unexpected_Token,
            text = fmt.aprintf(
                "Unexpected token: [%s]\"%s\". Expected EOF", 
                t.type, t.text),
        })
    }
}

@(private="file")
_statement :: proc(parser: ^Parser) -> (^AST_Statement, bool) {
    for !_is_at_end(parser) {
        t := _peek(parser, 0)
        
        if t.type == .Print {
            print, ok := _print(parser)
            if ok {
                return cast(^AST_Statement)(print), true
            }
            _consume_until(parser, .Newline)
        }
        else if t.type == .Identifier {
            assignment, ok := _assignment(parser)
            if ok {
                return cast(^AST_Statement)(assignment), true
            }
            _consume_until(parser, .Newline)
        }
        else {
            _add_error(parser, Parse_Error {
                type = .Unexpected_Token,
                text = fmt.aprintf("Unexpected token: [%s]\"%s\". Expected statement", t.type, t.text),
            })
            _consume_until(parser, .Newline)
        }
    }

    return nil, false
}

@(private="file")
_print :: proc(parser: ^Parser) -> (^AST_Print, bool) {
    if _is_at_end(parser) {
        return nil, false
    }
    
    ok: bool
    
    list := [?]Token_Type {.Print, .Left_Paren}
    if !_expect_list_advance(parser, list[:], true) {
        return nil, false
    }

    expression_ast: ^AST_Expression
    if expression_ast, ok = _expression(parser); !ok {
        return nil, false
    }

    if _, ok = _expect(parser, 0, .Right_Paren, true); !ok {
        return nil, false
    }
    _advance(parser)

    _expect_statement_terminator(parser, 0, true)
    _advance(parser)

    print := new(AST_Print)
    print.type = .Print
    print.arg = expression_ast
    return print, true
}

@(private="file")
_expect :: proc(
    parser: ^Parser, 
    offset: int, 
    type: Token_Type, 
    ignore_whitespace: bool
) -> (^Token, bool) {

    if ignore_whitespace {
        if offset > 0 {
            fmt.printf("UNEXPECTED SCENARIO, IGNORE WHITESPACE BUT LOOKING AHEAD. NEED TO IMPLEMENT")
        }

        _consume_whitespace(parser)
    }

    t := _peek(parser, offset)
    if t.type != type {
        _add_error(parser, Parse_Error {
            type = .Unexpected_Token,
            text = fmt.aprintf("Unexpected token: [%s]\"%s\". Expected \"%s\"", t.type, t.text, type),
        })
        return nil, false
    }
    return t, true
}

@(private="file")
_expect_list_advance :: proc(
    parser: ^Parser, 
    expected_types: []Token_Type, 
    ignore_whitespace: bool,
) -> bool {
    for expected in expected_types {
        if t, ok := _expect(parser, 0, expected, ignore_whitespace); !ok {
            return false
        }
        _advance(parser)
    }
    return true
}

@(private="file")
_expect_statement_terminator :: proc(
    parser: ^Parser, 
    offset: int, 
    ignore_whitespace: bool
) -> (^Token, bool) {
    if ignore_whitespace {
        _consume_whitespace(parser)
    }

    t := _peek(parser, offset)
    if !_is_statement_terminator(t) {
        _add_error(parser, Parse_Error {
            type = .Unexpected_Token,
            text = fmt.aprintf("Expected end of statement but found: %s", t.text),
        })
        return nil, false
    }
    return t, true
}

@(private="file")
_match :: proc(
    parser: ^Parser, 
    expected: []Token_Type, 
    ignore_whitespace: bool
) -> (out: [dynamic]^Token, ok: bool) {    
    for expect in expected {
        if _is_at_end(parser) {
            ok = false
            return
        }
        if ignore_whitespace {
            _consume_whitespace(parser)
        }
        t := _peek(parser, 0)
        if t.type != expect {
            delete(out)
            ok = false
            return
        }
        append(&out, t)
        _advance(parser)
    }
    ok = true
    return
}

@(private="file")
_is_statement_terminator :: proc(token: ^Token) -> bool {
    return token.type == .Newline || token.type == .EOF
}

@(private="file")
_is_whitespace :: proc(token: ^Token) -> bool {
    return token.type == .Tab
}

@(private="file")
_assignment :: proc(parser: ^Parser) -> (^AST_Assignment, bool) {
    if _is_at_end(parser) {
        return nil, false
    }

    ok: bool
    identifier: ^Token
    if identifier, ok = _expect(parser, 0, .Identifier, false); !ok {
        return nil, false
    }
    _advance(parser)

    list := [?]Token_Type {.Colon, .Equals}
    if !_expect_list_advance(parser, list[:], true) {
        return nil, false
    }

    expression: ^AST_Expression
    if expression, ok = _expression(parser); !ok {
        return nil, false
    }

    assignment := new(AST_Assignment)
    assignment.type = .Assignment
    assignment.identifier = identifier
    assignment.expression = expression

    return assignment, true
}

@(private="file")
_expression :: proc(parser: ^Parser) -> (^AST_Expression, bool) {
    if _is_at_end(parser) {
        return nil, false
    }
    
    t := _peek(parser, 0)
    if t.type == .Number {
        _advance(parser)
        expression := new(AST_NumberLiteral)
        expression.type = .NumberLiteral
        expression.number = t
        return cast(^AST_Expression)(expression), true
    }
    else if t.type == .Identifier {
        _advance(parser)
        expression := new(AST_Identifier)
        expression.type = .Identifier
        expression.identifier = t
        return cast(^AST_Expression)(expression), true
    }
    
    return nil, false
}

@(private="file")
_advance :: proc(parser: ^Parser) -> Token {
    res := parser.tokens[parser.current]
    parser.current += 1
    return res
}

@(private="file")
_skip :: proc(parser: ^Parser, num: int) {
    i := 0
    for !_is_at_end(parser) && i < num {
        parser.current += 1
        i += 1
    }
}

@(private="file")
_peek :: proc(parser: ^Parser, offset: int) -> ^Token {
    if parser.current + offset >= parser.token_count {
        return &EOF_Token
    }
    return &parser.tokens[parser.current + offset]
}

@(private="file")
_is_at_end :: proc(parser: ^Parser) -> bool {
    return parser.current + 1 >= parser.token_count
}

@(private="file")
_add_error :: proc(parser: ^Parser, error: Parse_Error) {
    append(&parser.result.errors, error)
}

@(private="file")
_consume_whitespace :: proc(parser: ^Parser) {
    for !_is_at_end(parser){
        if _is_whitespace(_peek(parser, 0)) {
            _advance(parser)
        }
        else {
            break
        }
    }
}

@(private="file")
_consume_until_capture :: proc(parser: ^Parser, builder: strings.Builder, type: Token_Type) {
    for !_is_at_end(parser) && _peek(parser, 0).type != type{
        // TODO capture
        _advance(parser)
    }
}

@(private="file")
_consume_until_throw :: proc(parser: ^Parser, type: Token_Type) {
    for !_is_at_end(parser) && _peek(parser, 0).type != type{
        _advance(parser)
    }
}

_consume_until :: proc {
    _consume_until_capture,
    _consume_until_throw,
}