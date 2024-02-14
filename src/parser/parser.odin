package parser

import "core:fmt"
import "core:strings"

import "../log"
import "../ast"
import tok "../tokenizer"

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

Result_Type :: enum {
    Success,
    Error,
}

Error_Type :: enum {
    Unexpected_Token,
    Expected_Newline,
}

Error :: struct {
    type: Error_Type,
    text: string,
}

Result :: struct {
    errors: [dynamic]Error,
    ast: ast.AST,
}

Parser :: struct {
    result: ^Result,
    tokens: [dynamic]tok.Token,
    token_count: int,
    current: int,
}

parse_chunk :: proc(chunk: string) -> ^Result {
    tokenize_result := tok.tokenize_chunk(chunk)

    // print_tok.tokens(tok.result)
    // TODO: These should be passed on as parser errors
    tok.print_tokenize_errors(tokenize_result)

    parser := Parser {
        result = new(Result),
        tokens = tokenize_result.tokens,
        token_count = len(tokenize_result.tokens),
    }

    parse_program(&parser)

    return parser.result
}

print_parse_errors :: proc(results: ^Result) {
    for error in results.errors {
        fmt.println(error.text)
    }
}

parse_program :: proc(parser: ^Parser) {
    log.trace("parse_program")
    for {
        statement, ok := parse_statement(parser)
        if !ok {
            break
        }
        append(&parser.result.ast.statements, statement)
    }
    
    if !is_at_end(parser) {
        t := peek(parser, 0)
        add_error(parser, Error {
            type = .Unexpected_Token,
            text = fmt.aprintf(
                "Unexpected token: [%s]\"%s\". Expected EOF", 
                t.type, t.text),
        })
    }
}

declaration_start_pattern :: []tok.Type{.Identifier, .Colon}
inferred_declaration_pattern :: []tok.Type{.Identifier, .Colon, .Equals}
explicit_declaration_pattern :: []tok.Type{.Identifier, .Colon, .Identifier}
assignment_pattern :: []tok.Type{.Identifier, .Equals}

parse_statement :: proc(parser: ^Parser) -> (^ast.Statement, bool) {
    log.trace("parse_statement")
    for !is_at_end(parser) {
        trace_current_parse_state(parser)
        
        t := peek(parser, 0)
        log.trace("Starting statement with: ", tok.descriptive_text(t))
        
        if match(parser, declaration_start_pattern, true) {
            if match(parser, inferred_declaration_pattern, true) {
                decl, ok := parse_inferred_declaration(parser)
                
                if !ok {
                    consume_until_type(parser, .Newline)
                    return nil, false
                }
                else {
                    return cast(^ast.Statement)decl, true
                }
            }
            else if match(parser, explicit_declaration_pattern, true) {
                // TODO
                return nil, false
            }
            else {
                // TODO better error message
                unexpected_token(parser, "Expected a type or \"=\" after :")
                consume_until_type(parser, .Newline)
                return nil, false
            }
        }
        else if match(parser, assignment_pattern, true) {
            assign, ok := parse_assignment(parser)

            if !ok {
                consume_until_type(parser, .Newline)
                return nil, false
            }
            else {
                return cast(^ast.Statement)assign, true
            }
        }
        else if t.type == .Identifier {
            // Expression - Identifier
            expr, ok := parse_expression(parser)
            if !ok {
                consume_until_type(parser, .Newline)
                return nil, false
            }
            return cast(^ast.Statement)expr, true
        }
        else if t.type == .Number {
            // Expression = Number literal
            expr, ok := parse_expression(parser)
            if !ok {
                consume_until_type(parser, .Newline)
                return nil, false
            }
            return cast(^ast.Statement)expr, true
        }
        else if t.type == .Newline {
            // Ignore newlines
            // TODO: This might not be the right 
            //  thing to do in an interpreter setting
            advance(parser)
        }
        else {
            err_text := fmt.aprintf(
                "Unexpected token. Cannot start statement with %s", 
                tok.descriptive_text(t),
            )
            unexpected_token(parser, err_text)
            consume_until_type(parser, .Newline)
            advance(parser)
        }
    }

    return nil, false
}

expect_token :: proc(
    parser: ^Parser, 
    offset: int, 
    type: tok.Type, 
    ignore_whitespace: bool,
) -> (^tok.Token, bool) {

    if ignore_whitespace {
        if offset > 0 {
            fmt.printf("UNEXPECTED SCENARIO, IGNORE WHITESPACE BUT LOOKING AHEAD. NEED TO IMPLEMENT")
        }

        consume_whitespace(parser)
    }

    t := peek(parser, offset)
    if t.type != type {
        add_error(parser, Error {
            type = .Unexpected_Token,
            text = fmt.aprintf(
                "Unexpected %s. Expected \"%s\"", 
                tok.descriptive_text(t), 
                type,
            ),
        })
        return nil, false
    }
    return t, true
}

