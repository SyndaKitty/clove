package ast

import "core:strings"
import "core:fmt"

buffer :: ^strings.Builder

print_ast :: proc(program: Program) {
    buffer := strings.builder_make(0, 256)

    for stmt in program.statements {
        print_node(&buffer, stmt)
        strings.write_string(&buffer, "\n")
    }

    fmt.print(strings.to_string(buffer))
}

print_node :: proc(buf: buffer, node: ^Node) {
    switch n in &node.derived_node {
        // Statements
        case ^Expression_Statement:
            print_node(buf, n.expression)
        
        case ^Declaration:
            strings.write_string(buf, "declare ")
            strings.write_string(buf, n.identifier.name_tok.text)
            strings.write_string(buf, " = ")
            print_node(buf, n.expression)

        case ^Assignment:
            strings.write_string(buf, "assign ")
            strings.write_string(buf, n.identifier.name_tok.text)
            strings.write_string(buf, " = ")
            print_node(buf, n.expression)

        // Expressions
        case ^Func_Call:
            strings.write_string(buf, "call(")
            strings.write_string(buf, n.func.name_tok.text)
            strings.write_string(buf, "), arg=(")
            one := false
            for arg in n.args {
                print_node(buf, arg)
                strings.write_string(buf, ",")
                one = true
            }
            if one {
                // Remove trailing ,
                pop(&buf.buf)
            }
            strings.write_string(buf, ")")
            
        case ^Identifier:
            strings.write_string(buf, "var(")
            strings.write_string(buf, n.name_tok.text)
            strings.write_string(buf, ")")

        case ^Number_Literal:
            strings.write_string(buf, "num(")
            strings.write_string(buf, n.num_str)
            strings.write_string(buf, ")")

        case ^Unary_Op:
            strings.write_string(buf, "unary(")
            strings.write_string(buf, n.operator.text)
            strings.write_string(buf, " ")
            print_node(buf, n.subject)
            strings.write_string(buf, ")")

        case ^Binary_Op:
            #partial switch n.operator.type {
                case .Add:              strings.write_string(buf, "ADD(")
                case .Subtract:         strings.write_string(buf, "SUB(")
                case .Multiply:         strings.write_string(buf, "MUL(")
                case .Divide:           strings.write_string(buf, "DIV(")
                case .Less:             strings.write_string(buf, "LESS(")
                case .Less_Or_Eq:       strings.write_string(buf, "LESS_EQ(")
                case .Greater:          strings.write_string(buf, "GREATER(")
                case .Greater_Or_Eq:    strings.write_string(buf, "GREATER_EQ(")
                case .Equality:         strings.write_string(buf, "EQ(")
                case: 
                    if len(n.operator.text) == 0 {
                        panic("No text representation of operator")
                    }    
                    strings.write_string(buf, n.operator.text)
                    strings.write_string(buf, "(")
            }

            print_node(buf, n.left)
            strings.write_string(buf, ",")
            print_node(buf, n.right)
            strings.write_string(buf, ")")

        case ^Bool_Literal:
            strings.write_string(buf, "bool(")
            strings.write_string(buf, "true" if n.value else "false")
            strings.write_string(buf, ")")

        case ^Array_Literal:
            strings.write_string(buf, "arr[")
            one := false
            for item in n.items {
                print_node(buf, item)
                strings.write_string(buf, ",")
                one = true
            }
            if one {
                pop(&buf.buf)
            }
            strings.write_string(buf, "]")

        case ^Float_Literal:
            strings.write_string(buf, "float(")
            strings.write_string(buf, n.num_str)
            strings.write_string(buf, ")")

        case ^Integer_Literal:
            strings.write_string(buf, "int(")
            strings.write_string(buf, n.num_str)
            strings.write_string(buf, ")")

        case ^String_Literal:
            strings.write_string(buf, "str(")
            strings.write_string(buf, n.string_tok.text)
            strings.write_string(buf, ")")

        case:
            strings.write_string(buf, "Unknown type")
    }
}