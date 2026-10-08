# std.ai

`std/ai.spf`

## Uses

- `std.tensor`
- `std.math`
- `std.rand`
- `std.io`

## Types

### object `Dense`

One fully connected layer: outputs = activation(inputs * weights + bias)

| field | type | notes |
|---|---|---|
| `inputs` | `Int` | has a default |
| `outputs` | `Int` | has a default |
| `activation` | `Text` | has a default |
| `weights` | `[Num]` | has a default |
| `bias` | `[Num]` | has a default |

**Methods**

- `fn start(self)` — Fill the weights with small random numbers.
- `fn forward(self, x: [Num]) -> [Num]` — Run one example through the layer.

### object `Network`

A two layer network, trained by gradient descent.

| field | type | notes |
|---|---|---|
| `hidden` | `Dense` | has a default |
| `output` | `Dense` | has a default |
| `rate` | `Num` | has a default |

**Methods**

- `fn build(self, inputs: Int, middle: Int, outputs: Int)`
- `fn predict(self, x: [Num]) -> [Num]`
- `fn learn(self, x: [Num], wanted: [Num]) -> Num` — One training step over a single example.
- `fn train(self, inputs: [[Num]], wanted: [[Num]], rounds: Int, show: Bool) -> Num` — Train over a whole dataset for a number of rounds.

## Functions

### `fn apply(kind: Text, x: Num) -> Num`

The activation functions the layers can use.

### `fn slope(kind: Text, y: Num) -> Num`

The slope of an activation, given its output.

### `fn loss(got: [Num], wanted: [Num]) -> Num`

Mean squared error between a prediction and the wanted answer.

### `fn tokenize(text: Text) -> [Text]`

Turn text into a list of word tokens.

### `fn vocabulary(words: [Text]) -> Map<Text, Int>`

Build a word to number lookup from a body of text.

