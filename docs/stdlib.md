# Standard library

Every function below is built into the runtime.

## io

`use std.io`

| function | signature | does |
|---|---|---|
| `io.say` | `(Any) -> Nil` | Write a value and a line break to standard output |
| `io.print` | `(Any) -> Nil` | Write a value with no trailing line break |
| `io.warn` | `(Any) -> Nil` | Write a value to standard error |
| `io.ask` | `(Text) -> Text` | Print a prompt and read one line from standard input |
| `io.read_line` | `() -> Text?` | Read one line of standard input, or nil at end |
| `io.flush` | `() -> Nil` | Flush buffered output |

## math

`use std.math`

| function | signature | does |
|---|---|---|
| `math.sqrt` | `(Num) -> Num` | Square root |
| `math.abs` | `(Num) -> Num` | Absolute value |
| `math.floor` | `(Num) -> Int` | Round down to an Int |
| `math.ceil` | `(Num) -> Int` | Round up to an Int |
| `math.round` | `(Num) -> Int` | Round to the nearest Int |
| `math.pow` | `(Num, Num) -> Num` | Raise to a power |
| `math.sin` | `(Num) -> Num` | Sine of an angle in radians |
| `math.cos` | `(Num) -> Num` | Cosine of an angle in radians |
| `math.tan` | `(Num) -> Num` | Tangent of an angle in radians |
| `math.atan2` | `(Num, Num) -> Num` | Angle of the vector (x, y) |
| `math.log` | `(Num) -> Num` | Natural logarithm |
| `math.log2` | `(Num) -> Num` | Base 2 logarithm |
| `math.log10` | `(Num) -> Num` | Base 10 logarithm |
| `math.exp` | `(Num) -> Num` | e raised to a power |
| `math.min` | `(Num, Num) -> Num` | Smaller of two numbers |
| `math.max` | `(Num, Num) -> Num` | Larger of two numbers |
| `math.clamp` | `(Num, Num, Num) -> Num` | Clamp a value into a range |
| `math.pi` | `() -> Num` | The constant pi |
| `math.e` | `() -> Num` | Euler's number |
| `math.inf` | `() -> Num` | Positive infinity |
| `math.is_nan` | `(Num) -> Bool` | True when the value is not a number |
| `math.hypot` | `(Num, Num) -> Num` | Length of the vector (x, y) |

## fs

`use std.fs`

| function | signature | does |
|---|---|---|
| `fs.read` | `(Text) -> Text?` | Read a whole file as text |
| `fs.write` | `(Text, Text) -> Bool` | Write text to a file |
| `fs.append` | `(Text, Text) -> Bool` | Append text to a file |
| `fs.exists` | `(Text) -> Bool` | True when a path exists |
| `fs.remove` | `(Text) -> Bool` | Delete a file |
| `fs.list` | `(Text) -> [Text]` | Names inside a directory |
| `fs.mkdir` | `(Text) -> Bool` | Create a directory and its parents |
| `fs.is_dir` | `(Text) -> Bool` | True when a path is a directory |
| `fs.is_file` | `(Text) -> Bool` | True when a path is a regular file |
| `fs.size` | `(Text) -> Int` | Size of a file in bytes |
| `fs.copy` | `(Text, Text) -> Bool` | Copy a file |
| `fs.rename` | `(Text, Text) -> Bool` | Rename or move a file |
| `fs.read_bytes` | `(Text) -> [Int]?` | Read a file as a list of bytes |
| `fs.write_bytes` | `(Text, [Int]) -> Bool` | Write a list of bytes to a file |

## path

`use std.path`

| function | signature | does |
|---|---|---|
| `path.join` | `(Text, Text) -> Text` | Join two path parts |
| `path.dirname` | `(Text) -> Text` | Directory part of a path |
| `path.basename` | `(Text) -> Text` | File name part of a path |
| `path.ext` | `(Text) -> Text` | Extension of a path |
| `path.abs` | `(Text) -> Text` | Absolute form of a path |

## time

`use std.time`

