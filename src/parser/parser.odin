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

// We could create an error record at the most specific point, and then bubble up
// the error struct, and if any production wants to override the error message it can,
// once the error struct is bubbled all the way up to parse_statement, it can be printed

// For now the error approach is that 
// the most specific calls will do error reporting

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
    program: ast.Program,
}

Parser :: struct {
    result: ^Result,
    tokens: [dynamic]tok.Token,
    token_count: int,
    current: int,
}

parse_chunk :: proc(chunk: string) -> ^Result {
    tokenize_result := tok.tokenize_chunk(chunk)

    // tok.print_tokens(tokenize_result)
    // TODO: These should be passed on as parser errors
    tok.print_errors(tokenize_result)

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
    trace_push("parse_program")
    defer trace_pop("parse_program")
    
    trace_current_parse_state(parser)
    
    for {
        statement, ok := parse_statement(parser)
        if !ok {
            break
        }
        append(&parser.result.program.statements, statement)
    }
    
    if !is_at_end(parser) {
        t := peek(parser, 0)
        error(parser, .Unexpected_Token, fmt.aprintf(
            "Unexpected token: %s. Expected EOF", 
            tok.descriptive_text(t)),
        )
    }
}

declaration_start_pattern :: []tok.Type{.Identifier, .Colon}
assignment_pattern :: []tok.Type{.Identifier, .Equals}

parse_statement :: proc(parser: ^Parser) -> (^ast.Statement, bool) {
    log.trace()
    trace_push("parse_statement")
    defer trace_pop("parse_statement")

    skip_empty_lines(parser)

    for !is_at_end(parser) {
        trace_current_parse_state(parser)
        
        t := peek(parser, 0)
        
        if match(parser, declaration_start_pattern, true) {
            decl, ok := parse_declaration(parser)
            return &decl.base_stmt, ok
        }
        else if match(parser, assignment_pattern, true) {
            assign, ok := parse_assignment(parser)
            return cast(^ast.Statement)assign, ok
        }
        else if is_value_lead(t) {
            expr, ok := parse_expression(parser)
            if !ok {
                return nil, false
            }

            if !expect_newline(parser) {
                consume_line(parser)
            }

            stmt := ast.new(ast.Expression_Statement)
            stmt.expression = expr
            return &stmt.base_stmt, true
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
            consume_line(parser)
            advance(parser)
        }
    }

    return nil, false
}

inferred_declaration_pattern :: []tok.Type{.Identifier, .Colon, .Equals}
explicit_declaration_pattern :: []tok.Type{.Identifier, .Colon, .Identifier}

parse_declaration :: proc(parser: ^Parser) -> (^ast.Declaration, bool) {
    if match(parser, inferred_declaration_pattern, true) {
        decl, ok := parse_inferred_declaration(parser)
        return decl, true
    }
    else if match(parser, explicit_declaration_pattern, true) {
        // TODO
        consume_line(parser)
        return nil, false
    }
    else {
        unexpected_token(parser, "Expected a \"=\" or a type after :")
        consume_line(parser)
        return nil, false
    }
}

parse_assignment :: proc(parser: ^Parser) -> (^ast.Assignment, bool) {
    trace_push("parse_assignment")
    defer trace_pop("parse_assignment")
    assert(!is_at_end(parser))

    trace_current_parse_state(parser)

    name_token := peek(parser, 0)
    advance(parser, len(assignment_pattern)) // identifier equals
    identifier := ast.new_identifier(name_token)

    expression, ok := parse_expression(parser)
    if !ok {
        return nil, false
    }
    
    if !expect_newline(parser) {
        consume_line(parser)
    }

    return ast.new_assignment(identifier, expression), true
}

parse_expression :: proc(parser: ^Parser) -> (^ast.Expression, bool) {
    trace_push("parse_expression")
    defer trace_pop("parse_expression")
    trace_current_parse_state(parser)
    
    if is_at_end(parser) {
        unexpected_token(parser, "Unexpected end of file. Expected expression")
        return nil, false
    }

    val, ok := parse_value(parser)
    if !ok {
        return val, ok
    }

    node := cast(^ast.Expression)val

    for !is_expression_end(peek(parser, 0).type) && tok.is_operator(peek(parser, 0).type)
    {
        node, ok = parse_operation(parser, node)
        if !ok {
            return nil, false
        }
    }

    return node, true
}

is_expression_end :: proc(tok_type: tok.Type) -> bool {
    return tok_type == .EOF || tok_type == .Comma || tok_type == .Right_Bracket
}

