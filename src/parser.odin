package main

import "core:fmt"
import "core:strings"

import "log"

// TODO Potential improvement
// Should probably cascade errors upward when parsing
// For example when a declaration is expecting a value
// the value proc could pass (End of Line) Error struct back to expression proc
// and expression proc passes back to declaration proc
// This way we can write errors that are more informed
// Currently the best we could do is "Unexpected end of file, expecting value"
// However if we sent back the error, we could say 
// Declaration for A is missing a value
// It could be tricky because what if there was A := 1 +
// Then the ReadOperator function would return (End of Line) as well
// We would need a good way to disambiguate the various cases
// It gets complicated fast!
// Maybe there could be a context enum in the error proc
// So in case 1 it would be {type = End of Line, context = Value}
// in case 2 it would be {type = End of Line, context = Operator}
// Separately, we could track if the error has already been reported ??

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
    log.trace("parse_program")
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

declaration_pattern :: []Token_Type{.Identifier, .Colon, .Equals}
assignment_pattern :: []Token_Type{.Identifier, .Equals}

@(private="file")
_statement :: proc(parser: ^Parser) -> (^AST_Statement, bool) {
    for !_is_at_end(parser) {
        t := _peek(parser, 0)
        log.trace("Starting statement with: ", _token_error_text(t))

        if _match_peek(parser, declaration_pattern, true) {
            decl, ok := _declaration(parser)
            
            if !ok {
                _consume_until(parser, .Newline)
                return nil, false
            }
            else {
                return cast(^AST_Statement)decl, true
            }
        }
        else if _match_peek(parser, assignment_pattern, true) {
            assign, ok := _assignment(parser)

            if !ok {
                _consume_until(parser, .Newline)
                return nil, false
            }
            else {
                return cast(^AST_Statement)assign, true
            }
        }
        else if t.type == .Identifier {
            // Expression - Identifier
            // TODO expr := _expression(parser)
            _advance(parser)
        }
        else if t.type == .Number {
            // Expression = Number literal
            // TODO expr := _expression(parser)
            _advance(parser)
        }
        else if t.type == .Newline {
            // Ignore newlines
            // TODO: This might not be the right 
            //  thing to do in an interpreter setting
            _advance(parser)
        }
        else {
            err_text := fmt.aprintf(
                "Unexpected %s. Expected statement", 
                _token_error_text(t),
            )
            _unexpected_token(parser, err_text)
            _consume_until(parser, .Newline)
            _advance(parser)
        }
    }

    return nil, false
}

