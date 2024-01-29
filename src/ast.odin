package main

AST_Type :: enum {
    Program,
    Statement,
    Assignment,
    NumberLiteral,
    Identifier,
    Print,
}

AST :: struct {
    type: AST_Type,
    statements: [dynamic]^AST_Statement,
}

AST_Base :: struct {
    type: AST_Type
}

AST_Statement :: union {
    AST_Base,
    AST_Assignment,
    AST_Print,
}

AST_Expression :: union {
    AST_Base,
    AST_NumberLiteral,
    AST_Identifier,
}

AST_Assignment :: struct {
    type: AST_Type,
    identifier: ^Token,
    expression: ^AST_Expression,
}

AST_NumberLiteral :: struct {
    type: AST_Type,
    number: ^Token,
}

AST_Identifier :: struct {
    type: AST_Type,
    identifier: ^Token,
}

AST_Print :: struct {
    type: AST_Type,
    arg: ^AST_Expression,
}

// AST_Operation :: struct {
//     type: AST_Type,
//     operator: Token,
// }