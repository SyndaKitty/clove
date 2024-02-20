package ast

import "core:intrinsics"
import "core:mem"
import "core:strings"

import tok "../tokenizer"
import "../log"

Program :: struct {
    statements: [dynamic]^Statement,
}

Type :: enum {
    Statement,
    Declaration,
    Assignment,
    Expression,
    Number_Literal,
    Identifier,
    Array_Literal,
    Binary_Op,
    Unary_Op,
}

Node :: struct {
    derived_node: Any_Node,
}

// Base Types
Statement :: struct {
    using base_node: Node,
    derived_stmt: Any_Statement,
}

Expression :: struct {
    using base: Node,
    derived_expr: Any_Expr,
}

// Statements
Declaration :: struct {
    using base_stmt: Statement,
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
    using base_stmt: Statement,
    expression: ^Expression
}

Assignment :: struct {
    using base_stmt: Statement,
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
    using base_expr: Expression,
    derived_val: Any_Value,
}

Identifier :: struct {
    using base_val: Value,
    name_tok: ^tok.Token,
}

new_identifier :: proc(name: ^tok.Token) -> ^Identifier {
    ast := new(Identifier)
    ast.name_tok = name

    return ast
}

Number_Literal :: struct {
    using base_val: Value,
    num_tok: ^tok.Token,
}

new_number_literal :: proc(t: ^tok.Token) -> ^Number_Literal {
    node := new(Number_Literal)
    node.num_tok = t
    return node
}

String_Literal :: struct {
    using base_val: Value,
    string_tok: ^tok.Token,
}

new_string_literal :: proc(t: ^tok.Token) -> ^String_Literal {
    node := new(String_Literal)
    node.string_tok = t
    return node
}

Binary_Op :: struct {
    using base_expr: Expression,
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
    using base_val: Value,
    subject: ^Expression,
    operator: ^tok.Token,
}

new_unary :: proc(subject: ^Expression, operator: ^tok.Token) -> ^Unary_Op{
    ast := new(Unary_Op)
    ast.subject = subject
    ast.operator = operator
    return ast
}

Func_Call :: struct {
    using base_val: Value,
    func: ^Identifier,
    arg: ^Expression,
}

new_func_call :: proc(func_name: ^Identifier, arg: ^Identifier) -> ^Func_Call {
    ast := new(Func_Call)
    ast.func = func_name
    ast.arg = arg

    return ast
}

Array_Literal :: struct {
    using base_val: Value,
    items: []^Expression,
}

new_array_literal :: proc(items: []^Expression) -> ^Array_Literal {
    ast := new(Array_Literal)
    ast.items = items

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
    ^String_Literal,
    ^Func_Call,
    ^Array_Literal,
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
    ^Func_Call,
    ^String_Literal,
    ^Array_Literal,
}

Any_Value :: union {
    ^Identifier,
    ^Number_Literal,
    ^String_Literal,
    ^Unary_Op,
    ^Func_Call,
    ^Array_Literal,
}

new :: proc($T: typeid) -> ^T {
	n, _ := mem.new(T)
	n.derived_node = n
	base: ^Node = n // dummy check
	_ = base
	when intrinsics.type_has_field(T, "derived_expr") {
		n.derived_expr = n
	}
	when intrinsics.type_has_field(T, "derived_stmt") {
		n.derived_stmt = n
	}
	return n
}

is_value :: proc(n: ^Node) -> bool {
    #partial switch n in &n.derived_node {
        case ^Number_Literal: return true
        case ^String_Literal: return true
        case ^Array_Literal: return true
        case ^Identifier: return true
        case: return false
    }
    
    return false
}