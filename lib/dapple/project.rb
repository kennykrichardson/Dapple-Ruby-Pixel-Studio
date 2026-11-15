# frozen_string_literal: true

require 'json'
require 'time'
require 'fileutils'

module Dapple
  module Project
    FORMAT_VERSION = 1
    module_function

    def save(path, document:, palette_name:, palette:, algorithm:, params:, seed:)
      payload = {
        'format' => 'dapple-project',
        'version' => FORMAT_VERSION,
        'width' => document.width,
        'height' => document.height,
        'pixels' => document.to_a,
        'palette_name' => palette_name,
        'palette' => palette,
        'generator' => algorithm.to_s,
        'params' => params.respond_to?(:to_h) ? params.to_h : params,
        'seed' => Integer(seed),
        'saved_at' => Time.now.utc.iso8601
      }
      FileUtils.mkdir_p(File.dirname(File.expand_path(path)))
      File.write(path, JSON.pretty_generate(payload))
      path
    end

    def load(path)
      data = JSON.parse(File.read(path))
      raise ArgumentError, 'not a Dapple project file' unless data['format'] == 'dapple-project'
      raise ArgumentError, 'unsupported Dapple project version' unless data['version'] == FORMAT_VERSION
      width = Integer(data.fetch('width'))
      height = Integer(data.fetch('height'))
      document = Document.new(width: width, height: height)
      document.replace!(data.fetch('pixels'))
      raw_palette = data.fetch('palette')
      raise ArgumentError, 'project palette must be an array' unless raw_palette.is_a?(Array)
      raise ArgumentError, 'project palette must contain 1–32 colors' unless raw_palette.length.between?(1, 32)
      palette = raw_palette.map { |color| Palettes.normalize(color) }
      raw_params = data.fetch('params', {})
      raise ArgumentError, 'project parameters must be an object' unless raw_params.is_a?(Hash)
      dna = PatternDNA.new(**raw_params.transform_keys(&:to_sym))
      {
        document: document,
        palette_name: data.fetch('palette_name', 'Custom'),
        palette: palette,
        algorithm: data.fetch('generator', 'noise').to_sym,
        params: dna,
        seed: Integer(data.fetch('seed', 0))
      }
    rescue JSON::ParserError, KeyError, TypeError, NoMethodError, ArgumentError => error
      raise error if error.message.start_with?('not a Dapple', 'unsupported Dapple', 'project palette', 'project parameters')
      raise ArgumentError, "invalid Dapple project: #{error.message}"
    end

    def autosave_path
      File.join(Dir.home, '.dapple', 'autosave.dapple')
    end
  end
end
