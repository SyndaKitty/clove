package main

AST_Type :: enum {
    Assignment,
    Operation,
}

AST :: struct #raw_union {
    AST_Assignment,
    AST_Print,
}

AST_Expression :: struct #raw_union {
    AST_NumberLiteral,
}

AST_Assignment :: struct {
    type: AST_Type,
    identifier: ^Token,
    expression: ^AST,
}

AST_NumberLiteral :: struct {
    type: AST_Type,
    number: ^Token,
}

AST_Print :: struct {
    type: AST_Type,

}

// AST_Operation :: struct {
//     type: AST_Type,
//     operator: Token,
// }