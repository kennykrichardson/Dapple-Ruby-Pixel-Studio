# frozen_string_literal: true

module Dapple
  module ImageImporter
    module_function

    # Imports a PNG, scales it to the document dimensions using nearest-neighbor
    # sampling, and optionally quantizes opaque pixels to the active palette.
    def pixels(path, width:, height:, palette: nil, quantize: true)
      require 'chunky_png'
      image = ChunkyPNG::Image.from_file(path)
      palette = Array(palette)
      raise ArgumentError, 'a palette is required when quantize is enabled' if quantize && palette.empty?

      Array.new(height) do |y|
        source_y = [((y + 0.5) * image.height / height).floor, image.height - 1].min
        Array.new(width) do |x|
          source_x = [((x + 0.5) * image.width / width).floor, image.width - 1].min
          value = image[source_x, source_y]
          alpha = ChunkyPNG::Color.a(value)
          next nil if alpha < 128

          hex = format('#%02X%02X%02X', ChunkyPNG::Color.r(value), ChunkyPNG::Color.g(value), ChunkyPNG::Color.b(value))
          quantize ? Palettes.nearest(hex, palette) : hex
        end
      end
    rescue ChunkyPNG::Exception => error
      raise ArgumentError, "could not import PNG: #{error.message}"
    end
  end
end
