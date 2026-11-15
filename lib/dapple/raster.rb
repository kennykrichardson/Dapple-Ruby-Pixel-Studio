# frozen_string_literal: true

module Dapple
  # Pure rasterization helpers. Kept independent of Ruby2D for easy testing.
  module Raster
    module_function

    def line(x0, y0, x1, y1)
      dx = (x1 - x0).abs
      sx = x0 < x1 ? 1 : -1
      dy = -(y1 - y0).abs
      sy = y0 < y1 ? 1 : -1
      error = dx + dy
      points = []

      loop do
        points << [x0, y0]
        break if x0 == x1 && y0 == y1

        twice = 2 * error
        if twice >= dy
          error += dy
          x0 += sx
        end
        if twice <= dx
          error += dx
          y0 += sy
        end
      end
      points
    end

    def rectangle(x0, y0, x1, y1, filled: false)
      left, right = [x0, x1].minmax
      top, bottom = [y0, y1].minmax
      return (top..bottom).flat_map { |y| (left..right).map { |x| [x, y] } } if filled

      points = []
      (left..right).each { |x| points << [x, top] << [x, bottom] }
      (top..bottom).each { |y| points << [left, y] << [right, y] }
      points.uniq
    end

    def ellipse(x0, y0, x1, y1, filled: false)
      left, right = [x0, x1].minmax
      top, bottom = [y0, y1].minmax
      rx = (right - left) / 2.0
      ry = (bottom - top) / 2.0
      cx = (left + right) / 2.0
      cy = (top + bottom) / 2.0
      return [[cx.round, cy.round]] if rx.zero? && ry.zero?

      points = []
      (top..bottom).each do |y|
        (left..right).each do |x|
          dx = rx.zero? ? (x == cx.round ? 0.0 : Float::INFINITY) : ((x - cx) / rx)**2
          dy = ry.zero? ? (y == cy.round ? 0.0 : Float::INFINITY) : ((y - cy) / ry)**2
          value = dx + dy
          if filled ? value <= 1.0 : value.between?(0.78, 1.25)
            points << [x, y]
          end
        end
      end
      points
    end

    def clip(points, width, height)
      points.uniq.select { |x, y| x >= 0 && y >= 0 && x < width && y < height }
    end
  end
end
