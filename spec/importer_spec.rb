# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/dapple'

class ImporterSpec < Minitest::Test
  def test_png_import_when_chunky_png_is_installed
    begin
      require 'chunky_png'
    rescue LoadError
      skip 'chunky_png is installed by bundle install in the full app environment'
    end
    require 'tmpdir'
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'source.png')
      image = ChunkyPNG::Image.new(2, 2, ChunkyPNG::Color::TRANSPARENT)
      image[0, 0] = ChunkyPNG::Color.from_hex('#FF0000')
      image.save(path)
      pixels = Dapple::ImageImporter.pixels(path, width: 4, height: 4,
                                            palette: ['#FF0000', '#0000FF'], quantize: true)
      assert_equal 4, pixels.length
      assert_equal 4, pixels.first.length
      assert_equal '#FF0000', pixels[0][0]
      assert_nil pixels[3][3]
    end
  end
end
