package interpreter

import "core:intrinsics"
import "core:mem"

Value :: struct {
    derived_val: Any_Value
}

Any_Value :: union {
    ^Integer,
    ^Float,
    ^String,
    ^Nil,
    ^Array,
    ^Bool,
}

Integer :: struct {
    using base: Value,
    val_int: int,
}

Float :: struct {
    using base: Value,
    val_float: f32,
}

String :: struct {
    using base: Value,
    val_string: string,
}

Nil :: struct {
    using base: Value,
}

Array :: struct {
    using base: Value,
    items: [dynamic]^Value,
}

Bool :: struct {
    using base: Value,
    boolean: bool,
}

new :: proc($T: typeid) -> ^T {
	n, _ := mem.new(T)
	n.derived_val = n
	base: ^Value = n // dummy check
	_ = base
	return n
}

is_number :: proc(val: ^Value) -> bool {
    #partial switch n in &val.derived_val {
        case ^Float: return true
        case ^Integer: return true
    }
    return false
}

is_int :: proc(val: ^Value) -> bool {
    #partial switch n in &val.derived_val {
        case ^Integer: return true
    }
    return false
}

is_string :: proc(val: ^Value) -> bool {
    if s, ok := val.derived_val.(^String); ok {
        return true
    }
    return false
}

get_string :: proc(val: ^Value) -> string {
    s, ok := val.derived_val.(^String)
    assert(ok)
    return s.val_string
}