@(private="file")
_expect :: proc(
    parser: ^Parser, 
    offset: int, 
    type: Token_Type, 
    ignore_whitespace: bool,
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
            text = fmt.aprintf(
                "Unexpected %s. Expected \"%s\"", 
                _token_error_text(t), 
                type,
            ),
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
    ignore_whitespace: bool,
) -> (^Token, bool) 
{
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
_match_peek :: proc(
    parser: ^Parser,
    expected: []Token_Type, 
    ignore_whitespace: bool,
) -> bool 
{
    i := 0
    for expect in expected {
        if _peek(parser, i).type == .EOF {
            return false
        }
        if ignore_whitespace {
            _consume_whitespace(parser)
        }
        t := _peek(parser, i)
        if t.type != expect {
            return false
        }
        i += 1
    }
    return true
}


@(private="file")
_match :: proc(
    parser: ^Parser, 
    expected: []Token_Type, 
    ignore_whitespace: bool
) -> (out: [dynamic]^Token, ok: bool) 
{
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
            // TODO: Need to remove this when we change memory management scheme
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
    log.trace("assignment")
    assert(!_is_at_end(parser))

    ok: bool
    name_token: ^Token
    if name_token, ok = _expect(parser, 0, .Identifier, false); !ok {
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

    identifier := identifier(name_token)
    return assignment(identifier, expression), true
}

@(private="file")
_expression :: proc(parser: ^Parser) -> (^AST_Expression, bool) {
    log.trace("Expression")
    _log_current_parse_state(parser)
    
    if _is_at_end(parser) {
        _unexpected_token(parser, "Unexpected end of file. Expected expression")
        return nil, false
    }

    val, ok := _read_value(parser)
    if !ok {
        _consume_until(parser, .Newline)
        return nil, false
    }
    log.trace("Got value")

    node := val

    for !_is_at_end(parser) && is_operator(_peek(parser, 0).type) {
        node, ok = _read_operation(parser, val)
        if !ok {
            return nil, false
        }
    }
    return node, true
}

_read_operation :: proc(
    parser: ^Parser, 
    prev_node: ^AST_Expression,
) -> (^AST_Expression, bool)
{
    return nil, false
}

@(private="file")
_declaration :: proc(parser: ^Parser) -> (^AST_Declaration, bool) {
    log.trace("Declaration")
    assert(!_is_at_end(parser))  
    
    iden := identifier(_peek(parser, 0))
    _log_current_parse_state(parser)
    _advance(parser, len(declaration_pattern))
    _log_current_parse_state(parser)

    expr, ok := _expression(parser)
    if !ok {
        _unexpected_token(parser, "Unexpected token: [%s]")
        return nil, false
    }
    
    return declaration(iden, expr), true
}

// Literal or identifier
@(private="file")
_read_value :: proc(parser: ^Parser) -> (^AST_Expression, bool) {
    log.trace("Value")
    
    if _is_at_end(parser) {
        return nil, false
    }
    
    t := _peek(parser, 0)
    res: ^AST_Expression
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
        expression.name_token = t
        return cast(^AST_Expression)(expression), true
    }
    else {
        _unexpected_token(parser, fmt.aprintf("Unexpected token [%s]", _token_error_text(t)))
        return nil, false
    }
}

@(private="file")
_advance_single :: proc(parser: ^Parser) -> Token {
    res := parser.tokens[parser.current]
    parser.current += 1
    return res
}

_advance_mutli :: proc(parser: ^Parser, num: int) -> bool {
    for i := 0; i < num; i+=1 {
        if _is_at_end(parser) {
            return false
        }
        parser.current += 1
    }
    return true
}

_advance :: proc {
    _advance_single,
    _advance_mutli,
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
_unexpected_token_token :: proc(parser: ^Parser, token: ^Token) {
    _add_error(parser, Parse_Error {
        type = .Unexpected_Token,
        text = token.text,
    })
}

@(private="file")
_unexpected_token_message :: proc(parser: ^Parser, text: string) {
    _add_error(parser, Parse_Error {
        type = .Unexpected_Token,
        text = text,
    })
}

@(private="file")
_unexpected_token :: proc {
    _unexpected_token_token,
    _unexpected_token_message,
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

// Give a representation of the token for an error message
//  it should be easy for a user to understand
_token_error_text :: proc(t: ^Token) -> string {
    switch t.type {
        case .Newline:      return "newline"
        case .Left_Paren:   return "\"(\""
        case .Right_Paren:  return "\")\""
        case .Dot:          return "\".\""
        case .Colon:        return "\":\""
        case .Equals:       return "\"=\""
        case .Tab:          return "tab"
        case .EOF:          return "end of file"
        case .Add:          return "\"+\""
        case .Subtract:     return "\"-\""
        case .Multiply:     return "\"*\""
        case .Divide:       return "\"/\""
        case .Identifier:   return fmt.aprintf("identifier \"%s\"", t.text)
        case .Number:       return fmt.aprintf("number \"%s\"", t.text)
        case .Unknown:      return fmt.aprintf("token \"%s\"", t.text)
    }
    return ""
}

_log_current_parse_state :: proc(parser: ^Parser) {
    log.trace(
        _token_error_text(_peek(parser, 0)), " ",
        _token_error_text(_peek(parser, 1)), " ",
        _token_error_text(_peek(parser, 2)), " ",
        _token_error_text(_peek(parser, 3)), " ",
    )
}