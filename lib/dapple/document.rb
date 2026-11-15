# frozen_string_literal: true

module Dapple
  # Pixel storage with no dependency on the graphical runtime.
  class Document
    attr_reader :width, :height

    def initialize(width: 48, height: 48)
      raise ArgumentError, 'width and height must be positive' unless width.is_a?(Integer) && height.is_a?(Integer) && width.positive? && height.positive?
      raise ArgumentError, 'canvas dimensions cannot exceed 256 × 256' if width > 256 || height > 256

      @width = width
      @height = height
      clear
    end

    def pixel_at(x, y)
      return nil unless in_bounds?(x, y)

      @pixels[y][x]
    end

    def set_pixel(x, y, color)
      return false unless in_bounds?(x, y)
      return false if @pixels[y][x] == color

      @pixels[y][x] = color
      true
    end

    def paint(x, y, color, brush_size: 1)
      raise ArgumentError, 'brush_size must be positive' unless brush_size.is_a?(Integer) && brush_size.positive?

      offset = (brush_size - 1) / 2
      changed = []
      brush_size.times do |dy|
        brush_size.times do |dx|
          px = x + dx - offset
          py = y + dy - offset
          changed << [px, py] if set_pixel(px, py, color)
        end
      end
      changed
    end

    def clear
      @pixels = Array.new(height) { Array.new(width) }
      self
    end

    def replace!(pixels)
      valid = pixels.is_a?(Array) && pixels.length == height &&
              pixels.all? { |row| row.is_a?(Array) && row.length == width && row.all? { |color| color.nil? || valid_color?(color) } }
      raise ArgumentError, 'replacement pixels must match document dimensions and contain hex colors or nil' unless valid

      @pixels = pixels.map(&:dup)
      self
    end

    def resize!(new_width, new_height, preserve: true)
      unless new_width.is_a?(Integer) && new_height.is_a?(Integer) && new_width.positive? && new_height.positive? && new_width <= 256 && new_height <= 256
        raise ArgumentError, 'canvas dimensions must be between 1 and 256'
      end
      replacement = Array.new(new_height) { Array.new(new_width) }
      if preserve
        [height, new_height].min.times do |y|
          [width, new_width].min.times { |x| replacement[y][x] = @pixels[y][x] }
        end
      end
      @width = new_width
      @height = new_height
      replace!(replacement)
    end

    def to_a
      @pixels.map(&:dup)
    end

    def each_pixel
      return enum_for(:each_pixel) unless block_given?

      height.times do |y|
        width.times do |x|
          yield x, y, @pixels[y][x]
        end
      end
    end

    def painted_count
      @pixels.sum { |row| row.count { |pixel| !pixel.nil? } }
    end

    def ==(other)
      other.is_a?(Document) && width == other.width && height == other.height && @pixels == other.to_a
    end

    private

    def in_bounds?(x, y)
      x.is_a?(Integer) && y.is_a?(Integer) && x >= 0 && y >= 0 && x < width && y < height
    end

    def valid_color?(color)
      color.is_a?(String) && color.match?(/\A#[0-9A-Fa-f]{6}\z/)
    end
  end
end
