package ast

import "core:strings"
import "core:fmt"

lua_ast :: proc(program: Program) {
    buffer := strings.builder_make(0, 256)

    for stmt in program.statements {
        lua_node(&buffer, stmt)
        strings.write_string(&buffer, "\n")
    }

    fmt.println(strings.to_string(buffer))
}

lua_node :: proc(buf: buffer, node: ^Node) {
    #partial switch n in &node.derived_node {
        // Statements
        case ^Expression_Statement:
            lua_node(buf, n.expression)
        
        case ^Declaration:
            strings.write_string(buf, n.identifier.name_tok.text)
            strings.write_string(buf, " = ")
            lua_node(buf, n.expression)
        
        case ^Assignment:
            strings.write_string(buf, n.identifier.name_tok.text)
            strings.write_string(buf, " = ")
            lua_node(buf, n.expression)

        // Expressions
        case ^Func_Call:
            strings.write_string(buf, n.func.name_tok.text)
            strings.write_string(buf, "(")
            lua_node(buf, n.arg)
            strings.write_string(buf, ")")
            
        case ^Identifier:
            strings.write_string(buf, n.name_tok.text)

        case ^Number_Literal:
            strings.write_string(buf, n.num_tok.text)

        case ^Unary_Op:
            strings.write_string(buf, n.operator.text)
            lua_node(buf, n.subject)

        case ^Binary_Op:
            strings.write_string(buf, "(")
            lua_node(buf, n.left)
            #partial switch n.operator.type {
                case .Add:      strings.write_string(buf, " + ")
                case .Subtract: strings.write_string(buf, " - ")
                case .Multiply: strings.write_string(buf, " * ")
                case .Divide:   strings.write_string(buf, " / ")
                case: 
            }
            lua_node(buf, n.right)
            strings.write_string(buf, ")")

        case ^Array_Literal:
            strings.write_string(buf, "{")
            one := false
            for item in n.items {
                lua_node(buf, item)
                strings.write_string(buf, ",")
                one = true
            }
            if one {
                pop(&buf.buf)
            }
            strings.write_string(buf, "}")

        case:
            strings.write_string(buf, "Unknown type")
    }
}