package ast

import "core:intrinsics"
import "core:mem"

import tok "../tokenizer"

AST :: struct {
    statements: [dynamic]^Statement,
}

Type :: enum {
    Statement,
    Declaration,
    Assignment,
    Expression,
    Number_Literal,
    Identifier,
    Binary_Op,
    Unary_Op,
}

Node :: struct {
    derived: Any_Node,
}

// Base Types
Statement :: struct {
    using statement_base: Node,
    derived_statement: Any_Statement,
}

Expression :: struct {
    using expression_base: Node,
    derived_expr: Any_Expr,
}

// Statements
Declaration :: struct {
    using declaration_base: Statement,
    identifier: ^Identifier,
    expression: ^Expression,
}

new_declaration :: proc(
    identifier: ^Identifier, 
    expression: ^Expression,
) -> ^Declaration 
{
    ast := new(Declaration)
    ast.identifier = identifier
    ast.expression = expression

    return ast
}

Expression_Statement :: struct {
    using node: Statement,
    expression: ^Expression
}

Assignment :: struct {
    using statement: Statement,
    identifier: ^Identifier,
    expression: ^Expression,
}

new_assignment :: proc(
    identifier: ^Identifier, 
    expression: ^Expression,
) -> ^Assignment 
{
    ast := new(Assignment)
    ast.identifier = identifier
    ast.expression = expression
    
    return ast
}


// Expressions
Value :: struct {
    using expr: Expression,
    derived: Any_Value,
}

Identifier :: struct {
    using val: Value,
    name_token: ^tok.Token,
}

new_identifier :: proc(name: ^tok.Token) -> ^Identifier {
    ast := new(Identifier)
    ast.name_token = name

    return ast
}

Number_Literal :: struct {
    using val: Value,
    number: ^tok.Token,
}

new_number_literal :: proc(t: ^tok.Token) -> ^Node {
    node := new(Number_Literal)
    node.number = t
    return node
}

Binary_Op :: struct {
    using expr: Expression,
    left: ^Expression,
    right: ^Expression,
    operator: ^tok.Token,
}

new_binary :: proc(
    left, right: ^Expression, 
    operator: ^tok.Token,
) -> ^Binary_Op 
{
    ast := new(Binary_Op)
    ast.left = left
    ast.right = right
    ast.operator = operator

    return ast
}

Unary_Op :: struct {
    using expr: Expression,
    subject: ^Expression,
    operator: ^tok.Token,
}

new_unary :: proc(subject: ^Expression, operator: ^tok.Token) -> ^Unary_Op{
    ast := new(Unary_Op)
    ast.subject = subject
    ast.operator = operator
    return ast
}

Comparison :: struct {
    // TODO - we should allow multiple comparisons
    // eg. a == b == c >= 2
    // This could be implemented by tracking several expressions
}

Any_Node :: union {
    ^Declaration,
    ^Assignment,

    ^Expression_Statement,
    ^Identifier,
    ^Binary_Op,
    ^Unary_Op,
    ^Number_Literal,
    //^Func_Call,
    
}

Any_Statement :: union {
    ^Declaration,
    ^Assignment,
    ^Expression_Statement,
}

Any_Expr :: union {
    ^Identifier,
    ^Number_Literal,
    ^Binary_Op,
    ^Unary_Op,
    //Func_Call TODO,
}

Any_Value :: union {
    ^Identifier,
    ^Number_Literal,
    // Func_Call
}

new :: proc($T: typeid) -> ^T {
	n, _ := mem.new(T)
	n.derived = n
	base: ^Node = n // dummy check
	_ = base
	when intrinsics.type_has_field(T, "derived_expr") {
		n.derived_expr = n
	}
	when intrinsics.type_has_field(T, "derived_statement") {
		n.derived_statement = n
	}
	return n
}

is_value :: proc(n: ^Node) -> bool {
    {
        _, ok := n.derived.(^Number_Literal) 
        if ok do return true
    }
    {
        _, ok := n.derived.(^Identifier) 
        if ok do return true
    }
    
    return false
}