# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../lib/convolutional'

class ConvolutionalTest < Minitest::Test
  def setup
    @code = Conv.new(3, 'G0' => [1, 1, 1], 'G1' => [1, 1, 0])
  end

  def test_known_vector_and_transitions
    assert_equal [1, 1, 1, 1, 0, 1, 0, 0], @code.encode('1011')
    assert_equal [1, 0, 1, 1], @code.decode('11110100')
    assert_equal [{ 'new' => '00', 'out' => '00' }, { 'new' => '10', 'out' => '11' }], @code.state_mach['00']
    assert_equal [{ 'new' => '00', 'out' => '10' }, { 'new' => '10', 'out' => '01' }], @code.state_mach['01']
    assert_same @code.state_mach, @code.state_mach
    assert @code.state_mach['00'][0].frozen?
  end

  def test_round_trips_across_constraint_lengths
    (1..4).each do |length|
      code = Conv.new(length, 'G0' => [1] * length, 'G1' => [1] + [0] * (length - 1))
      (0...64).each do |number|
        input = number.to_s(2).rjust(6, '0')
        assert_equal Conv.convert(input), code.decode(code.encode(input)), "K=#{length}, input=#{input}"
      end
    end
  end

  def test_viterbi_matches_brute_force_minimum_distance
    messages = (0...8).map { |number| Conv.convert(number.to_s(2).rjust(3, '0')) }
    codewords = messages.map { |message| @code.encode(message) }
    (0...64).each do |number|
      received = Conv.convert(number.to_s(2).rjust(6, '0'))
      minimum = codewords.map { |word| Conv.distance(word, received) }.min
      decoded = @code.decode(received)
      assert_equal 3, decoded.size
      assert_equal minimum, Conv.distance(@code.encode(decoded), received)
    end
  end

  def test_corrects_a_single_bit_error
    received = @code.encode('10110000')
    received[2] ^= 1
    assert_equal Conv.convert('10110000'), @code.decode(received)
  end

  def test_repeating_puncture_pattern
    assert_equal [0, 1, 1, 0, 0, 1], @code.puncture('01110010', [[1, 1], [1, 0]])
    assert_equal [], @code.puncture([], [[1], [1]])
  end

  def test_punctured_decoding_matches_brute_force
    # Includes a partial pattern and a completely erased time step.
    [[[1, 1], [1, 0]], [[1, 0], [1, 0]], [[1], [1]]].each do |matrix|
      messages = (0...8).map { |number| Conv.convert(number.to_s(2).rjust(3, '0')) }
      codewords = messages.map { |message| @code.puncture(@code.encode(message), matrix) }
      (0...(2**codewords.first.size)).each do |number|
        received = Conv.convert(number.to_s(2).rjust(codewords.first.size, '0'))
        decoded = @code.decode(received, puncture_matrix: matrix, input_length: 3)
        minimum = codewords.map { |word| Conv.distance(word, received) }.min
        assert_equal 3, decoded.size
        assert_equal minimum, Conv.distance(@code.puncture(@code.encode(decoded), matrix), received)
      end
    end
  end

  def test_punctured_round_trip_and_error_recovery
    matrix = [[1, 1], [1, 0]]
    (0...64).each do |number|
      input = Conv.convert(number.to_s(2).rjust(6, '0'))
      received = @code.puncture(@code.encode(input), matrix)
      assert_equal input, @code.decode(received, puncture_matrix: matrix, input_length: input.size)
    end
    input = Conv.convert('10110000')
    received = @code.puncture(@code.encode(input), matrix)
    received[0] ^= 1
    assert_equal input, @code.decode(received, puncture_matrix: matrix, input_length: input.size)
    assert_equal [], @code.decode([], puncture_matrix: matrix, input_length: 0)
    # An entirely erased first step still produces the requested number of bits.
    assert_equal [0], @code.decode([], puncture_matrix: [[0, 1], [0, 1]], input_length: 1)
  end

  def test_invalid_punctured_decoding
    matrix = [[1, 1], [1, 0]]
    [nil, -1, 1.5, '3'].each do |length|
      assert_raises(ArgumentError) { @code.decode('111', puncture_matrix: matrix, input_length: length) }
    end
    ['11', '1111'].each do |bits|
      assert_raises(ArgumentError) { @code.decode(bits, puncture_matrix: matrix, input_length: 2) }
    end
    assert_raises(ArgumentError) { @code.decode('11', input_length: 1) }
    [[[1]], [[1], [1, 0]], [[], []], [[0], [0]], [[1], [2]]].each do |bad_matrix|
      assert_raises(ArgumentError) { @code.decode([], puncture_matrix: bad_matrix, input_length: 0) }
    end
  end

  def test_empty_inputs
    assert_equal [], @code.encode('')
    assert_equal [], @code.decode([])
  end

  def test_invalid_bits_and_vectors
    ['10x', '102', [0, 2], [true], [1.0], nil, 12].each do |input|
      assert_raises(ArgumentError) { Conv.convert(input) }
      assert_raises(ArgumentError) { @code.encode(input) }
      assert_raises(ArgumentError) { @code.decode(input) }
    end
    assert_raises(ArgumentError) { Conv.distance([1], [1, 0]) }
    assert_raises(ArgumentError) { Conv.product([1], [1, 0]) }
    assert_raises(ArgumentError) { @code.output('10') }
    assert_raises(ArgumentError) { @code.decode('101') }
    assert_equal 1, Conv.product('110', '100')
    assert_equal 2, Conv.distance('110', '101')
  end

  def test_invalid_configuration
    [0, -1, 2.5, nil].each do |length|
      assert_raises(ArgumentError) { Conv.new(length, 'G0' => [1]) }
    end
    [{}, nil, { 'G0' => [1, 0] }, { 'G0' => [0, 0, 0] }].each do |generators|
      assert_raises(ArgumentError) { Conv.new(3, generators) }
    end
    [[[1]], [[1], [1, 0]], [[], []], [[0], [0]], [[1], [2]], nil].each do |matrix|
      assert_raises(ArgumentError) { @code.puncture('1100', matrix) }
    end
    assert_raises(ArgumentError) { @code.puncture('1', [[1], [1]]) }
  end

  def test_generator_configuration_is_copied_and_frozen
    generators = { 'G0' => [1, 1, 1] }
    code = Conv.new(3, generators)
    generators['G0'][0] = 0
    assert_equal [1, 1, 1], code.gen['G0']
    assert code.gen.frozen?
    assert code.gen['G0'].frozen?
  end

  def test_legacy_entry_point_and_helpers
    require_relative '../src/convolutional'
    paths = @code.next_path(['', '00', 0], '11')
    assert_equal [['0', '00', 2], ['1', '10', 0]], paths
    assert_equal [['1', '10', 0]], @code.minimize([[['0', '10', 2]], [['1', '10', 0]]])
  end
end
