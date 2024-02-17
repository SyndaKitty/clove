package ast

import "core:strings"
import "core:fmt"

buffer :: ^strings.Builder

print_ast :: proc(program: AST) {
    buffer := strings.builder_make(0, 256)

    for stmt in program.statements {
        print_node(&buffer, stmt)
        strings.write_string(&buffer, "\n")
    }

    fmt.println(strings.to_string(buffer))
}

print_node :: proc(buf: buffer, node: ^Node) {
    #partial switch n in &node.derived_node {
        // Statements
        case ^Expression_Statement:
            print_node(buf, n.expression)
        
        case ^Declaration:
            strings.write_string(buf, "declare ")
            strings.write_string(buf, n.identifier.name_token.text)
            strings.write_string(buf, " = ")
            print_node(buf, n.expression)

        case ^Assignment:
            strings.write_string(buf, "assign ")
            strings.write_string(buf, n.identifier.name_token.text)
            strings.write_string(buf, " = ")
            print_node(buf, n.expression)

        // Expressions
        case ^Func_Call:
            strings.write_string(buf, "func_call name=(")
            strings.write_string(buf, n.func.name_token.text)
            strings.write_string(buf, "), arg=(")
            print_node(buf, n.arg)
            strings.write_string(buf, ")")
            
        case ^Identifier:
            strings.write_string(buf, "var(")
            strings.write_string(buf, n.name_token.text)
            strings.write_string(buf, ")")

        case ^Number_Literal:
            strings.write_string(buf, "num(")
            strings.write_string(buf, n.number.text)
            strings.write_string(buf, ")")

        case ^Unary_Op:
            strings.write_string(buf, "unary(")
            strings.write_string(buf, n.operator.text)
            strings.write_string(buf, " ")
            print_node(buf, n.subject)
            strings.write_string(buf, ")")

        case ^Binary_Op:
            #partial switch n.operator.type {
                case .Add:      strings.write_string(buf, "ADD(")
                case .Subtract: strings.write_string(buf, "SUB(")
                case .Multiply: strings.write_string(buf, "MUL(")
                case .Divide:   strings.write_string(buf, "DIV(")
                case: 
                    strings.write_string(buf, n.operator.text)
                    strings.write_string(buf, "(")
            }

            print_node(buf, n.left)
            strings.write_string(buf, ",")
            print_node(buf, n.right)
            strings.write_string(buf, ")")

        case:
            strings.write_string(buf, "Unknown type")
    }
}