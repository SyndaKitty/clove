package main

AST_Type :: enum {
    Program,
    Statement,
    Declaration,
    Assignment,
    NumberLiteral,
    Identifier,
    BinaryOp,
    UnaryOp,
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
}

AST_Expression :: union {
    AST_Base,
    AST_NumberLiteral,
    AST_Identifier,
    AST_BinaryOp,
    AST_UnaryOp,
}


AST_Declaration :: struct {
    type: AST_Type,
    identifier: ^AST_Identifier,
    expression: ^AST_Expression,
}

declaration :: proc(
    identifier: ^AST_Identifier, 
    expression: ^AST_Expression,
) -> ^AST_Declaration 
{
    ast := new(AST_Declaration)
    ast.type = .Declaration
    ast.identifier = identifier
    ast.expression = expression

    return ast
}


AST_Assignment :: struct {
    type: AST_Type,
    identifier: ^AST_Identifier,
    expression: ^AST_Expression,
}

assignment :: proc(
    identifier: ^AST_Identifier, 
    expression: ^AST_Expression,
) -> ^AST_Assignment 
{
    ast := new(AST_Assignment)
    ast.type = .Declaration
    ast.identifier = identifier
    ast.expression = expression

    return ast
}


AST_NumberLiteral :: struct {
    type: AST_Type,
    number: ^Token,
}

number_literal :: proc(t: ^Token) -> ^AST_NumberLiteral {
    expression := new(AST_NumberLiteral)
    expression.type = .NumberLiteral
    expression.number = t

    return expression
}


AST_BinaryOp :: struct {
    type: AST_Type,
    left: ^AST_Expression,
    right: ^AST_Expression,
    operator: ^Token,
}

binary :: proc(
    left, right: ^AST_Expression, 
    operator: ^Token,
) -> ^AST_BinaryOp 
{
    ast := new(AST_BinaryOp)
    ast.type = .BinaryOp
    ast.left = left
    ast.right = right
    ast.operator = operator

    return ast
}


AST_UnaryOp :: struct {
    type: AST_Type,
    subject: ^AST_Expression,
    operator: ^Token,
}

unary :: proc(subject: ^AST_Expression, operator: ^Token) -> ^AST_UnaryOp{
    ast := new(AST_UnaryOp)
    ast.type = .UnaryOp
    ast.subject = subject
    ast.operator = operator
    return ast
}


AST_Identifier :: struct {
    type: AST_Type,
    name_token: ^Token,
}

identifier :: proc(name: ^Token) -> ^AST_Identifier {
    ast := new(AST_Identifier)
    ast.type = .Identifier
    ast.name_token = name

    return ast
}


AST_Comparison :: struct {
    // TODO - we should allow multiple comparisons
    // eg. a == b == c >= 2
    // This could be implemented by tracking several expressions
}