parse_operation :: proc(
    parser: ^Parser, 
    prev_node: ^ast.Expression,
) -> (^ast.Expression, bool)
{
    trace_push("parse_operation")
    defer trace_pop("parse_operation")
    buf := strings.builder_make(0, 100)
    ast.print_node(&buf, prev_node)
    
    trace_current_parse_state(parser)

    op := peek(parser)
    if !tok.is_operator(op.type) {
        unexpected_token_message(
            parser, 
            fmt.aprintf(
                "Unexpected %s Expected operator", 
                tok.descriptive_text(op),
            ),
        )
        return nil, false
    }
    advance(parser)

    val, ok := parse_value(parser)
    if !ok {
        return nil, false
    }

    if ast.is_value(&prev_node.base) {
        return ast.new_binary(prev_node, val, op), true
    }
    else if bin, ok := prev_node.derived_node.(^ast.Binary_Op); ok {
        if tok.precedence(bin.operator) >= tok.precedence(op) {
            return ast.new_binary(prev_node, val, op), true
        }
        else {
            bin.right = ast.new_binary(bin.right, val, op)
            return prev_node, true
        }
    }
    else {
        assert(
            false, 
            "Unexpected arg to parse_operation. Not a value or binary op",
        )
    }
    
    return nil, false
}

parse_inferred_declaration :: proc(parser: ^Parser) -> (^ast.Declaration, bool) {
    trace_push("parse_inferred_declaration")
    defer trace_pop("parse_inferred_declaration")
    assert(!is_at_end(parser))  
    trace_current_parse_state(parser)

    iden := ast.new_identifier(peek(parser, 0))
    advance(parser, len(inferred_declaration_pattern))

    expr, ok := parse_expression(parser)
    if !ok {
        // TODO better error
        unexpected_token(parser, "Invalid expression")
        consume_line(parser)
        return nil, false
    }
    
    if !expect_newline(parser) {
        consume_line(parser)
    }

    return ast.new_declaration(iden, expr), true
}

value_lead :: []tok.Type {.Identifier, .Number, .String, .Left_Bracket}
is_value_lead :: proc(token: ^tok.Token) -> bool {
    for lead in value_lead {
        if token.type == lead do return true
    }
    return false
}

func_call_pattern :: []tok.Type { .Identifier, .Left_Paren, .Identifier, .Right_Paren }
parse_value :: proc(parser: ^Parser) -> (^ast.Value, bool) {
    trace_push("parse_value")
    defer trace_pop("parse_value")
    trace_current_parse_state(parser)

    if is_at_end(parser) {
        return nil, false
    }
    
    t := peek(parser, 0)
    if t.type == .Number {
        advance(parser)
        return &ast.new_number_literal(t).base_val, true
    }
    else if t.type == .String {
        advance(parser)
        return &ast.new_string_literal(t).base_val, true
    }
    else if t.type == .Left_Bracket {
        array, ok := parse_array_literal(parser)
        return &array.base_val, ok
    }
    else if match(parser, func_call_pattern, true) {
        func_call, ok := parse_func_call(parser)
        return &func_call.base_val, ok
    }
    else if t.type == .Identifier {
        advance(parser)
        return cast(^ast.Value)ast.new_identifier(t), true
    }
    else {
        unexpected_token(
            parser, 
            fmt.aprintf(
                "Unexpected token %s", 
                tok.descriptive_text(t),
            ),
        )
        return nil, false
    }
}

parse_func_call :: proc(parser: ^Parser) -> (^ast.Func_Call, bool) {
    trace_push("parse_func_call")
    defer trace_pop("parse_func_call")
    trace_current_parse_state(parser)

    ok, func_tok := expect(parser, .Identifier)
    if !ok do return nil, false
    
    func_name := ast.new_identifier(func_tok)
    
    ok, _ = expect(parser, .Left_Paren)
    if !ok do return nil, false

    // TODO arg list
    arg_tok: ^tok.Token
    ok, arg_tok = expect(parser, .Identifier)
    if !ok do return nil, false
    
    arg := ast.new_identifier(arg_tok)

    ok, _ = expect(parser, .Right_Paren)
    if !ok do return nil, false

    return ast.new_func_call(func_name, arg), true
}

