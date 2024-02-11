package main

AST_Type :: enum {
    Program,
    Statement,
    Declaration,
    Assignment,
    NumberLiteral,
    Identifier,
}

AST :: struct {
    type: AST_Type,
    statements: [dynamic]^AST_Statement,
}

AST_Base :: struct {
    type: AST_Type,
}

AST_Statement :: union {
    AST_Base,
    AST_Declaration,
    AST_Assignment,
    AST_Print,
}

AST_Expression :: union {
    AST_Base,
    AST_NumberLiteral,
    AST_Identifier,
    AST_Binary,
    AST_Unary,
}

AST_Declaration :: struct {
    type: AST_Type,
    identifier: ^Token,
    expression: ^AST_Expression,
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

AST_Binary :: struct {
    type: AST_Type,
    left: ^AST_Expression,
    right: ^AST_Expression,
    operator: Token,
}

AST_Unary :: struct {
    type: AST_Type,
    subject: ^AST_Expression,
    operator: Token,
}

AST_Identifier :: struct {
    type: AST_Type,
    identifier: ^Token,
}