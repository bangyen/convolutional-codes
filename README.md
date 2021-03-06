# Ruby Convolutional Codes
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/c27c7ee72adc46038bc117bc56d766a1)](https://www.codacy.com/manual/bangyen99/convolutional-codes?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=bangyen/convolutional-codes&amp;utm_campaign=Badge_Grade)
[![Coding Style](https://img.shields.io/badge/code%20style-rubocop-brightgreen)](https://github.com/rubocop-hq/rubocop)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0) \
Ruby class implementation of convolutional code encoding and decoding.

## Format
Generator polynomials will be represented as a hash of lists, e.g. G0 = 111 and G1 = 110 would equal
```ruby
polynomials = {
  'G0' => [1, 1, 1],
  'G1' => [1, 1, 0]
}
```
Finite-state automata (FSA) will be represented similarly. Take, for example, a convolutional code with constraint length 3 and the aforementioned polynomials.
```ruby
ex_fsa = {
  '00' => [
    { 'new' => '00', 'out' => '00' },
    { 'new' => '10', 'out' => '11' }
  ],
  '01' => [
    { 'new' => '00', 'out' => '10' },
    { 'new' => '10', 'out' => '01' }
  ],
  '10' => [
    { 'new' => '01', 'out' => '11' },
    { 'new' => '11', 'out' => '00' }
  ],
  '11' => [
    { 'new' => '01', 'out' => '01' },
    { 'new' => '11', 'out' => '10' }
  ]
}
```
Each key is a state, and each value is a list of hashes representing the new state and output when given an input (the index). The starting and accepting state columns are omitted because convolutional codes start at `'0'*(k - 1)` and don't have accepting states.

## Methods
| Name         | Functionality                                                                                     |
|--------------|---------------------------------------------------------------------------------------------------|
| `convert`    | Preprocesses a string by converting it into an array of integers.                                 |
| `product`    | Finds the dot product of two vectors.                                                             |
| `distance`   | Returns the hamming distance between two vectors.                                                 |
| `output`     | Returns the product of a word and each generator polynomial.                                      |
| `state_mach` | Creates an FSA which represents the given convolutional code.                                     |
| `next_path`  | Generates the new trellis paths, their FSA states, and their respective path metrics.             |
| `minimize`   | Prunes non-survivor trellis paths.                                                                |
| `encode`     | Non-recursively encodes a word using the given constraight length and generator polynomials.      |
| `decode`     | Decodes the codeword using Viterbi decoding.                                                      |
