# frozen_string_literal: true

# A binary, rate-1/n convolutional encoder and hard-decision Viterbi decoder.
class Conv
  VERSION = '0.1.0'

  attr_reader :const, :gen, :gen_num

  def initialize(const, gen)
    unless const.is_a?(Integer) && const.positive?
      raise ArgumentError, 'constraint length must be a positive integer'
    end
    unless gen.is_a?(Hash) && !gen.empty?
      raise ArgumentError, 'generators must be a nonempty hash'
    end
    @const = const
    @gen = gen.transform_values do |polynomial|
      bits = self.class.convert(polynomial)
      raise ArgumentError, 'generator length must equal constraint length' unless bits.size == const
      raise ArgumentError, 'generator must contain a nonzero coefficient' unless bits.include?(1)

      bits.freeze
    end.freeze
    @gen_num = @gen.size
  end

  def self.convert(word)
    bits = if word.is_a?(String) && word.match?(/\A[01]*\z/)
             word.chars.map(&:to_i)
           elsif word.is_a?(Array) && word.all? { |bit| bit.is_a?(Integer) && [0, 1].include?(bit) }
             word.dup
           end
    raise ArgumentError, 'bits must be a binary string or an array of 0 and 1 integers' unless bits

    bits
  end

  def self.product(arr, oth)
    arr, oth = [arr, oth].map { |word| convert(word) }
    raise ArgumentError, 'vectors must have equal lengths' unless arr.size == oth.size

    arr.zip(oth).sum { |a, b| a * b } % 2
  end

  def self.distance(word, other)
    word, other = [word, other].map { |bits| convert(bits) }
    raise ArgumentError, 'vectors must have equal lengths' unless word.size == other.size

    word.zip(other).count { |a, b| a != b }
  end

  def output(word)
    word = self.class.convert(word)
    raise ArgumentError, 'register length must equal constraint length' unless word.size == const

    gen.values.map { |polynomial| self.class.product(polynomial, word) }
  end

  # Frozen transitions are cached; a state stores newest memory bit first.
  def state_mach
    @state_mach ||= (0...(2**(const - 1))).to_h do |number|
      state = const == 1 ? '' : number.to_s(2).rjust(const - 1, '0')
      transitions = [0, 1].map do |bit|
        register = "#{bit}#{state}"
        { 'new' => register[0, const - 1].freeze, 'out' => output(register).join.freeze }.freeze
      end.freeze
      [state.freeze, transitions]
    end.freeze
  end

  # Compatibility helper: [decoded bits, state, path metric].
  def next_path(path, word)
    bits, state, metric = path
    state_mach.fetch(state).each_with_index.map do |transition, bit|
      ["#{bits}#{bit}", transition['new'], metric + self.class.distance(transition['out'], word)]
    end
  end

  def minimize(paths)
    survivors = {}
    paths.flatten(1).each do |path|
      old = survivors[path[1]]
      survivors[path[1]] = path if old.nil? || path[2] < old[2]
    end
    survivors.values
  end

  # Rows correspond to generators; columns repeat over time.
  def puncture(word, matrix)
    bits = self.class.convert(word)
    pattern = puncture_pattern(matrix)
    raise ArgumentError, 'codeword must contain complete output symbols' unless (bits.size % gen_num).zero?

    bits.each_with_index.filter_map { |bit, index| bit if pattern[index % pattern.size] == 1 }
  end

  # Starts at zero; emits one symbol per input bit, with no flush bits.
  def encode(word)
    state = '0' * (const - 1)
    self.class.convert(word).flat_map do |bit|
      transition = state_mach.fetch(state)[bit]
      state = transition['new']
      self.class.convert(transition['out'])
    end
  end

  # Keeps one survivor per state and traces predecessor links once at the end.
  def decode(word, puncture_matrix: nil, input_length: nil)
    bits = self.class.convert(word)
    if puncture_matrix.nil?
      raise ArgumentError, 'input_length requires a puncture matrix' unless input_length.nil?
      raise ArgumentError, 'codeword must contain complete output symbols' unless (bits.size % gen_num).zero?
    else
      pattern = puncture_pattern(puncture_matrix)
      unless input_length.is_a?(Integer) && input_length >= 0
        raise ArgumentError, 'input_length must be a nonnegative integer for punctured decoding'
      end
      total = input_length * gen_num
      cycles, remainder = total.divmod(pattern.size)
      expected = cycles * pattern.sum + pattern.first(remainder).sum
      raise ArgumentError, 'punctured bit count does not match input_length and matrix' unless bits.size == expected

      received = bits.each
      bits = Array.new(total) { |index| received.next if pattern[index % pattern.size] == 1 }
    end

    metrics = { '0' * (const - 1) => 0 }
    history = []
    bits.each_slice(gen_num) do |symbol|
      survivors = {}
      metrics.each do |state, metric|
        state_mach.fetch(state).each_with_index do |transition, bit|
          destination = transition['new']
          distance = symbol.each_with_index.count do |received, index|
            !received.nil? && transition['out'][index].to_i != received
          end
          candidate = metric + distance
          old = survivors[destination]
          survivors[destination] = [candidate, state, bit] if old.nil? || candidate < old[0]
        end
      end
      history << survivors
      metrics = survivors.transform_values(&:first)
    end
    state = metrics.min_by { |_key, metric| metric }.first
    history.reverse.map do |survivors|
      _metric, state, bit = survivors.fetch(state)
      bit
    end.reverse
  end

  private

  def puncture_pattern(matrix)
    unless matrix.is_a?(Array) && matrix.size == gen_num && matrix.all? { |row| row.is_a?(Array) }
      raise ArgumentError, 'puncture matrix must have one row per generator'
    end
    rows = matrix.map { |row| self.class.convert(row) }
    unless rows.first.size.positive? && rows.all? { |row| row.size == rows.first.size }
      raise ArgumentError, 'puncture matrix must be nonempty and rectangular'
    end
    pattern = rows.transpose.flatten
    raise ArgumentError, 'puncture matrix must retain at least one bit' unless pattern.include?(1)
    pattern
  end
end