| function | signature | does |
|---|---|---|
| `time.now` | `() -> Num` | Seconds since the epoch, with fractions |
| `time.ms` | `() -> Int` | Milliseconds since the epoch |
| `time.clock` | `() -> Num` | High resolution timer in seconds |
| `time.sleep` | `(Num) -> Nil` | Pause for a number of seconds |
| `time.format` | `(Num, Text) -> Text` | Format a timestamp (%Y-%m-%d %H:%M:%S) |
| `time.parts` | `(Num) -> [Text: Int]` | Year, month, day, hour, minute, second |

## rand

`use std.rand`

| function | signature | does |
|---|---|---|
| `rand.seed` | `(Int) -> Nil` | Seed the generator |
| `rand.int` | `(Int, Int) -> Int` | Random integer in a range |
| `rand.num` | `() -> Num` | Random number between 0 and 1 |
| `rand.choice` | `([T]) -> T?` | Random item from a list |
| `rand.shuffle` | `([T]) -> [T]` | Shuffled copy of a list |
| `rand.normal` | `(Num, Num) -> Num` | Normally distributed random number |

## sys

`use std.sys`

| function | signature | does |
|---|---|---|
| `sys.args` | `() -> [Text]` | Command line arguments |
| `sys.env` | `(Text) -> Text?` | Value of an environment variable |
| `sys.set_env` | `(Text, Text) -> Nil` | Set an environment variable |
| `sys.exit` | `(Int) -> Nil` | Stop the program with an exit code |
| `sys.platform` | `() -> Text` | Operating system name |
| `sys.arch` | `() -> Text` | Processor architecture |
| `sys.cpu_count` | `() -> Int` | Number of logical processors |
| `sys.run` | `(Text) -> Text` | Run a shell command and capture its output |
| `sys.memory` | `() -> Int` | Bytes currently allocated by the runtime |

## json

`use std.json`

| function | signature | does |
|---|---|---|
| `json.parse` | `(Text) -> Any?` | Parse JSON text into values |
| `json.write` | `(Any) -> Text` | Serialise a value as JSON |
| `json.pretty` | `(Any) -> Text` | Serialise a value as indented JSON |

## csv

`use std.csv`

| function | signature | does |
|---|---|---|
| `csv.parse` | `(Text) -> [[Text]]` | Parse CSV text into rows |
| `csv.write` | `([[Text]]) -> Text` | Write rows as CSV text |

## hash

`use std.hash`

| function | signature | does |
|---|---|---|
| `hash.sha256` | `(Text) -> Text` | SHA-256 digest as hex text |
| `hash.crc32` | `(Text) -> Int` | CRC-32 checksum |
| `hash.fnv64` | `(Text) -> Int` | FNV-1a 64 bit hash |
| `hash.base64` | `(Text) -> Text` | Base64 encode |
| `hash.unbase64` | `(Text) -> Text` | Base64 decode |
| `hash.hmac_sha256` | `(Text, Text) -> Text` | HMAC-SHA-256 of a message with a key |

## net

`use std.net`

| function | signature | does |
|---|---|---|
| `net.listen` | `(Int) -> Int` | Listen for TCP connections on a port |
| `net.accept` | `(Int) -> Int` | Accept one TCP connection |
| `net.connect` | `(Text, Int) -> Int` | Open a TCP connection |
| `net.send` | `(Int, Text) -> Int` | Send text on a socket |
| `net.recv` | `(Int, Int) -> Text` | Receive up to n bytes |
| `net.close` | `(Int) -> Nil` | Close a socket |
| `net.resolve` | `(Text) -> Text?` | Resolve a host name to an address |
| `net.udp_open` | `(Int) -> Int` | Open a UDP socket on a port |
| `net.udp_send` | `(Int, Text, Int, Text) -> Int` | Send a UDP datagram |
| `net.udp_recv` | `(Int, Int) -> Text` | Receive a UDP datagram |
| `net.hostname` | `() -> Text` | Name of this machine |

## http

`use std.http`

| function | signature | does |
|---|---|---|
| `http.get` | `(Text) -> Text?` | Fetch a URL with GET |
| `http.post` | `(Text, Text) -> Text?` | Send a POST request |
| `http.serve` | `(Int, fn(Any) -> Any) -> Nil` | Run an HTTP server on a port |
| `http.stop` | `() -> Nil` | Stop the running HTTP server |
| `http.url_encode` | `(Text) -> Text` | Percent-encode text for a URL |
| `http.url_decode` | `(Text) -> Text` | Decode percent-encoded text |

