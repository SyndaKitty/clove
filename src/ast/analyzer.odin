package ast

import "core:fmt"
import tok "../tokenizer"

Result :: struct {
    tokens: [dynamic]tok.Token,
    errors: [dynamic]Error,
    lines: [dynamic][]rune,
}

Error_Type :: enum {
    
}

Error :: struct {
    type: Error_Type,
    text: string,
}

Scope :: struct {
    map[string]string,
}

Analyzer :: struct {
    
}

// Lifetime analysis
//     Declaration must come first
//     Name checks

// Type checking
//     Declaration
//     Assignments
//     Operations

analyze_ast :: proc(program: Program) {
    for stmt in program.statements {
        analyze_node(stmt)
    }
}

analyze_node :: proc(node: ^Node) {
    #partial switch n in &node.derived_node {
        // Statements
        case ^Expression_Statement:
            
        
        case ^Declaration:
            

        case ^Assignment:
            

        // Expressions
        case ^Func_Call:
            

        case ^Identifier:
            

        case ^Number_Literal:
            

        case ^Unary_Op:
            

        case ^Binary_Op:
            

        case:
            
    }
}