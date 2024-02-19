package tokenizer

import "core:unicode/utf8"
import "core:strings"
import "core:fmt"
import "../log"

// TODO: Adhere to Unicode standard
// https://www.unicode.org/reports/tr31/#D1

Result :: struct {
    tokens: [dynamic]Token,
    errors: [dynamic]Error,
    lines: [dynamic][]rune,
}

Error_Type :: enum {
    Unknown_Character,
    Malformed_Number,
    Invalid_Escape_Sequence,
    String_Missing_End,
    Comment_Missing_End,
    Misaligned_Tab,
}

Error :: struct {
    type: Error_Type,
    text: string,
    line_number: int,
    from: int,
    to: int,
}

Type :: enum {
    Left_Paren,
    Right_Paren,
    Dot,
    Colon,
    Equals,
    Tab,
    Number,
    Identifier,
    Newline,
    Add,
    Subtract,
    Multiply,
    Divide,
    String,
    Unknown,
    EOF,
}

EOF := Token {
    type = .EOF,
}

Token :: struct {
    type: Type,
    text: string,
    
    line_number: int,
    
    // indices within the line
    start: int, 
    end: int,
}

Tokenizer :: struct {
    result: ^Result,
    runes: []rune,
    rune_count: int,
    
    // rune index
    current: int,

    // line index of the start of the current token
    token_start: int,
    line_number: int,
    line_index: int,

    line_start: int,
}

Buffer :: ^strings.Builder

free_tokenize_result :: proc(result: ^Result) {
    for t in result.tokens {
        delete(t.text)
    }
    delete(result.tokens)
    delete(result.errors)
    free(result)
}

tokenize_chunk :: proc(chunk: string) -> ^Result {
    tokenizer: Tokenizer
    tokenizer.result = new(Result)
    tokenizer.runes = utf8.string_to_runes(chunk)
    tokenizer.rune_count = len(tokenizer.runes)

    for !is_at_end(&tokenizer) {
        scan_token(&tokenizer)
    }
    add_token(&tokenizer, .EOF)

    return tokenizer.result
}

print_tokens :: proc(results: ^Result) {
    for token in &results.tokens {
        fmt.print(debug_text(&token))
        if token.type == .Newline {
            fmt.println()
        }
    }
    fmt.println()
}

print_errors :: proc(results: ^Result) {
    for error in results.errors {
        if len(error.text) > 0 {
            fmt.println(error.text)
        }
        else {
            fmt.printf("[%s]\n", error.type)
        }

        for r in results.lines[error.line_number] {
            fmt.print(r)
        }
        for i := 0; i < error.from; i += 1 {
            fmt.print(" ")
        }
        fmt.println("^")
    }
}

