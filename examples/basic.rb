# frozen_string_literal: true
require_relative '../lib/convolutional'

code = Conv.new(3, 'G0' => [1, 1, 1], 'G1' => [1, 1, 0])
message = '10110000'
encoded = code.encode(message)
received = encoded.dup
received[2] ^= 1
puts "Input:    #{message}"
puts "Encoded:  #{encoded.join}"
puts "Received: #{received.join}"
puts "Decoded:  #{code.decode(received).join}"
puts "State 00: #{code.state_mach.fetch('00').inspect}"
puts "Punctured: #{code.puncture(encoded, [[1, 1], [1, 0]]).join}"

matrix = [[1, 1], [1, 0]]
punctured = code.puncture(encoded, matrix)
punctured[0] ^= 1
puts "Punctured received: #{punctured.join}"
puts "Punctured decoded:  #{code.decode(punctured, puncture_matrix: matrix, input_length: message.length).join}"
