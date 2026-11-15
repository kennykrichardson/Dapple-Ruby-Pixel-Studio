# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/dapple/raster'

class RasterSpec < Minitest::Test
  def test_bresenham_line_includes_both_endpoints
    points = Dapple::Raster.line(0, 0, 4, 2)
    assert_equal [0, 0], points.first
    assert_equal [4, 2], points.last
    assert_equal points.uniq, points
  end

  def test_rectangle_outline_and_fill
    outline = Dapple::Raster.rectangle(1, 1, 3, 3)
    filled = Dapple::Raster.rectangle(1, 1, 3, 3, filled: true)
    assert_equal 8, outline.length
    assert_equal 9, filled.length
  end

  def test_ellipse_is_clipped_to_canvas
    points = Dapple::Raster.ellipse(-5, -5, 8, 8)
    assert points.all? { |x, y| x.between?(-5, 8) && y.between?(-5, 8) }
    clipped = Dapple::Raster.clip(points, 4, 4)
    assert clipped.all? { |x, y| x.between?(0, 3) && y.between?(0, 3) }
  end
end
