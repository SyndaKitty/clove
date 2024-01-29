package main

import "core:unicode/utf8"
import "core:strings"
import "core:fmt"

// TODO: Adhere to Unicode standard
// https://www.unicode.org/reports/tr31/#D1

Tokenize_Result :: struct {
    tokens: [dynamic]Token,
    errors: [dynamic]Token_Error,
}

Token_Error_Type :: enum {
    Unknown_Character,
}

Token_Error :: struct {
    type: Token_Error_Type,
}

Token_Type :: enum {
    Left_Paren,
    Right_Paren,
    Print,
    Dot,
    Colon,
    Equals,
    Alpha,
    Digit,
    Tab,
    Identifier,
    Newline,
    Unknown,
}

Token :: struct {
    type: Token_Type,
    text: string,
    
    // TODO populate the below fields
    line_number: int,
    
    // indices within the line
    start: int, 
    end: int,
}

Tokenizer :: struct {
    result: ^Tokenize_Result,
    runes: []rune,
    rune_count: int,
    
    // rune index
    current: int,

    // line index of the start of the current token
    start: int,
    line_number: int,
    line_index: int,
}

free_tokenize_result :: proc(result: ^Tokenize_Result) {
    for t in result.tokens {
        delete(t.text)
    }
    delete(result.tokens)
    delete(result.errors)
    free(result)
}

tokenize_chunk :: proc(chunk: string) -> ^Tokenize_Result {
    tokenizer: Tokenizer
    tokenizer.result = new(Tokenize_Result)
    tokenizer.runes = utf8.string_to_runes(chunk)
    tokenizer.rune_count = len(tokenizer.runes)

    for !_is_at_end(&tokenizer) {
        _scan_token(&tokenizer)
    }
    
    return tokenizer.result
}

print_tokenize_results :: proc(results: ^Tokenize_Result) {
    for token in results.tokens {
        if token.type == .Newline {
            fmt.println("\n")
        }
        else if token.type == .Identifier {
            fmt.printf("['%s']", token.text)
        }
        else if token.type == .Left_Paren {
            fmt.print("[(]")
        }
        else if token.type == .Right_Paren {
            fmt.print("[)]")
        }
        else if token.type == .Print {
            fmt.print("[println]")
        }
        else if token.type == .Left_Paren {
            fmt.print("[(]")
        }
        else if token.type == .Dot {
            fmt.print("[.]")
        }
        else if token.type == .Colon {
            fmt.print("[:]")
        }
        else if token.type == .Equals {
            fmt.print("[=]")
        }
        else if token.type == .Tab {
            fmt.print("[\\t]")
        }
        else if token.type == .Unknown {
            fmt.printf("[?? %s ??]", token.text)
        }
    }
}

@private
_scan_token :: proc(tokenizer: ^Tokenizer) {
    c := tokenizer.runes[tokenizer.current]
    if _match(tokenizer, "//") {
        for !_is_at_end(tokenizer) && tokenizer.runes[tokenizer.current] != '\n' {
            _advance(tokenizer)
        }
    }
    else if c == '(' {
        _advance(tokenizer)
        _add_token(tokenizer, Token{type = .Left_Paren})
    }
    else if c == ')' { 
        _advance(tokenizer)
        _add_token(tokenizer, Token{type = .Right_Paren})
    }
    else if c == ':' {
        _advance(tokenizer)
        _add_token(tokenizer, Token{type = .Colon})
    }
    else if c == '=' { 
        _advance(tokenizer)
        _add_token(tokenizer, Token{type = .Equals})
    }
    else if _match(tokenizer, "    ") || _match(tokenizer, '\t') {
        _add_token(tokenizer, Token{type = .Tab})
    }
    else if c == ' ' {
        // Ignore
        _advance(tokenizer)
    }
    else if _match(tokenizer, "println") {
        _add_token(tokenizer, Token{type = .Print})
    }
    else if _match_number(tokenizer) {
        // Done
    }
    else if c == '.' {
        _advance(tokenizer)
        _add_token(tokenizer, Token{type = .Dot})
    }
    else if _match_identifier(tokenizer) {
        // Done
    }
    else if c == '\r' {
        // Ignore
        _advance(tokenizer)
    }
    else if c == '\n' {
        _advance(tokenizer)
        _add_token(tokenizer, Token{type = .Newline})
    }
    else {
        builder := strings.builder_make(0, 16)
        for !_is_at_end(tokenizer) && 
            !_is_separator(tokenizer.runes[tokenizer.current]
        ) {
            strings.write_rune(&builder, _advance(tokenizer))
        }
        _add_token(tokenizer, Token{
            type = .Unknown, 
            text = strings.to_string(builder)
        })
    }
}

@private
_is_letter :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

@private
_is_digit :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

@private
_is_separator :: proc(r: rune) -> bool {
    return r == ' ' || r == '\t' || r == '\n' || r == '\r'
}

@private
_match_number :: proc(tokenizer: ^Tokenizer) -> bool {
    digit_encountered := false
    
    return false
    /*

    for !_is_at_end(tokenizer) {
        r := tokenizer.runes[tokenizer.current]
        if _is_digit(r) {
            digit_encountered = true
        }
        else if r == '.' {

        }
    }

    return false */
}

@private
_match_identifier :: proc(tokenizer: ^Tokenizer) -> bool {
    if _is_at_end(tokenizer) {
        return false
    }
    r := tokenizer.runes[tokenizer.current]
    if !_is_letter(r) {
        return false
    }
    
    builder := strings.builder_make(0, 16)
    strings.write_rune(&builder, r)
    _advance(tokenizer)

    for !_is_at_end(tokenizer) {
        r = tokenizer.runes[tokenizer.current]
        if _is_letter(r) || _is_digit(r) {
            strings.write_rune(&builder, r)
            _advance(tokenizer)
        }
        else {
            break
        }
    }
    _add_token(tokenizer, Token{
        type = .Identifier,
        text = strings.to_string(builder)
    })

    return true
}

@private
_match :: proc {
    _match_rune,
    _match_string,
}

@private
_match_rune :: proc(tokenizer: ^Tokenizer, expected: rune) -> bool {
    if _is_at_end(tokenizer) {
        return false
    }
    if tokenizer.runes[tokenizer.current] != expected {
        return false
    }
    
    tokenizer.current += 1
    return true
}

@private
_match_string :: proc(tokenizer: ^Tokenizer, expected: string) -> bool {
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

@private
_add_token :: proc(tokenizer: ^Tokenizer, token: Token) {
    append(&tokenizer.result.tokens, token)
}

@private
_is_at_end :: proc(tokenizer: ^Tokenizer) -> bool {
    return tokenizer.current >= tokenizer.rune_count
}

@private
_peek :: proc(tokenizer: ^Tokenizer, offset: int) -> rune {
    index := tokenizer.current + offset
    
    if index >= tokenizer.rune_count {
        // Reach end of source
        return rune(0)
    }
    return tokenizer.runes[index]
}

@private
_advance:: proc(tokenizer: ^Tokenizer) -> rune {
    ret := tokenizer.runes[tokenizer.current]
    tokenizer.current += 1
    return ret
}