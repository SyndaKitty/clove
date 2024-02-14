package tokenizer

import "core:unicode/utf8"
import "core:strings"
import "core:fmt"

// TODO: Adhere to Unicode standard
// https://www.unicode.org/reports/tr31/#D1

Result :: struct {
    tokens: [dynamic]Token,
    errors: [dynamic]Error,
}

Error_Type :: enum {
    Unknown_Character,
    Malformed_Number,
    Comment_Missing_End,
}

Error :: struct {
    type: Error_Type,
    text: string,
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
    Unknown,
    EOF,
}

EOF := Token {
    type = .EOF,
}

is_operator :: proc(type: Type) -> bool {
    return type == .Add || 
        type == .Subtract || 
        type == .Multiply || 
        type == .Divide
}

Token :: struct {
    type: Type,
    text: string,
    
    // TODO populate the below fields
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
    start: int,
    line_number: int,
    line_index: int,
}

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
    add_token(&tokenizer, Token{type = .EOF})

    return tokenizer.result
}

print_tokenize_tokens :: proc(results: ^Result) {
    for token in &results.tokens {
        fmt.println(debug_text(&token))
    }
    fmt.println()
}

print_tokenize_errors :: proc(results: ^Result) {
    for error in results.errors {
        if len(error.text) > 0 {
            fmt.printf("[%s]: [%s]\n", error.type, error.text)
        }
        else {
            fmt.printf("[%s]\n", error.type)
        }
    }
}

scan_token :: proc(tokenizer: ^Tokenizer) {
    c := tokenizer.runes[tokenizer.current]
    if match(tokenizer, "/*") {
        nest := 1
        for !is_at_end(tokenizer) && nest > 0 {
            if match(tokenizer, "/*") {
                nest += 1
            }
            else if match(tokenizer, "*/") {
                nest -= 1
            }
            else {
                advance(tokenizer)
            }
        }
        if is_at_end(tokenizer) && nest > 0 {
            error(tokenizer, Error {
                type = .Comment_Missing_End,
                text = "Multiline comment missing corresponding ending \"*/\"",
            })
        }
    }
    else if match(tokenizer, "//") {
        for !is_at_end(tokenizer) && tokenizer.runes[tokenizer.current] != '\n' {
            advance(tokenizer)
        }
    }
    else if c == '(' {
        advance(tokenizer)
        add_token(tokenizer, Token{type = .Left_Paren})
    }
    else if c == ')' { 
        advance(tokenizer)
        add_token(tokenizer, Token{type = .Right_Paren})
    }
    else if c == ':' {
        advance(tokenizer)
        add_token(tokenizer, Token{type = .Colon})
    }
    else if c == '=' { 
        advance(tokenizer)
        add_token(tokenizer, Token{type = .Equals})
    }
    else if match(tokenizer, "    ") || match(tokenizer, '\t') {
        add_token(tokenizer, Token{type = .Tab})
    }
    else if match(tokenizer, "+") {
        add_token(tokenizer, Token{type = .Add})
    }
    else if match(tokenizer, "-") {
        add_token(tokenizer, Token{type = .Subtract})
    }
    else if match(tokenizer, "*") {
        add_token(tokenizer, Token{type = .Multiply})
    }
    else if match(tokenizer, "/") {
        add_token(tokenizer, Token{type = .Divide})
    }
    else if c == ' ' {
        // Ignore
        advance(tokenizer)
    }
    else if match_number(tokenizer) {
        // Done
    }
    else if c == '.' {
        advance(tokenizer)
        add_token(tokenizer, Token{type = .Dot})
    }
    else if match_identifier(tokenizer) {
        // Done
    }
    else if c == '\r' {
        // Ignore
        advance(tokenizer)
    }
    else if c == '\n' {
        advance(tokenizer)
        add_token(tokenizer, Token{type = .Newline})
    }
    else {
        builder := strings.builder_make(0, 16)
        consume_until_separator(tokenizer, &builder)
        str := strings.to_string(builder)
        add_token(tokenizer, Token{
            type = .Unknown, 
            text = str,
        })
        error(tokenizer, Error {
            type = .Unknown_Character,
            text = fmt.aprintf("Unknown string: \"%s\"", str),
        })
    }
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

match_number :: proc(tokenizer: ^Tokenizer) -> bool {
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
    
                error(tokenizer, Error {
                    type = .Malformed_Number,
                    text = fmt.aprintf("Malformed number: \"%s\"", strings.to_string(builder))
                })
            }
        }
        else {
            break
        }
    }

    add_token(tokenizer, Token{
        type = .Number,
        text = strings.to_string(builder)
    })
    return true
}

consume_until_separator :: proc(tokenizer: ^Tokenizer, builder: ^strings.Builder) {
    for !is_at_end(tokenizer) && 
        !is_separator(tokenizer.runes[tokenizer.current]
    ) {
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
    add_token(tokenizer, Token{
        type = .Identifier,
        text = strings.to_string(builder),
    })

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
    
    tokenizer.current += 1
    return true
}

match_string :: proc(tokenizer: ^Tokenizer, expected: string) -> bool {
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

    tokenizer.current += i
    return true
}

add_token :: proc(tokenizer: ^Tokenizer, token: Token) {
    append(&tokenizer.result.tokens, token)
}

is_at_end :: proc(tokenizer: ^Tokenizer) -> bool {
    return tokenizer.current >= tokenizer.rune_count
}

peek :: proc(tokenizer: ^Tokenizer, offset: int) -> rune {
    index := tokenizer.current + offset
    
    if index >= tokenizer.rune_count {
        // Reach end of source
        return rune(0)
    }
    return tokenizer.runes[index]
}

advance :: proc {
    advance_single,
    advance_many,
}

advance_single :: proc(tokenizer: ^Tokenizer) -> rune {
    ret := tokenizer.runes[tokenizer.current]
    tokenizer.current += 1
    return ret
}

advance_many :: proc(tokenizer: ^Tokenizer, count: int) {
    tokenizer.current += count
}

error :: proc(tokenizer: ^Tokenizer, error: Error) {
    append(&tokenizer.result.errors, error)
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
        case .Number:       return fmt.aprintf("number \"%s\"", t.text)
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
        case .Unknown:      return fmt.aprintf("[?? %s ??]", t.text)
    }
    return ""
}