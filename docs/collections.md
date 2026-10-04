# std.collections

`std/collections.spf`

## Functions

### `fn zip(left: [Any], right: [Any]) -> [[Any]]`

Pair up two lists, stopping at the shorter one.

### `fn unique(items: [Any]) -> [Any]`

Remove repeats, keeping the first appearance of each item.

### `fn chunks(items: [Any], size: Int) -> [[Any]]`

Split a list into chunks of at most `size` items.

### `fn tally(items: [Any], matches: fn(Any) -> Bool) -> Int`

Count how many items satisfy a test.

### `fn group_by(items: [Any], key_of: fn(Any) -> Text) -> Map<Text, [Any]>`

Group items by a key worked out from each item.

### `fn span(numbers: [Num]) -> [Num]`

The smallest and largest values, as a two item list.

### `fn mean(numbers: [Num]) -> Num`

The average of a list of numbers.

