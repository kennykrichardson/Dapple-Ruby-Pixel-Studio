# frozen_string_literal: true

module Dapple
  module Palettes
    THEMES = {
      'Moss' => %w[#182A26 #315447 #5D8062 #A4B878 #D7D7A2 #F0E6C8],
      'Sunset' => %w[#242447 #49406B #885477 #D46B68 #F2A66A #F6D58A],
      'Ocean' => %w[#142B3B #1E5263 #27858A #62B6A8 #A6D9B5 #E1EBC5],
      'Candy' => %w[#39264A #744C85 #D66FA3 #F5A6B8 #F8D4A5 #FFF0D1],
      'Arcade' => %w[#171738 #343A8A #2367A8 #31B5A4 #A1E55A #FFE66D],
      'Neon' => %w[#171521 #522B72 #A13D9B #EF4770 #FF9C42 #E5F66B],
      'Earth' => %w[#34251F #674536 #A66B45 #C99558 #E2C58B #F1E6C5],
      'Mono' => %w[#171717 #3B3B3B #666666 #999999 #C7C7C7 #F2F2F2]
    }.freeze

    module_function

    def names = THEMES.keys
    def fetch(name) = THEMES.fetch(name)

    def gradient(start_hex, end_hex, steps = 6)
      raise ArgumentError, 'steps must be between 2 and 32' unless steps.is_a?(Integer) && steps.between?(2, 32)
      start_rgb = rgb(start_hex)
      end_rgb = rgb(end_hex)
      Array.new(steps) do |index|
        ratio = index.to_f / (steps - 1)
        channels = start_rgb.zip(end_rgb).map { |a, b| (a + ((b - a) * ratio)).round }
        format('#%02X%02X%02X', *channels)
      end
    end

    def import(path)
      extension = File.extname(path).downcase
      colors = case extension
               when '.gpl'
                 File.readlines(path).filter_map do |line|
                   match = line.match(/^\s*(\d+)\s+(\d+)\s+(\d+)\s+/)
                   format('#%02X%02X%02X', *match.captures.map(&:to_i)) if match
                 end
               when '.json'
                 require 'json'
                 data = JSON.parse(File.read(path))
                 data.is_a?(Hash) ? data.fetch('colors') : data
               else
                 raise ArgumentError, 'palette import supports .gpl and .json files'
               end
      normalized = colors.map { |color| normalize(color) }.uniq
      raise ArgumentError, 'palette file contains no usable colors' if normalized.empty?

      normalized.take(32)
    end

    def nearest(color, palette)
      source = rgb(color)
      palette.min_by do |candidate|
        target = rgb(candidate)
        source.zip(target).sum { |a, b| (a - b)**2 }
      end
    end

    def rgb(hex)
      value = normalize(hex)
      [value[1..2], value[3..4], value[5..6]].map { |part| part.to_i(16) }
    end

    def normalize(color)
      value = color.to_s.strip
      value = "##{value}" unless value.start_with?('#')
      raise ArgumentError, "invalid color: #{color}" unless value.match?(/\A#[0-9a-fA-F]{6}\z/)

      value.upcase
    end
  end
end
