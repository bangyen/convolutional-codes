# convolutional-codes
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/c27c7ee72adc46038bc117bc56d766a1)](https://www.codacy.com/manual/bangyen99/convolutional-codes?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=bangyen/convolutional-codes&amp;utm_campaign=Badge_Grade)\
Ruby class implementation of convolutional code encoding and decoding.

## Format
Generator polynomials will be represented as a hash of lists, e.g. G0 = 111 and G1 = 110 would equal
```
polynomials = {
  'G0' => [1, 1, 1],
  'G1' => [1, 1, 0]
}
```
Finite-state machines will be represented similarly. Take, for example, a convolutional code with constraint length 3 and the aforementioned polynomials.
```
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
