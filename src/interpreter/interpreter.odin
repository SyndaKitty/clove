package interpreter

import "core:strings"
import "core:os"
import "core:fmt"
import "core:strconv"

import "../log"
import "../parser"
import "../ast"
import "../file"

Result_Type :: enum {
    Success,
    Parse_Error,
    File_Error,
}

Result :: struct {
    kind: Result_Type,
    
    parse_result: parser.Result,
    file_error: os.Errno,
}

Interpreter :: struct {
    values: map[string]^Value,
}


// Read and run input line by line
run_interpreter :: proc() {
    interpreter: Interpreter
    interpreter.values = make(map[string]^Value)

    line_builder := strings.builder_make(0, 256)
    defer strings.builder_destroy(&line_builder)
    
    for {
        fmt.print(">> ")
        line, err := file.get_line_input(&line_builder)
        if err != os.ERROR_NONE {
            fmt.printf("Unable to read input: Errno %d\n", err)
            return
        }

        // TODO: This should come from an exit() call instead
        if line == "quit" || line == "stop" || line == "exit" {
            break
        }

        interpret_chunk(line, &interpreter)

        strings.builder_reset(&line_builder)
    }
}

interpret_chunk :: proc(
    line: string,
    interp: ^Interpreter = nil,
) {
    i: Interpreter
    interp_val := interp
    if interp_val == nil {
        interp_val = &i
    }
    
    res := parser.parse_chunk(line)
    if len(res.errors) > 0 {
        for err in res.errors {
            fmt.println(err.text)
        }
     }
    else {
        ast.lua_ast(res.program)
        ast.print_ast(res.program)
        // interpret_ast(interp_val, res.program)
    }
}

interpret_ast :: proc(interp: ^Interpreter, program: ast.Program) {
    for stmt in program.statements {
        // fmt.println(stmt)
        evaluate_statement(interp, stmt)
    }
}

evaluate_statement :: proc(interp: ^Interpreter, node: ^ast.Node) {
    #partial switch n in &node.derived_node {
        // Statements
        case ^ast.Expression_Statement:
            v, ok := evaluate_expression(interp, n.expression)
            if ok {
                fmt.printf("%s\n", to_display_string(v))
            }
        
        case ^ast.Declaration:
            var_name := n.identifier.name_tok.text
            log.trace("Declaring \"", var_name, "\"")

            if var_name in interp.values {
                fmt.printf("Variable \"%s\" is already declared\n", var_name)
                return
            }
            
            val, ok := evaluate_expression(interp, n.expression)
            if !ok {
                log.trace("Could not evaluate expression")
                return
            }
            interp.values[var_name] = val

        case ^ast.Assignment:
            var_name := n.identifier.name_tok.text
            log.trace("Assigning \"", var_name, "\"")

            if var_name not_in interp.values {
                fmt.printf("Variable \"%s\" is not declared\n", var_name)
                return
            }
            
            val, ok := evaluate_expression(interp, n.expression)
            if !ok {
                log.trace("Could not evaluate expression")
                return
            }
            interp.values[var_name] = val

        case ^ast.Func_Call:
            evaluate_expression(interp, node)
    }
}

evaluate_expression :: proc(interp: ^Interpreter, node: ^ast.Node) -> (^Value, bool) {
    log.trace("evaluate_expression")
    switch n in &node.derived_node {
        case ^ast.Func_Call:
            func_name := n.func.name_tok.text
            log.trace("Running function ", func_name)
            if func_name == "println" {
                buf := strings.builder_make(0, 32)
                for arg in n.args {
                    val, ok := evaluate_expression(interp, arg)
                    if !ok do break
                    
                    strings.write_string(&buf, to_string(val))
                }
                fmt.println(strings.to_string(buf))
                return new(Nil), true
            }
            else {
                fmt.printf("Unknown function \"%s\"\n", func_name)
                return nil, false
            }

        case ^ast.Identifier:
            var_name := n.name_tok.text
            if var_name in interp.values {
                return interp.values[var_name], true
            }
            else {
                fmt.printf("Undefined variable \"%s\"\n", var_name)
                return nil, false
            }

        case ^ast.Integer_Literal:
            i, ok := strconv.parse_int(n.num_str)
            if ok {
                integer := new(Integer)
                integer.val_int = i
                return integer, true
            }
            fmt.printf("Invalid int \"%s\"\n", n.num_str)
            return nil, false

        case ^ast.Float_Literal:
            val := new(Float)
            ok: bool
            val.val_float, ok = strconv.parse_f32(n.num_str)
            if !ok {
                fmt.printf("Invalid float \"%s\"\n", n.num_str)
                return nil, false
            }
            return val, true
            

        case ^ast.String_Literal:
            val := new(String)
            val.val_string = n.string_tok.text
            return val, true

        case ^ast.Unary_Op:
            fmt.println("Unary not implemented")
            return nil, false

        case ^ast.Binary_Op:
            left, right: ^Value
            ok: bool

            left, ok = evaluate_expression(interp, n.left)
            if !ok {
                return nil, false
            }

            right, ok = evaluate_expression(interp, n.right)
            if !ok {
                return nil, false
            }
            #partial switch n.operator.type {
                
                case .Add:
                    ret, ok := evaluate_add(left, right)
                    if !ok {
                        return nil, false
                    }
                    return ret, true

                case .Subtract:
                    if !check_numbers(left, right, "Cannot subtract values of type %s and %s\n") {
                        return nil, false
                    }
                    ret := new(Float)
                    ret.val_float = to_float(left) - to_float(right)
                    return ret, true

                case .Multiply:
                    if !check_numbers(left, right, "Cannot multiply values of type %s and %s\n") {
                        return nil, false
                    }
                    ret := new(Float)
                    ret.val_float = to_float(left) * to_float(right)
                    return ret, true

                case .Divide:
                    if !check_numbers(left, right, "Cannot divide values of type %s and %s\n") {
                        return nil, false
                    }
                    ret := new(Float)
                    r := to_float(right)
                    if r == 0.0 {
                        fmt.println("Divide by zero!")
                        return nil, false
                    }
                    ret.val_float = to_float(left) / r
                    return ret, true

                case:
                    fmt.printf("Unknown operator \"%s\"\n", n.operator.text)
                    return nil, false
            }

        case ^ast.Array_Literal:
            arr := new(Array)
            for item in n.items {
                expr, ok := evaluate_expression(interp, item)
                if !ok {
                    return nil, false
                }
                append(&arr.items, expr)
            }
            return &arr.base, true

        case ^ast.Bool_Literal:
            b := new(Bool)
            b.boolean = n.value
            return &b.base, true

        case ^ast.Nil:
            fmt.println("Nil not implemented")
            return nil, false

        case ^ast.Assignment:           assert(false, "Invalid expression")
        case ^ast.Declaration:          assert(false, "Invalid expression")
        case ^ast.Expression_Statement: assert(false, "Invalid expression")
        case ^ast.Number_Literal:       assert(false, "Invalid expression")
    }

    log.error("Unknown expression type ", node.derived_node)
    return nil, false
}

