# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/dapple/document'

class DocumentSpec < Minitest::Test
  def test_document_starts_transparent
    document = Dapple::Document.new(width: 4, height: 3)
    assert_nil document.pixel_at(0, 0)
    assert_equal 0, document.painted_count
  end

  def test_paint_respects_bounds_and_brush_size
    document = Dapple::Document.new(width: 4, height: 4)
    changed = document.paint(1, 1, '#FF0000', brush_size: 2)
    assert_equal 4, changed.length
    assert_equal '#FF0000', document.pixel_at(1, 1)
    assert_equal '#FF0000', document.pixel_at(2, 2)
    assert_equal 4, document.painted_count
  end

  def test_identical_paints_are_no_ops
    document = Dapple::Document.new(width: 3, height: 3)
    assert_equal [[1, 1]], document.paint(1, 1, '#FF0000')
    assert_equal [], document.paint(1, 1, '#FF0000')
  end

  def test_brush_clips_at_canvas_edges
    document = Dapple::Document.new(width: 3, height: 3)
    changed = document.paint(0, 0, '#00FF00', brush_size: 3)
    assert_equal 4, changed.length
    assert_equal 4, document.painted_count
  end

  def test_replace_copies_rows
    document = Dapple::Document.new(width: 2, height: 2)
    pixels = [['#111111', nil], [nil, '#222222']]
    document.replace!(pixels)
    pixels[0][0] = '#FFFFFF'
    assert_equal '#111111', document.pixel_at(0, 0)
  end

  def test_rejects_wrong_dimensions_and_invalid_colors
    document = Dapple::Document.new(width: 2, height: 2)
    assert_raises(ArgumentError) { document.replace!([[nil]]) }
    assert_raises(ArgumentError) { document.replace!([['red', nil], [nil, nil]]) }
  end

  def test_resize_preserves_overlap_and_clears_new_area
    document = Dapple::Document.new(width: 2, height: 2)
    document.set_pixel(1, 1, '#ABCDEF')
    document.resize!(3, 3)
    assert_equal '#ABCDEF', document.pixel_at(1, 1)
    assert_nil document.pixel_at(2, 2)
  end

  def test_rejects_canvas_larger_than_supported_limit
    assert_raises(ArgumentError) { Dapple::Document.new(width: 257, height: 2) }
  end
end