scan_token :: proc(tokenizer: ^Tokenizer) {
    trace_current_token_state(tokenizer)
    if tokenizer.line_index == 0 {
        // TODO allow user to define tab as x spaces
        // Maybe something like #indent space 4
        // or #indent tab 2 if the user likes to uses multiple tabs for some reason
        // would be best if we could infer this
        for match(tokenizer, "\t") || match(tokenizer, "    ") {
            add_token(tokenizer, .Tab)
        }
        
        if peek(tokenizer) == ' ' {
            error(
                tokenizer,
                .Misaligned_Tab, 
                "Tab spacing is misaligned. Unexpected space",
            )
        }
    }
    
    if is_at_end(tokenizer) {
        next_line(tokenizer)
        return
    }

    c := peek(tokenizer)
    if match(tokenizer, "/*") {
        nest := 1
        for !is_at_end(tokenizer) && nest > 0 {
            if match(tokenizer, "/*") {
                nest += 1
            }
            else if match(tokenizer, "*/", false) {
                nest -= 1
            }
            else if peek(tokenizer) == '\n' {
                advance(tokenizer, false)
                next_line(tokenizer)
            }
            else {
                advance(tokenizer, false)
            }
        }
        if is_at_end(tokenizer) && nest > 0 {
            error(
                tokenizer, 
                .Comment_Missing_End,
                "Multiline comment is missing corresponding ending \"*/\"",
            )
        }
    }
    else if match(tokenizer, "//") {
        for !is_at_end(tokenizer) && peek(tokenizer) != '\n' {
            advance(tokenizer, false)
        }
    }
    else if c == '"' {
        read_string(tokenizer)
    }
    else if c == '(' {
        advance(tokenizer)
        add_token(tokenizer, .Left_Paren, "(")
    }
    else if c == ')' { 
        advance(tokenizer)
        add_token(tokenizer, .Right_Paren, ")")
    }
    else if c == ':' {
        advance(tokenizer)
        add_token(tokenizer, .Colon, ":")
    }
    else if c == '=' { 
        advance(tokenizer)
        add_token(tokenizer, .Equals, "=")
    }
    else if match(tokenizer, "+") {
        add_token(tokenizer, .Add, "+")
    }
    else if match(tokenizer, "-") {
        add_token(tokenizer, .Subtract, "-")
    }
    else if match(tokenizer, "*") {
        add_token(tokenizer, .Multiply, "*")
    }
    else if match(tokenizer, "/") {
        add_token(tokenizer, .Divide, "/")
    }
    else if c == ' ' {
        // Ignore
        advance(tokenizer, false)
    }
    else if match_number(tokenizer) {
        // Done
    }
    else if c == '.' {
        advance(tokenizer)
        add_token(tokenizer, .Dot, ".")
    }
    else if match_identifier(tokenizer) {
        // Done
    }
    else if c == '\r' {
        // Ignore
        advance(tokenizer, false)
    }
    else if c == '\n' {
        advance(tokenizer)
        add_token(tokenizer, .Newline)
        next_line(tokenizer)
    }
    else {
        builder := strings.builder_make(0, 16)
        consume_until_separator(tokenizer, &builder)
        str := strings.to_string(builder)
        add_token(tokenizer, .Unknown, str)
        error(
            tokenizer,
            .Unknown_Character,
            fmt.aprintf("Unknown string: \"%s\"", str),
        )
    }

    if is_at_end(tokenizer) {
        next_line(tokenizer)
        return
    }
}

next_line :: proc(tokenizer: ^Tokenizer) {
    tokenizer.line_number += 1
    add_line(tokenizer)
    tokenizer.line_start = tokenizer.current
    tokenizer.line_index = 0
    tokenizer.token_start = 0
}

add_line :: proc(tokenizer: ^Tokenizer) {
    line_runes := tokenizer.runes[tokenizer.line_start:tokenizer.current]
    append(&tokenizer.result.lines, line_runes)
}

is_letter :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

is_digit :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

is_separator :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\n' || r == '\r'
}

is_operator :: proc(type: Type) -> bool {
    return type == .Add || 
        type == .Subtract || 
        type == .Multiply || 
        type == .Divide
}

read_string :: proc(tokenizer: ^Tokenizer) -> bool {
    if peek(tokenizer) != '"' do return false
    advance(tokenizer)

    string_buf := strings.builder_make(0, 32)

    escape_mode := false
    for !is_at_end(tokenizer) {
        r := peek(tokenizer)
        
        if escape_mode {
            if escaped, ok := read_escaped_rune(tokenizer, &string_buf, r); ok {
                escape_mode = false
                advance(tokenizer)
                strings.write_rune(&string_buf, escaped)
                continue
            }
            else {
                return false
            }
        }
        
        switch r {
            case '\\':
                escape_mode = true
            case '"':
                add_token_text(tokenizer, .String, strings.to_string(string_buf))
                advance(tokenizer)
                return true
            case '\n':
                advance(tokenizer)
                error(
                    tokenizer, 
                    .String_Missing_End, 
                    "string missing corresponding ending \"",
                )
                return false
            case:
                strings.write_rune(&string_buf, r)

        }
        advance(tokenizer)
    }
    
    error(
        tokenizer, 
        .String_Missing_End, 
        "string missing corresponding ending \"",
    )
    return false
}

