package main

import "core:os"
import "core:fmt"
import "core:strings"
import "core:mem"

import "log"
import "ast"

main :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    when ODIN_DEBUG {
        log.debug("Running in debug mode")
        /*
        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
        */
    }


    if len(os.args) > 2 {
        fmt.println("Usage: clove [file]")
    }
    else if len(os.args) == 2 {
        run_clove_file(os.args[1])
    }
    else if len(os.args) == 1 {
        run_interpreter()
    }
}

run_clove_file :: proc(filename: string) {
    valid_filename, ok := find_file(filename)
    defer delete(valid_filename)
    
    if !ok {
        fmt.printf("File not found: \"%s\"\n", filename)
        return
    }

    if contents, ok := os.read_entire_file(valid_filename); ok {
        contents_string := strings.clone_from(contents)
        defer delete(contents)
        defer delete(contents_string)
        
        interpreter: Interpreter
        result: Interpret_Result

        interpret_chunk(contents_string, &result, &interpreter)
    }
    else {
        fmt.printf("Unable to read file %s\n", valid_filename)
        return
    }
    log.trace("Test3")
}