## thread

`use std.thread`

| function | signature | does |
|---|---|---|
| `thread.spawn` | `(fn() -> Any) -> Future<Any>` | Run a function on another thread |
| `thread.cpus` | `() -> Int` | Number of hardware threads |
| `thread.sleep` | `(Num) -> Nil` | Pause this thread |
| `thread.lock` | `() -> Int` | Create a mutual exclusion lock |
| `thread.acquire` | `(Int) -> Nil` | Take a lock |
| `thread.release` | `(Int) -> Nil` | Release a lock |
| `thread.atomic_add` | `(Int, Int) -> Int` | Atomically add to a counter |
| `thread.counter` | `(Int) -> Int` | Create an atomic counter with a start value |
| `thread.channel` | `(Int) -> Chan<Any>` | Create a channel with a buffer size |

## task

`use std.task`

| function | signature | does |
|---|---|---|
| `task.sleep` | `(Num) -> Nil` | Suspend the current task |
| `task.yield` | `() -> Nil` | Give other tasks a turn |
| `task.run_all` | `() -> Nil` | Run queued tasks until they finish |
| `task.pending` | `() -> Int` | How many tasks are waiting |

## db

`use std.db`

| function | signature | does |
|---|---|---|
| `db.open` | `(Text) -> Int` | Open or create an Ember database file |
| `db.exec` | `(Int, Text) -> Int` | Run a statement, give the number of affected rows |
| `db.query` | `(Int, Text) -> [[Text: Any]]` | Run a query and return rows |
| `db.close` | `(Int) -> Nil` | Close a database |
| `db.begin` | `(Int) -> Nil` | Start a transaction |
| `db.commit` | `(Int) -> Nil` | Commit a transaction |
| `db.rollback` | `(Int) -> Nil` | Undo a transaction |
| `db.tables` | `(Int) -> [Text]` | Names of the tables in a database |

## tensor

`use std.tensor`

| function | signature | does |
|---|---|---|
| `tensor.make` | `([Int], [Num]) -> Any` | Create a tensor with a shape and data |
| `tensor.zeros` | `([Int]) -> Any` | Tensor filled with zeros |
| `tensor.random` | `([Int], Num) -> Any` | Tensor filled with random values |
| `tensor.shape` | `(Any) -> [Int]` | Shape of a tensor |
| `tensor.at` | `(Any, Int) -> Num` | Read one element by flat index |
| `tensor.put` | `(Any, Int, Num) -> Nil` | Write one element by flat index |
| `tensor.add` | `(Any, Any) -> Any` | Element-wise addition |
| `tensor.sub` | `(Any, Any) -> Any` | Element-wise subtraction |
| `tensor.mul` | `(Any, Any) -> Any` | Element-wise multiplication |
| `tensor.scale` | `(Any, Num) -> Any` | Multiply every element by a number |
| `tensor.matmul` | `(Any, Any) -> Any` | Matrix multiplication |
| `tensor.transpose` | `(Any) -> Any` | Transpose a 2D tensor |
| `tensor.relu` | `(Any) -> Any` | Rectified linear activation |
| `tensor.sigmoid` | `(Any) -> Any` | Logistic activation |
| `tensor.tanh` | `(Any) -> Any` | Hyperbolic tangent activation |
| `tensor.softmax` | `(Any) -> Any` | Softmax over the last dimension |
| `tensor.sum` | `(Any) -> Num` | Sum of every element |
| `tensor.mean` | `(Any) -> Num` | Average of every element |
| `tensor.argmax` | `(Any) -> Int` | Index of the largest element |
| `tensor.to_list` | `(Any) -> [Num]` | Elements as a flat list |
| `tensor.dot` | `(Any, Any) -> Num` | Dot product of two tensors |

## ui

`use std.ui`

| function | signature | does |
|---|---|---|
| `ui.window` | `(Text, Int, Int) -> Int` | Create a window and return its id |
| `ui.node` | `(Int, Text, Text) -> Int` | Add a widget to a parent and return its id |
| `ui.set` | `(Int, Text, Any) -> Nil` | Set a widget property |
| `ui.get` | `(Int, Text) -> Any` | Read a widget property |
| `ui.on` | `(Int, Text, fn() -> Nil) -> Nil` | Attach an event handler |
| `ui.run` | `() -> Nil` | Run the user interface event loop |
| `ui.quit` | `() -> Nil` | Close the user interface |
| `ui.describe` | `() -> Text` | JSON description of the current UI tree |
| `ui.emit` | `(Int, Text) -> Nil` | Deliver an event to a widget (used by hosts) |
| `ui.backend` | `() -> Text` | Name of the active UI backend |

