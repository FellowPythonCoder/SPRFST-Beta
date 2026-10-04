# std.testing

`std/testing.spf`

## Uses

- `std.io`

## Functions

### `fn same(got: Any, wanted: Any, what: Text)`

Fail unless the two values are the same.

### `fn different(got: Any, unwanted: Any, what: Text)`

Fail unless the two values differ.

### `fn yes(condition: Bool, what: Text)`

Fail unless the condition holds.

### `fn no(condition: Bool, what: Text)`

Fail unless the condition does not hold.

### `fn close(got: Num, wanted: Num, tolerance: Num, what: Text)`

Fail unless two numbers are within a tolerance of each other.

### `fn holds(items: [Any], item: Any, what: Text)`

Fail unless the list contains the item.

### `fn failed(outcome: Result<Any>, what: Text)`

Fail unless the result carries an error.

