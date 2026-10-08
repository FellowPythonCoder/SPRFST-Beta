# std.core

`std/core.spf`

## Uses

- `std.math`

## Functions

### `fn between(value: Num, low: Num, high: Num) -> Bool`

Keep a number inside a range.

### `fn sign(value: Num) -> Int`

The sign of a number: -1, 0 or 1.

### `fn blend(from: Num, to: Num, amount: Num) -> Num`

Move part of the way from one number to another.

### `fn round_to(value: Num, places: Int) -> Num`

Round to a number of decimal places.

### `fn times(count: Int, work: fn(Int) -> Any) -> [Any]`

Repeat a piece of work and give back every result.

### `fn first_set(values: [Any?]) -> Any?`

The first value that is not nothing.

### `fn human_size(bytes: Int) -> Text`

Readable byte sizes, for logs and status lines.

### `fn human_time(seconds: Num) -> Text`

A short readable duration.