parse_array_literal :: proc(parser: ^Parser) -> (^ast.Array_Literal, bool) {
    trace_push("parse_array_literal")
    defer trace_pop("parse_array_literal")
    trace_current_parse_state(parser)

    ok, _ := expect(parser, .Left_Bracket)
    if !ok do return nil, false

    t := peek(parser)
    if t.type == .Right_Bracket {
        advance(parser)
        return ast.new_array_literal(nil), true
    }

    items: [dynamic]^ast.Expression

    loop: for {
        expr: ^ast.Expression
        expr, ok = parse_expression(parser)
        if !ok do return nil, false

        t := peek(parser)
        #partial switch t.type {
            case .Comma:
                append(&items, expr)
                advance(parser)
                continue

            case .Newline:
                unexpected_token_message(
                    parser, 
                    fmt.aprintf("Unexpected %s, expected ] to end array", t),
                )
                break loop
            
            case .Right_Bracket:
                append(&items, expr)
                advance(parser)
                break loop

            case: 
                unexpected_token_message(
                    parser, 
                    fmt.aprintf("Unexpected %s, expected ] to end array", t),
                )
                return nil, false
        }
    }

    arr := ast.new_array_literal(items[:])
    return arr, true
}

skip_empty_lines :: proc(parser: ^Parser) {
    for {
        i := 0
        for ; peek(parser, i).type == .Tab; i += 1 {}
        
        t := peek(parser, i).type
        if t == .Newline {
            advance(parser, i + 1)
        }
        else if t == .EOF {
            advance(parser, i)
            return
        }
        else {
            return
        }
    }
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

advance_single :: proc(parser: ^Parser) -> tok.Token {
    res := parser.tokens[parser.current]
    parser.current += 1
    trace_current_parse_state(parser)
    return res
}

advance_many :: proc(parser: ^Parser, num: int) -> bool {
    for i := 0; i < num; i+=1 {
        if is_at_end(parser) {
            return false
        }
        parser.current += 1
        trace_current_parse_state(parser)
    }
    return true
}

advance :: proc {
    advance_single,
    advance_many,
}

expect :: proc(parser: ^Parser, type: tok.Type, adv := true) -> (bool, ^tok.Token) {
    t := peek(parser)
    if t.type != type {
        unexpected_token(parser, t, type)
        return false, nil
    }
    if adv do advance(parser)
    return true, t
}

expect_newline :: proc(parser: ^Parser, adv := false) -> bool {
    t := peek(parser)
    if t.type != .EOF && t.type != .Newline {
        unexpected_token(
            parser, 
            fmt.aprintf(
                "Unexpected %s, expected newline", 
                tok.descriptive_text(t),
            ),
        )
        return false
    }
    if adv do advance(parser)
    return true
}

// expect_any :: proc(
//     parser: ^Parser, 
//     types: []tok.Type, 
//     adv := true
// ) -> (bool, ^tok.Token) 
// {
//     t := peek(parser)
//     for expected in types {
//         if expected == t.type {
//             if adv do advance(parser)
//             return true, t
//         }
//     }
//     if adv do advance(parser)
//     return false, nil
// }

peek :: proc(parser: ^Parser, offset := 0) -> ^tok.Token {
    if parser.current + offset >= parser.token_count {
        return &tok.EOF
    }
    return &parser.tokens[parser.current + offset]
}

is_at_end :: proc(parser: ^Parser) -> bool {
    return parser.current + 1 >= parser.token_count
}

error :: proc(parser: ^Parser, type: Error_Type, text: string) {
    log.error(text)
    append(&parser.result.errors, Error {
        type = type,
        text = text,
    })
}

unexpected_token_token :: proc(
    parser: ^Parser, 
    token: ^tok.Token, 
    expected: tok.Type,
) {
    expected_token := tok.Token {
        type = expected,
    }
    text := fmt.aprintf(
        "Unexpected %s Expected %s", 
        tok.descriptive_text(token),
        tok.descriptive_text(&expected_token),
    )
    error(parser, .Unexpected_Token, text)
}

unexpected_token_message :: proc(parser: ^Parser, text: string) {
    error(parser, .Unexpected_Token, text)
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

consume_line :: proc(parser: ^Parser) {
    consume_until_type(parser, .Newline)
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
    strings.write_string(&builder, "| ")
    for i := 0 ;; i += 1 {
        t := peek(parser, i)
        done := t.type == .EOF || t.type == .Newline
        strings.write_string(&builder, tok.debug_text(t))

        if done {
            break
        }
    }
    trace(strings.to_string(builder))
}

trace_nest := 0

trace_push :: proc(msg: string) {
    trace(fmt.aprintf("<%s>", msg))
    trace_nest += 1
}

trace :: proc(msg: string) {
    buf := strings.builder_make(0, 32)
    for i := 0; i < trace_nest; i += 1 {
        strings.write_string(&buf, "  ")
    }
    strings.write_string(&buf, msg)
    log.trace(strings.to_string(buf))
}

trace_pop :: proc(msg: string) {
    trace_nest -= 1
    trace(fmt.aprintf("</%s>", msg))
}