match :: proc(
    parser: ^Parser,
    expected: []tok.Type, 
    ignore_whitespace: bool,
) -> bool 
{
    i := 0
    for expect in expected {
        if peek(parser, i).type == .EOF {
            return false
        }
        if ignore_whitespace {
            consume_whitespace(parser)
        }
        t := peek(parser, i)
        if t.type != expect {
            return false
        }
        i += 1
    }
    return true
}

is_statement_terminator :: proc(token: ^tok.Token) -> bool {
    return token.type == .Newline || token.type == .EOF
}

parse_assignment :: proc(parser: ^Parser) -> (^ast.Assignment, bool) {
    log.trace("parse_assignment")
    assert(!is_at_end(parser))

    name_token := peek(parser, 0)
    advance(parser, len(assignment_pattern)) // identifier equals
    identifier := ast.new_identifier(name_token)

    expression, ok := parse_expression(parser)
    if !ok {
        return nil, false
    }

    return ast.new_assignment(identifier, expression), true
}

parse_expression :: proc(parser: ^Parser) -> (^ast.Expression, bool) {
    log.trace("parse_expression")
    trace_current_parse_state(parser)
    
    if is_at_end(parser) {
        unexpected_token(parser, "Unexpected end of file. Expected expression")
        return nil, false
    }

    val, ok := parse_value(parser)
    if !ok {
        consume_until_type(parser, .Newline)
        return nil, false
    }

    node := val

    for !is_at_end(parser) && tok.is_operator(peek(parser, 0).type) {
        node, ok = parse_operation(parser, val)
        if !ok {
            return nil, false
        }
    }
    return node, true
}

parse_operation :: proc(
    parser: ^Parser, 
    prev_node: ^ast.Expression,
) -> (^ast.Expression, bool)
{
    return nil, false
}

parse_inferred_declaration :: proc(parser: ^Parser) -> (^ast.Declaration, bool) {
    log.trace("parse_inferred_declaration")
    assert(!is_at_end(parser))  
    
    iden := ast.new_identifier(peek(parser, 0))
    advance(parser, len(inferred_declaration_pattern))

    expr, ok := parse_expression(parser)
    if !ok {
        // TODO better error
        unexpected_token(parser, "Invalid expression")
        return nil, false
    }
    
    return ast.new_declaration(iden, expr), true
}

// Literal or identifier
parse_value :: proc(parser: ^Parser) -> (^ast.Expression, bool) {
    log.trace("parse_value")
    
    if is_at_end(parser) {
        return nil, false
    }
    
    t := peek(parser, 0)
    res: ^ast.Expression
    if t.type == .Number {
        advance(parser)
        return cast(^ast.Expression)ast.new_number_literal(t), true
    }
    else if t.type == .Identifier {
        advance(parser)
        return cast(^ast.Expression)ast.new_identifier(t), true
    }
    else {
        unexpected_token(parser, fmt.aprintf("Unexpected token [%s]", tok.descriptive_text(t)))
        return nil, false
    }
}

advance_single :: proc(parser: ^Parser) -> tok.Token {
    res := parser.tokens[parser.current]
    parser.current += 1
    return res
}

advance_many :: proc(parser: ^Parser, num: int) -> bool {
    for i := 0; i < num; i+=1 {
        if is_at_end(parser) {
            return false
        }
        parser.current += 1
    }
    return true
}

advance :: proc {
    advance_single,
    advance_many,
}


peek :: proc(parser: ^Parser, offset: int) -> ^tok.Token {
    if parser.current + offset >= parser.token_count {
        return &tok.EOF
    }
    return &parser.tokens[parser.current + offset]
}

is_at_end :: proc(parser: ^Parser) -> bool {
    return parser.current + 1 >= parser.token_count
}

add_error :: proc(parser: ^Parser, error: Error) {
    append(&parser.result.errors, error)
}

unexpected_token_token :: proc(parser: ^Parser, token: ^tok.Token) {
    add_error(parser, Error {
        type = .Unexpected_Token,
        text = token.text,
    })
}

unexpected_token_message :: proc(parser: ^Parser, text: string) {
    add_error(parser, Error {
        type = .Unexpected_Token,
        text = text,
    })
}

unexpected_token :: proc {
    unexpected_token_token,
    unexpected_token_message,
}

consume_whitespace :: proc(parser: ^Parser) {
    for !is_at_end(parser){
        if peek(parser, 0).type == .Tab {
            advance(parser)
        }
        else {
            break
        }
    }
}

consume_until_type :: proc(parser: ^Parser, type: tok.Type) -> int {
    count := 0
    for !is_at_end(parser) && peek(parser, 0).type != type {
        advance(parser)
        count += 1
    }
    return count
}

trace_current_parse_state :: proc(parser: ^Parser) {
    builder := strings.builder_make(0, 100)
    for i := 0 ;; i += 1 {
        t := peek(parser, i)
        done := t.type == .EOF || t.type == .Newline
        strings.write_string(&builder, tok.debug_text(t))

        if done {
            break
        }
    }
    log.trace(strings.to_string(builder))
}