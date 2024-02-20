package ast

import "core:intrinsics"
import "core:mem"
import "core:strings"
import "core:strconv"

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
    Integer_Literal,
    Float_Literal,
    Array_Literal,
    Bool_Literal,
    Identifier,
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
    num: Any_Number,
    num_str: string,
}

@(require_results)
new_number_literal :: proc(t: ^tok.Token) -> (^Number_Literal, bool) {
    if int_lit, ok := new_integer_literal(t); ok {
        return &int_lit.base_num, true
    }
    else if float_lit, ok := new_float_literal(t); ok {
        return &float_lit.base_num, true
    }
    return nil, false
}

Float_Literal :: struct {
    using base_num: Number_Literal,
}

@(require_results)
new_float_literal :: proc(t: ^tok.Token) -> (^Float_Literal, bool) {
    node := new(Float_Literal)
    val, ok := strconv.parse_f64(t.text)
    if ok {
        node.num_str = t.text
        return node, true
    }
    else {
        return nil, false
    }
}

Integer_Literal :: struct {
    using base_num: Number_Literal,
}

@(require_results)
new_integer_literal :: proc(t: ^tok.Token) -> (^Integer_Literal, bool) {
    node := new(Integer_Literal)
    val, ok := strconv.parse_int(t.text)
    if ok {
        node.num_str = t.text
        return node, true
    }
    else {
        return nil, false
    }
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
    args: []^Expression,
}

new_func_call :: proc(func_name: ^Identifier, args: []^Expression) -> ^Func_Call {
    ast := new(Func_Call)
    ast.func = func_name
    ast.args = args

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

Bool_Literal :: struct {
    using base_val: Value,
    value: bool,
}

new_bool_literal :: proc(val: bool) -> ^Bool_Literal{
    boolean := new(Bool_Literal)
    boolean.value = val
    return boolean
}

Comparison :: struct {
    // TODO - we should allow multiple comparisons
    // eg. a == b == c >= 2
    // This could be implemented by tracking several expressions
}

Any_Node :: union {
    ^Array_Literal,
    ^Assignment,
    ^Binary_Op,
    ^Bool_Literal,
    ^Declaration,
    ^Expression_Statement,
    ^Float_Literal,
    ^Func_Call,
    ^Identifier,
    ^Integer_Literal,
    ^Number_Literal,
    ^String_Literal,
    ^Unary_Op,
}

Any_Statement :: union {
    ^Declaration,
    ^Assignment,
    ^Expression_Statement,
}

Any_Expr :: union {
    ^Array_Literal,
    ^Binary_Op,
    ^Bool_Literal,
    ^Float_Literal,
    ^Func_Call,
    ^Identifier,
    ^Integer_Literal,
    ^String_Literal,
    ^Unary_Op,
}

Any_Number :: struct {
    ^Integer_Literal,
    ^Float_Literal,
}

Any_Value :: union {
    ^Identifier,
    ^String_Literal,
    ^Integer_Literal,
    ^Float_Literal,
    ^Array_Literal,
    ^Bool_Literal,
    ^Unary_Op,
    ^Func_Call,
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
    switch n in &n.derived_node {
        case ^Number_Literal: return true
        case ^Float_Literal: return true
        case ^Integer_Literal: return true
        case ^String_Literal: return true
        case ^Array_Literal: return true
        case ^Identifier: return true
        case ^Bool_Literal: return true
        case ^Unary_Op: return true
        
        case ^Assignment: return false
        case ^Binary_Op: return false
        case ^Declaration: return false
        case ^Expression_Statement: return false
        case ^Func_Call: return false
        case: return false
    }
    
    return false
}