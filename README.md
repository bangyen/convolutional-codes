# Ruby Convolutional Codes

A small, dependency-free educational Ruby library for binary convolutional encoding and hard-decision Viterbi decoding. Its state machine is inspectable so you can follow how register contents, output symbols, and decoding paths relate.

This project targets learning and small experiments. It is not a real-time radio or production communications toolkit. The implementation supports rate-1/n feedforward encoders, configurable constraint lengths, and punctured encoding/decoding.

## Run locally

Requires Ruby 3.1 or later. Clone the repository, then run:

```sh
ruby examples/basic.rb
ruby test/convolutional_test.rb
```

For development with Rake:

```sh
bundle install
bundle exec rake test
```

## Usage

```ruby
require_relative 'lib/convolutional' # From the repository root
# require 'convolutional'           # When installed as a gem

code = Conv.new(3, 'G0' => [1, 1, 1], 'G1' => [1, 1, 0])
encoded = code.encode('1011')
# => [1, 1, 1, 1, 0, 1, 0, 0]
code.decode(encoded)
# => [1, 0, 1, 1]

# A longer example with one flipped received bit:
received = code.encode('10110000')
received[2] ^= 1
code.decode(received)
# => [1, 0, 1, 1, 0, 0, 0, 0]
```

Bits may be binary strings or arrays of integer zeros and ones. Results are arrays. Invalid inputs raise `ArgumentError`. The original `src/convolutional.rb` entry point remains available.

## Generator and state conventions

The constraint length K is the number of bits in the encoder register, including the current input. Each generator has exactly K coefficients. Coefficients run from the **current input to the oldest memory bit**. Generator hash insertion order determines output bit order.

For K=3, a register `[input, previous_input, older_input]` is multiplied by each generator modulo two. With G0=`111` and G1=`110`, input `1` from state `00` emits `11` and moves to state `10`.

```ruby
code.state_mach['00']
# => [{ 'new' => '00', 'out' => '00' },
#     { 'new' => '10', 'out' => '11' }]
```

States contain K−1 bits, newest first. Transition index 0 or 1 is the input bit. The returned state machine is cached and frozen. Generator coefficients are copied and frozen at construction.

Every encode and decode call starts at the all-zero state. Encoding emits one n-bit output symbol per input bit and **does not append termination bits**. Decoding chooses the lowest-distance final state without requiring it to be zero. If you append K−1 zero input bits yourself, decoding returns them too; remove them yourself when interpreting the message.

Viterbi decoding minimizes Hamming distance to the received bits. Equal metrics retain the first encountered candidate, making ties deterministic. Recovery is not guaranteed for every corrupted message, especially short messages or errors near the end. Generator validation checks shape and binary coefficients, but does not establish that a code is noncatastrophic or has good error-correction properties.

## Puncturing

A puncturing matrix has one row per generator and one column per time step in its repeating pattern. One retains a bit; zero discards it. Output symbols are interleaved by generator, so the matrix is read column by column.

```ruby
code.puncture('01110010', [[1, 1], [1, 0]])
# => [0, 1, 1, 0, 0, 1]
```

This pattern retains both generator bits at the first step, then only G0 at the second, and repeats. Matrices must be binary, nonempty, rectangular, and retain at least one bit. Input must contain complete output symbols.

Decode punctured output by supplying the same matrix and the original number of input bits:

```ruby
message = '10110000'
matrix = [[1, 1], [1, 0]]
received = code.puncture(code.encode(message), matrix)
received[0] ^= 1
code.decode(received, puncture_matrix: matrix, input_length: message.length)
# => [1, 0, 1, 1, 0, 0, 0, 0]
```

Missing positions become internal erasures and contribute no Hamming-distance penalty. `input_length` is required because punctured bit count alone can be ambiguous, especially when a whole time step is erased. Include any manually appended termination bits in that length. The received bit count must exactly match the matrix and length, including a partial final pattern. Both encoding and decoding begin at the first matrix column; arbitrary pattern offsets are not supported.

Puncturing discards redundancy and can introduce equally likely messages or reduce error recovery. A valid matrix does not guarantee that every message or single-bit error can be recovered. Ties follow the same deterministic rule as ordinary decoding. With no matrix, `decode(bits)` keeps its original behavior.

## API

| Method | Purpose |
| --- | --- |
| `Conv.new(k, generators)` | Configure a rate-1/n encoder |
| `encode(bits)` | Encode from the zero state |
| `decode(bits, puncture_matrix: nil, input_length: nil)` | Decode complete or explicitly punctured symbols using hard decisions |
| `puncture(bits, matrix)` | Apply a repeating retention pattern |
| `state_mach` | Inspect frozen state transitions |
| `output(register)` | Calculate one output symbol |
| `Conv.convert(bits)` | Validate and copy binary input |
| `Conv.product(a, b)` | Calculate a binary dot product |
| `Conv.distance(a, b)` | Calculate Hamming distance |
| `next_path(path, symbol)` | Expand a legacy `[bits, state, metric]` path |
| `minimize(nested_paths)` | Keep the lowest-metric legacy path per state |

## Development and scope

Tests cover known output vectors, constraint lengths 1–4, noisy decoding compared with an exhaustive minimum-distance oracle, repeating puncturing, punctured decoding against an exhaustive oracle, erased time steps, invalid inputs, and compatibility helpers. GitHub Actions runs tests, the example, and gem packaging across Ruby versions.

The decoder caches the 2^(K−1) states and keeps one survivor per state. Predecessor links avoid repeatedly copying entire decoded paths. For fixed n, work is O(T × 2^(K−1)) and traceback storage is O(T × 2^(K−1)), where T is the number of received symbols. Large constraint lengths or long streams can consume substantial memory. Streaming, soft decisions, recursive encoders, tail-biting, and arbitrary puncturing offsets are outside the current scope.

Keep maintenance focused on correctness, clear examples, and Ruby compatibility. Broader communications experimentation is served by projects such as [Komm](https://komm.dev/) and [CommPy](https://github.com/veeresht/CommPy).

## Build a local gem

```sh
gem build convolutional-codes.gemspec
gem install ./convolutional-codes-0.1.0.gem
```

These instructions build and install locally; this repository does not imply a published RubyGems release.

## License

GPL-3.0-only. See [LICENSE](LICENSE).
