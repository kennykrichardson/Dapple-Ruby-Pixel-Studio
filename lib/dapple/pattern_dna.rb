# frozen_string_literal: true

module Dapple
  # Serializable controls for a procedural composition.
  class PatternDNA
    DEFAULTS = {
      noise_density: 0.78,
      octaves: 4,
      persistence: 0.55,
      symmetry_seeds: 34,
      symmetry_order: 8,
      cellular_density: 0.46,
      cellular_steps: 4,
      terrain_roughness: 0.62,
      terrain_horizon: 0.58,
      bayer_density: 0.52,
      fill_empty_only: false
    }.freeze

    DEFAULTS.each_key { |key| define_method(key) { @values[key] } }

    def initialize(**values)
      normalized = values.transform_keys(&:to_sym)
      unknown = normalized.keys - DEFAULTS.keys
      raise ArgumentError, "unknown Pattern DNA keys: #{unknown.join(', ')}" unless unknown.empty?
      @values = DEFAULTS.merge(normalized)
      validate!
    end

    def [](key) = @values.fetch(key.to_sym)
    def []=(key, value)
      candidate = @values.merge(key.to_sym => value)
      self.class.new(**candidate)
      @values = candidate
      validate!
      value
    end

    def to_h = @values.dup

    def mutate(rng:, strength: 0.12)
      changes = to_h
      changes[:noise_density] = clamp(changes[:noise_density] + rng.rand(-strength..strength), 0.05, 1.0)
      changes[:octaves] = [[changes[:octaves] + rng.rand(-1..1), 1].max, 7].min
      changes[:persistence] = clamp(changes[:persistence] + rng.rand(-strength..strength), 0.2, 0.9)
      changes[:symmetry_seeds] = [[changes[:symmetry_seeds] + rng.rand(-8..8), 1].max, 250].min
      changes[:symmetry_order] = rng.rand < 0.18 ? [4, 8].sample(random: rng) : changes[:symmetry_order]
      changes[:cellular_density] = clamp(changes[:cellular_density] + rng.rand(-strength..strength), 0.1, 0.9)
      changes[:cellular_steps] = [[changes[:cellular_steps] + rng.rand(-1..1), 1].max, 8].min
      changes[:terrain_roughness] = clamp(changes[:terrain_roughness] + rng.rand(-strength..strength), 0.1, 1.0)
      changes[:terrain_horizon] = clamp(changes[:terrain_horizon] + rng.rand(-strength..strength), 0.25, 0.78)
      changes[:bayer_density] = clamp(changes[:bayer_density] + rng.rand(-strength..strength), 0.05, 0.95)
      self.class.new(**changes)
    end

    private

    def validate!
      %i[octaves symmetry_seeds symmetry_order cellular_steps].each do |key|
        raise ArgumentError, "#{key} must be an integer" unless @values[key].is_a?(Integer)
      end
      %i[noise_density persistence cellular_density terrain_roughness terrain_horizon bayer_density].each do |key|
        raise ArgumentError, "#{key} must be numeric" unless @values[key].is_a?(Numeric)
      end
      raise ArgumentError, 'fill_empty_only must be boolean' unless [true, false].include?(@values[:fill_empty_only])
      raise ArgumentError, 'noise_density must be between 0.05 and 1.0' unless @values[:noise_density].between?(0.05, 1.0)
      raise ArgumentError, 'octaves must be between 1 and 7' unless @values[:octaves].between?(1, 7)
      raise ArgumentError, 'persistence must be between 0.2 and 0.9' unless @values[:persistence].between?(0.2, 0.9)
      raise ArgumentError, 'symmetry_seeds must be between 1 and 250' unless @values[:symmetry_seeds].between?(1, 250)
      raise ArgumentError, 'symmetry_order must be 4 or 8' unless [4, 8].include?(@values[:symmetry_order])
      raise ArgumentError, 'cellular_density must be between 0.1 and 0.9' unless @values[:cellular_density].between?(0.1, 0.9)
      raise ArgumentError, 'cellular_steps must be between 1 and 8' unless @values[:cellular_steps].between?(1, 8)
      raise ArgumentError, 'terrain_roughness must be between 0.1 and 1.0' unless @values[:terrain_roughness].between?(0.1, 1.0)
      raise ArgumentError, 'terrain_horizon must be between 0.25 and 0.78' unless @values[:terrain_horizon].between?(0.25, 0.78)
      raise ArgumentError, 'bayer_density must be between 0.05 and 0.95' unless @values[:bayer_density].between?(0.05, 0.95)
    end

    def clamp(value, low, high) = [[value, low].max, high].min
  end
end
