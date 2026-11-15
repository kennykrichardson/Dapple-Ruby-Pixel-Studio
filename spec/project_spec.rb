# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/dapple'

class ProjectSpec < Minitest::Test
  def test_project_round_trip
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'test.dapple')
      document = Dapple::Document.new(width: 3, height: 2)
      document.set_pixel(2, 1, '#ABCDEF')
      dna = Dapple::PatternDNA.new(octaves: 3, symmetry_seeds: 55)
      Dapple::Project.save(path, document: document, palette_name: 'Ocean',
                           palette: Dapple::Palettes.fetch('Ocean'), algorithm: :terrain,
                           params: dna, seed: 1234)
      loaded = Dapple::Project.load(path)
      assert_equal document.to_a, loaded[:document].to_a
      assert_equal 1234, loaded[:seed]
      assert_equal :terrain, loaded[:algorithm]
      assert_equal 3, loaded[:params][:octaves]
      assert_equal 'Ocean', loaded[:palette_name]
    end
  end
end
