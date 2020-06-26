# frozen_string_literal: true

# Implements convolutional codes as a class.
class Conv
  def initialize(const, gen)
    @const   = const
    @gen     = gen
    @gen_num = @gen.size
  end

  attr_reader :const, :gen, :gen_num

  def self.convert(word)
    word.is_a?(String) ? word.chars.map(&:to_i) : word
  end

  def self.product(arr, oth)
    arr, oth = [arr, oth].map { |k| Conv.convert(k) }
    (0...arr.size).map { |k| arr[k] * oth[k] }
                  .sum % 2
  end

  def self.distance(word, other)
    word, other = [word, other].map { |k| Conv.convert(k) }
    (0...word.size).filter { |k| word[k] != other[k] }
                   .size
  end

  def output(word)
    word = Conv.convert(word)
    @gen.values.map { |g| Conv.product(g, word) }
        .flatten
  end

  def state_mach
    max = 2**(@const - 1)
    h = (0...max).map do |k|
      k = (max + k).to_s(2)[1..-1]
      instruct = lambda do |x|
        x = "#{x}#{k}"
        { 'new' => x[0...-1], 'out' => output(x).join }
      end
      [k, [0, 1].map { |x| instruct[x] }]
    end
    h.to_h
  end

  def next_path(path, word)
    x, y, z = path
    value   = ->(n, s) { state_mach[y][n][s] }
    choice  = lambda do |n|
      ["#{x}#{n}", value[n, 'new'], z + Conv.distance(value[n, 'out'], word)]
    end
    [choice[0], choice[1]]
  end

  def minimize(paths)
    paths = paths.flatten(1)
    last = paths.map { |k| k[1] }
                .uniq
    smallest = lambda do |k|
      paths.filter { |x| x[1] == k }
           .min_by { |y| y[-1] }
    end
    paths.size != last.size ? paths = last.map { |k| smallest[k] } : paths
  end

  def encode(word)
    word = word.reverse + [0] * (@const - 1)
    (word.size - const).downto(0)
                       .map { |k| output(word[k...(k + const)]) }
                       .flatten
  end

  def decode(word)
    paths = [['', '00', 0]]
    (0..(word.size / @gen_num - 1)).each do |n|
      num   = n * @gen_num
      paths = paths.map { |k| next_path(k, word[num..num + @gen_num]) }
      paths = minimize(paths)
    end
    Conv.convert(paths.min_by { |k| k[-1] }[0])
  end
end
