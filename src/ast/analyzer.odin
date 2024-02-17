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

Analyzer :: struct {
    
}

// anaylze_ast :: proc(program: ast.AST) {
//     for statement in program.statements {
//         analyze(statement)
//         // statement.derived_stmt.(^ast.Expression_Statement)
//     }
// }

// analyze :: proc(node: ^ast.Node) {
//     switch n in &node.derived {
//         case ^Expression_Statement:
//             n.
//     }
// }