# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/dapple/palettes'
require_relative '../lib/dapple/pattern_dna'
require_relative '../lib/dapple/generators'

class GeneratorsSpec < Minitest::Test
  PALETTE = %w[#111111 #444444 #888888 #CCCCCC #EEEEEE #FFFFFF].freeze

  def test_smooth_noise_is_deterministic_and_well_shaped
    first = Dapple::Generators.noise(width: 12, height: 8, palette: PALETTE, rng: Random.new(7))
    second = Dapple::Generators.noise(width: 12, height: 8, palette: PALETTE, rng: Random.new(7))
    assert_equal first, second
    assert_equal 8, first.length
    assert_equal 12, first.first.length
  end

  def test_radial_symmetry_is_deterministic
    first = Dapple::Generators.symmetry(width: 21, height: 21, palette: PALETTE,
                                         rng: Random.new(11), seeds: 20, order: 4)
    second = Dapple::Generators.symmetry(width: 21, height: 21, palette: PALETTE,
                                          rng: Random.new(11), seeds: 20, order: 4)
    assert_equal first, second
    assert_equal 21, first.length
    21.times do |y|
      21.times do |x|
        if first[y][x].nil?
          assert_nil first[x][20 - y]
        else
          assert_equal first[y][x], first[x][20 - y]
        end
      end
    end
  end

  def test_terrain_uses_sixth_palette_color_and_is_deterministic
    first = Dapple::Generators.terrain(width: 32, height: 18, palette: PALETTE, rng: Random.new(3))
    second = Dapple::Generators.terrain(width: 32, height: 18, palette: PALETTE, rng: Random.new(3))
    assert_equal first, second
    assert_equal 18, first.length
    assert_equal 32, first.first.length
    assert_includes first.flatten, PALETTE[5]
    assert first.flatten.compact.all? { |color| PALETTE.include?(color) }
  end

  def test_all_algorithms_produce_requested_dimensions
    %i[noise symmetry terrain cellular bayer].each do |algorithm|
      pixels = Dapple::Generators.generate(algorithm: algorithm, width: 24, height: 16,
                                            palette: PALETTE, seed: 42)
      assert_equal 16, pixels.length, algorithm
      assert pixels.all? { |row| row.length == 24 }, algorithm
    end
  end

  def test_dna_mutation_is_reproducible
    dna = Dapple::PatternDNA.new
    first = dna.mutate(rng: Random.new(99)).to_h
    second = dna.mutate(rng: Random.new(99)).to_h
    assert_equal first, second
    refute_equal dna.to_h, first
  end

  def test_palette_gradient_has_requested_steps
    gradient = Dapple::Palettes.gradient('#000000', '#FFFFFF', 6)
    assert_equal 6, gradient.length
    assert_equal '#000000', gradient.first
    assert_equal '#FFFFFF', gradient.last
  end
end
