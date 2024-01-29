package main

import "core:path/filepath"
import "core:fmt"
import "core:os"
import "core:strings"

// Find the closest matching file
// Tries both
//  1. Exact match
//  2. filename + ".clove"
// Returns: filename, ok
find_file :: proc(filename: string) -> (string, bool) {
    trimmed_name := strings.clone_from(strings.trim(filename, " "))
    ext := filepath.ext(trimmed_name)

    // 
    if os.exists(trimmed_name) {
        return trimmed_name, true
    }
    else if !strings.has_suffix(trimmed_name, ".clove") {
        defer delete(trimmed_name)
        file_and_ext := [?]string { trimmed_name, ".clove" }
        return strings.concatenate(file_and_ext[:]), true
    }
    
    return "", false
}

// Read a line from stdin, use the passed builder as a buffer
get_line_input :: proc(builder: ^strings.Builder) -> (string, os.Errno) {
    for {
        // Read 128 bytes from stdin
        data: [128]u8
        total_read, err := os.read(os.stdin, data[:])
        
        if err != os.ERROR_NONE {
            return "", err
        }

        if total_read == 0 {
            continue
        }

        // Write bytes to the builder
        strings.write_bytes(builder, data[0:total_read])

        // Workaround Odin lib edge-case where if we 
        // read a \r as the last byte, the \n on the next read
        // will not terminate the call
        last_rune := data[total_read-1]
        when ODIN_OS != .Windows {
            next_byte: [1]u8
            if last_rune == '\r'{
                total_read, err = os.read(os.stdin, next_byte[:])
                if err != 0 {
                    return "", false
                }
                if err == 0 && next_byte[0] == '\n' {
                    strings.write_bytes(builder, {'\n'})
                    return strings.to_string(builder^)
                }
            }
        }

        // Convert builder to string and return
        if last_rune == '\n' {
            line := strings.to_string(builder^)
            
            // Remove \n
            line = line[:len(line)-1]

            // Remove \r
            if rune(line[len(line)-1]) == '\r' {
                line = line[:len(line)-1]
            }
            return line, os.ERROR_NONE
        }
    }
}