read_escaped_rune :: proc(tokenizer: ^Tokenizer, buf: Buffer, r: rune) -> (rune, bool){
    escapes := map[rune]rune { 
        '\\' = '\\',
        '"' = '\"',
        '0' = rune(0),
        'a' = '\a',
        'b' = '\b',
        'f' = '\f',
        'n' = '\n',
        'r' = '\r',
        't' = '\t',
        'v' = '\v',
    }

    if r in escapes {
        return escapes[r]
    }
    else {
        error(
            tokenizer, 
            .Invalid_Escape_Sequence, 
            fmt.aprintf("Invalid escape sequence \\%s", r)
        )
        return 0, false
    }
}

match_number :: proc(tokenizer: ^Tokenizer) -> bool {
    // TODO allow underscore separators
    r := tokenizer.runes[tokenizer.current]
    dot_digit := r == '.' && is_digit(peek(tokenizer, 1))
    if !is_digit(r) && !dot_digit {
        return false
    }

    builder := strings.builder_make(0, 16)

    decimal_encountered := false

    for !is_at_end(tokenizer) {
        r := tokenizer.runes[tokenizer.current]
        if is_digit(r) {
            strings.write_rune(&builder, advance(tokenizer))
        }
        else if r == '.' {
            if !decimal_encountered {
                decimal_encountered = true
                strings.write_rune(&builder, advance(tokenizer))
            }
            else {
                // We've encountered two decimals in a single number
                consume_until_separator(tokenizer, &builder)
    
                error(
                    tokenizer, 
                    .Malformed_Number,
                    fmt.aprintf(
                        "Malformed number: \"%s\"", 
                        strings.to_string(builder),
                    ),
                )
            }
        }
        else {
            break
        }
    }

    add_token(tokenizer, .Number, strings.to_string(builder))
    return true
}

consume_until_separator :: proc(tokenizer: ^Tokenizer, builder: ^strings.Builder) {
    for !is_at_end(tokenizer) && 
        !is_separator(tokenizer.runes[tokenizer.current]) {
        strings.write_rune(builder, advance(tokenizer))
    }
}

match_identifier :: proc(tokenizer: ^Tokenizer) -> bool {
    if is_at_end(tokenizer) {
        return false
    }
    r := tokenizer.runes[tokenizer.current]
    if !is_letter(r) {
        return false
    }
    
    builder := strings.builder_make(0, 16)
    strings.write_rune(&builder, r)
    advance(tokenizer)

    for !is_at_end(tokenizer) {
        r = tokenizer.runes[tokenizer.current]
        if is_letter(r) || is_digit(r) {
            strings.write_rune(&builder, r)
            advance(tokenizer)
        }
        else {
            break
        }
    }
    add_token(tokenizer, .Identifier, strings.to_string(builder))

    return true
}

match :: proc {
    match_rune,
    match_string,
}

match_rune :: proc(tokenizer: ^Tokenizer, expected: rune) -> bool {
    if is_at_end(tokenizer) {
        return false
    }
    if tokenizer.runes[tokenizer.current] != expected {
        return false
    }
    
    advance(tokenizer)
    return true
}

match_string :: proc(tokenizer: ^Tokenizer, expected: string, capture := true) -> bool {
    i := 0
    for r in expected {
        if tokenizer.current + i >= tokenizer.rune_count {
            return false
        }
        if tokenizer.runes[tokenizer.current + i] != r {
            return false
        }
        i += 1
    }

    advance(tokenizer, i, capture)
    return true
}

add_token_no_text :: proc(tokenizer: ^Tokenizer, type: Type) {
    append(&tokenizer.result.tokens, Token {
        type = type,
        start = tokenizer.token_start,
        end = tokenizer.line_index,
        line_number = tokenizer.line_number,
    })
    
    log.trace("New token:", type)
    tokenizer.token_start = tokenizer.line_index
}