## draw

`use std.draw`

| function | signature | does |
|---|---|---|
| `draw.canvas` | `(Int, Int) -> Any` | Create an image buffer |
| `draw.clear` | `(Any, Int) -> Nil` | Fill an image with a colour |
| `draw.pixel` | `(Any, Int, Int, Int) -> Nil` | Set one pixel |
| `draw.line` | `(Any, Int, Int, Int, Int, Int) -> Nil` | Draw a line |
| `draw.rect` | `(Any, Int, Int, Int, Int, Int) -> Nil` | Draw a filled rectangle |
| `draw.circle` | `(Any, Int, Int, Int, Int) -> Nil` | Draw a filled circle |
| `draw.text` | `(Any, Int, Int, Text, Int) -> Nil` | Draw text with the built-in font |
| `draw.save_png` | `(Any, Text) -> Bool` | Write an image to a PNG file |
| `draw.rgb` | `(Int, Int, Int) -> Int` | Pack a colour from red, green and blue |
| `draw.size` | `(Any) -> [Int]` | Width and height of an image |

## Built in

Available everywhere, no import needed.

| function | signature | does |
|---|---|---|
| `len` | `(Any) -> Int` | Length of text, list, map or set |
| `to_text` | `(Any) -> Text` | Convert any value to readable text |
| `to_int` | `(Any) -> Int` | Convert a number or text to Int |
| `to_num` | `(Any) -> Num` | Convert a number or text to Num |
| `type_of` | `(Any) -> Text` | Name of a value's runtime type |
| `assert` | `(Bool, Text) -> Nil` | Fail the program when a condition is false |
| `panic` | `(Text) -> Nil` | Stop the program with an error |
| `clone` | `(Any) -> Any` | Deep copy of a value |
| `hash_of` | `(Any) -> Int` | Stable hash of a value |
| `range` | `(Int, Int) -> [Int]` | List of integers from start up to end |
| `set` | `([T]) -> {T}` | Make a set out of a list |

## Methods on built in types

