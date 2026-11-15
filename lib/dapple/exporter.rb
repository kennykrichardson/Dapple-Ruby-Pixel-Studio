# frozen_string_literal: true

require 'fileutils'
module Dapple
  module Exporter
    module_function

    def export(document, path, scale: 8)
      raise ArgumentError, 'scale must be between 1 and 64' unless scale.is_a?(Integer) && scale.between?(1, 64)
      require 'chunky_png'

      image = ChunkyPNG::Image.new(document.width * scale, document.height * scale,
                                   ChunkyPNG::Color::TRANSPARENT)
      document.each_pixel do |x, y, hex|
        next if hex.nil?
        color = ChunkyPNG::Color.from_hex(hex)
        (y * scale).upto((y + 1) * scale - 1) do |py|
          (x * scale).upto((x + 1) * scale - 1) { |px| image[px, py] = color }
        end
      end
      FileUtils.mkdir_p(File.dirname(File.expand_path(path)))
      image.save(path)
      path
    end
  end
end