add_token_text :: proc(tokenizer: ^Tokenizer, type: Type, text: string) {
    append(&tokenizer.result.tokens, Token {
        type = type,
        text = text,
        start = tokenizer.token_start,
        end = tokenizer.line_index,
        line_number = tokenizer.line_number,
    })
    log.trace("New token:", type)
    
    tokenizer.token_start = tokenizer.line_index
}

add_token :: proc {
    add_token_no_text,
    add_token_text,
}

is_at_end :: proc(tokenizer: ^Tokenizer) -> bool {
    return tokenizer.current >= tokenizer.rune_count
}

peek :: proc(tokenizer: ^Tokenizer, offset := 0) -> rune {
    index := tokenizer.current + offset
    
    if index >= tokenizer.rune_count {
        // Reached end of source
        return rune(0)
    }
    return tokenizer.runes[index]
}

advance_single :: proc(tokenizer: ^Tokenizer, capture := true) -> rune {
    ret := tokenizer.runes[tokenizer.current]
    tokenizer.current += 1
    tokenizer.line_index += 1
    if !capture {
        tokenizer.token_start = tokenizer.line_index
    }
    trace_current_token_state(tokenizer)
    return ret
}

advance_many :: proc(tokenizer: ^Tokenizer, count: int, capture := true) {
    tokenizer.current += count
    tokenizer.line_index += count
    if !capture {
        tokenizer.token_start = tokenizer.line_index
    }
    trace_current_token_state(tokenizer)
}

advance :: proc {
    advance_single,
    advance_many,
}

error :: proc(tokenizer: ^Tokenizer, type: Error_Type, text: string) {
    append(&tokenizer.result.errors, Error {
        type = type,
        text = text,
        line_number = tokenizer.line_number,
        from = tokenizer.current,
        to = tokenizer.current,
    })
}
 
precedence :: proc(t: ^Token) -> int {
    #partial switch t.type {
        case .Multiply: return 10
        case .Divide:   return 10
        case .Add:      return 5
        case .Subtract: return 5
        case: return 0
    }
}

// Give a representation of the token for a message to the user
descriptive_text :: proc(t: ^Token) -> string {
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
        case .Number:       return fmt.aprintf("number literal \"%s\"", t.text)
        case .String:       return fmt.aprintf("string literal \"%s\"", t.text)
        case .Unknown:      return fmt.aprintf("token \"%s\"", t.text)
    }
    return ""
}

debug_text :: proc(t: ^Token) -> string {
    switch t.type {
        case .Newline:      return "[\\n]"
        case .Left_Paren:   return "[(]"
        case .Right_Paren:  return "[)]"
        case .Dot:          return "[.]"
        case .Colon:        return "[:]"
        case .Equals:       return "[=]"
        case .Tab:          return "[\\t]"
        case .EOF:          return "[EOF]"
        case .Add:          return "[+]"
        case .Subtract:     return "[-]"
        case .Multiply:     return "[*]"
        case .Divide:       return "[/]"
        case .Identifier:   return fmt.aprintf("['%s']", t.text)
        case .Number:       return fmt.aprintf("[%s]", t.text)
        case .String:       return fmt.aprintf("[\"%s\"]", t.text)
        case .Unknown:      return fmt.aprintf("[?? %s ??]", t.text)
    }
    return ""
}

trace_current_token_state :: proc(tokenizer: ^Tokenizer) {
    builder := strings.builder_make(0, 100)
    strings.write_string(&builder, "    |")
    for i := 0 ; i <= 20; i += 1 {
        t := peek(tokenizer, i)
        
        if t == rune(0) {
            strings.write_string(&builder, "<EOF>")
            break
        }
        else if t == '\r' { }
        else if t == '\n' {
            strings.write_string(&builder, "<nl>")
        }
        else {
            strings.write_rune(&builder, t)
        }
    }
    strings.write_string(&builder, "|")
    log.trace(strings.to_string(builder))
}