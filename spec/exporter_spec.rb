# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/dapple/document'
require_relative '../lib/dapple/exporter'

class ExporterSpec < Minitest::Test
  def test_rejects_invalid_scale
    document = Dapple::Document.new(width: 2, height: 2)
    assert_raises(ArgumentError) { Dapple::Exporter.export(document, 'unused.png', scale: 0) }
  end

  def test_png_export_when_chunky_png_is_installed
    begin
      require 'chunky_png'
    rescue LoadError
      skip 'chunky_png is installed by bundle install in the full app environment'
    end
    require 'tmpdir'
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'pixel.png')
      document = Dapple::Document.new(width: 2, height: 2)
      document.set_pixel(1, 1, '#FF0000')
      Dapple::Exporter.export(document, path, scale: 4)
      image = ChunkyPNG::Image.from_file(path)
      assert_equal 8, image.width
      assert_equal 8, image.height
      assert_equal ChunkyPNG::Color::TRANSPARENT, image[0, 0]
    end
  end
end