| type | method | signature | does |
|---|---|---|---|
| `Text` | `len` | `() -> Int` | Number of bytes in the text |
| `Text` | `chars` | `() -> [Text]` | Split into a list of characters |
| `Text` | `upper` | `() -> Text` | Uppercase copy |
| `Text` | `lower` | `() -> Text` | Lowercase copy |
| `Text` | `trim` | `() -> Text` | Remove leading and trailing whitespace |
| `Text` | `split` | `(Text) -> [Text]` | Split on a separator |
| `Text` | `lines` | `() -> [Text]` | Split into lines |
| `Text` | `contains` | `(Text) -> Bool` | True when the text contains a part |
| `Text` | `starts_with` | `(Text) -> Bool` | True when the text starts with a prefix |
| `Text` | `ends_with` | `(Text) -> Bool` | True when the text ends with a suffix |
| `Text` | `replace` | `(Text, Text) -> Text` | Replace every occurrence |
| `Text` | `slice` | `(Int, Int) -> Text` | Substring between two byte offsets |
| `Text` | `index_of` | `(Text) -> Int` | Byte offset of a part, or -1 |
| `Text` | `repeat` | `(Int) -> Text` | Repeat the text n times |
| `Text` | `pad_left` | `(Int, Text?) -> Text` | Pad on the left to a width |
| `Text` | `pad_right` | `(Int, Text?) -> Text` | Pad on the right to a width |
| `Text` | `to_int` | `() -> Int?` | Parse an Int, nil when it is not a number |
| `Text` | `to_num` | `() -> Num?` | Parse a Num, nil when it is not a number |
| `Text` | `reverse` | `() -> Text` | Reversed copy |
| `Text` | `code_at` | `(Int) -> Int` | Byte value at an offset |
| `Text` | `char_at` | `(Int) -> Text` | One character at an offset |
| `Text` | `is_empty` | `() -> Bool` | True when the text has no bytes |
| `Text` | `bytes` | `() -> [Int]` | Bytes of the text as a list |
| `Text` | `to_text` | `() -> Text` | The text itself |
| `List` | `len` | `() -> Int` | Number of items |
| `List` | `push` | `(T) -> Nil` | Append an item |
| `List` | `pop` | `() -> T?` | Remove and return the last item |
| `List` | `insert` | `(Int, T) -> Nil` | Insert an item at an index |
| `List` | `remove` | `(Int) -> T?` | Remove the item at an index |
| `List` | `clear` | `() -> Nil` | Remove every item |
| `List` | `contains` | `(T) -> Bool` | True when an equal item is present |
| `List` | `index_of` | `(T) -> Int` | Index of an item, or -1 |
| `List` | `first` | `() -> T?` | First item, or nil |
| `List` | `last` | `() -> T?` | Last item, or nil |
| `List` | `slice` | `(Int, Int) -> [T]` | Items between two indexes |
| `List` | `reverse` | `() -> [T]` | Reversed copy |
| `List` | `sort` | `() -> [T]` | Sorted copy, ascending |
| `List` | `sort_by` | `(fn(T, T) -> Bool) -> [T]` | Sorted copy; the test answers "does a come first" |
| `List` | `map` | `(fn(T) -> U) -> [U]` | Apply a function to every item |
| `List` | `filter` | `(fn(T) -> Bool) -> [T]` | Keep the items a test accepts |
| `List` | `reduce` | `(U, fn(U, T) -> U) -> U` | Fold the list into one value |
| `List` | `each` | `(fn(T) -> Nil) -> Nil` | Run a function for every item |
| `List` | `any` | `(fn(T) -> Bool) -> Bool` | True when a test accepts any item |
| `List` | `all` | `(fn(T) -> Bool) -> Bool` | True when a test accepts every item |
| `List` | `count` | `(fn(T) -> Bool) -> Int` | How many items a test accepts |
| `List` | `find` | `(fn(T) -> Bool) -> T?` | First item a test accepts |
| `List` | `join` | `(Text) -> Text` | Join the items into text |
| `List` | `sum` | `() -> Num` | Sum of numeric items |
| `List` | `min` | `() -> T?` | Smallest item |
| `List` | `max` | `() -> T?` | Largest item |
| `List` | `copy` | `() -> [T]` | Shallow copy |
| `List` | `concat` | `([T]) -> [T]` | Copy with another list appended |
| `List` | `take` | `(Int) -> [T]` | First n items |
| `List` | `drop` | `(Int) -> [T]` | All but the first n items |
| `List` | `is_empty` | `() -> Bool` | True when the list has no items |
| `List` | `flatten` | `() -> [Any]` | Flatten one level of nesting |
| `Map` | `len` | `() -> Int` | Number of entries |
| `Map` | `get` | `(K) -> V?` | Value for a key, or nil |
| `Map` | `set` | `(K, V) -> Nil` | Store a value for a key |
| `Map` | `has` | `(K) -> Bool` | True when the key is present |
| `Map` | `remove` | `(K) -> V?` | Remove a key and return its value |
| `Map` | `keys` | `() -> [K]` | Every key |
| `Map` | `values` | `() -> [V]` | Every value |
| `Map` | `clear` | `() -> Nil` | Remove every entry |
| `Map` | `is_empty` | `() -> Bool` | True when the map has no entries |
| `Set` | `add` | `(T) -> Nil` | Add an item |
| `Set` | `has` | `(T) -> Bool` | True when the item is present |
| `Set` | `remove` | `(T) -> Bool` | Remove an item |
| `Set` | `len` | `() -> Int` | Number of items |
| `Set` | `items` | `() -> [T]` | Items as a list |
| `Future` | `wait` | `() -> T` | Block until the task finishes |
| `Future` | `is_done` | `() -> Bool` | True when the task has finished |
| `Chan` | `send` | `(T) -> Nil` | Send a value (blocks when full) |
| `Chan` | `recv` | `() -> T?` | Receive a value (blocks when empty) |
| `Chan` | `try_recv` | `() -> T?` | Receive without blocking |
| `Chan` | `close` | `() -> Nil` | Close the channel |
| `Chan` | `len` | `() -> Int` | Number of queued values |