evaluate_add :: proc(left, right: ^Value) -> (^Value, bool) {
    is_lstr := is_string(left)
    is_lnum := is_number(left)

    is_rstr := is_string(right)
    is_rnum := is_number(right)
    
    valid := (is_lstr || is_lnum) && (is_rstr || is_rnum)

    if !valid {
        fmt.printf("Cannot add values of type %s and %s\n",
            type_string(left),
            type_string(right),
        )
        return nil, false
    }
    
    if is_lnum && is_rnum {
        if is_int(left) && is_int(right) {
            ret := new(Integer)
            ret.val_int = to_int(left) + to_int(right)
            return ret, true
        }
        ret := new(Float)
        ret.val_float = to_float(left) + to_float(right)

        return ret, true
    }

    if is_lstr || is_rstr {
        ret := new(String)
        
        lstr := to_string(left)
        rstr := to_string(right)
        
        buf := strings.builder_make(0, len(lstr) + len(rstr))
        strings.write_string(&buf, lstr)
        strings.write_string(&buf, rstr)
        
        ret.val_string = strings.to_string(buf)

        return ret, true
    }

    log.error(
        fmt.aprintf(
            "Addition not implemented for types %s and %s", 
            type_string(left), 
            type_string(right),
        ),
    )
    return nil, false
}


to_float :: proc(v: ^Value) -> f32 {
    #partial switch n in &v.derived_val {
        case ^Float: return n.val_float
        case ^Integer: return f32(n.val_int)
    }
    assert(false, "Value is not float")
    return -1
}

to_int :: proc(v: ^Value) -> int {
    #partial switch n in &v.derived_val {
        case ^Integer: return n.val_int
    }
    assert(false, "Value is not int")
    return -1
}

check_numbers :: proc(a, b: ^Value, error_msg: string) -> bool {
    if !is_number(a) || !is_number(b) {
        a_type := type_string(a)
        b_type := type_string(b)
        fmt.printf(
            error_msg, 
            a_type, 
            b_type,
        )
        return false
    }
    return true
}

// For display on the output console in interpreter mode
to_display_string :: proc(val: ^Value) -> string {
    // TODO: Maybe we don't want to display special characters like
    // \a \b \r \n as it can cause funky output on the console
    // If println calls it, then we should print the actual value
    if v, ok := val.derived_val.(^String); ok {
        return fmt.aprintf("\"%s\"", v.val_string)
    }
    return to_string(val)
}

to_string :: proc(val: ^Value) -> string {
    switch v in &val.derived_val {
        case ^Float:
            return fmt.aprintf("%f", v.val_float)
        case ^Integer:
            return fmt.aprintf("%d", v.val_int)
        case ^String:
            return v.val_string
        case ^Nil:
            return "nil"
        case ^Array:
            buf := strings.builder_make(0, 32)
            strings.write_rune(&buf, '[')
            one := false
            for item in v.items {
                 strings.write_string(&buf, to_string(item))
                 strings.write_string(&buf, ",")
                 one = true
            }
            if one {
                // Remove trailing ,
                pop(&buf.buf)
            }
            strings.write_rune(&buf, ']')
            return strings.to_string(buf)
        case ^Bool:
            return "true" if v.boolean else "false"
    }
    return ""
}

type_string :: proc(val: ^Value) -> string {
    switch v in &val.derived_val {
        case ^Float:
            return "float"
        case ^Integer:
            return "int"
        case ^String:
            return "string"
        case ^Nil:
            return "nil"
        case ^Array:
            return "array"
        case ^Bool:
            return "bool"
    }
    return ""
}