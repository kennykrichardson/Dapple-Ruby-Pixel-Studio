# frozen_string_literal: true

require_relative 'pattern_dna'

module Dapple
  # Pure, seeded generators. They return a matrix and never mutate a Document.
  module Generators
    module_function

    def generate(algorithm:, width:, height:, palette:, seed: 0, params: {})
      dna = params.is_a?(PatternDNA) ? params : PatternDNA.new(**params.transform_keys(&:to_sym))
      rng = Random.new(Integer(seed))
      case algorithm.to_sym
      when :noise
        noise(width: width, height: height, palette: palette, rng: rng,
              density: dna[:noise_density], octaves: dna[:octaves], persistence: dna[:persistence])
      when :symmetry, :symmetry4, :symmetry8
        order = algorithm.to_sym == :symmetry4 ? 4 : (algorithm.to_sym == :symmetry8 ? 8 : dna[:symmetry_order])
        symmetry(width: width, height: height, palette: palette, rng: rng,
                 seeds: dna[:symmetry_seeds], order: order)
      when :terrain
        terrain(width: width, height: height, palette: palette, rng: rng,
                roughness: dna[:terrain_roughness], horizon: dna[:terrain_horizon])
      when :cellular, :automata
        cellular(width: width, height: height, palette: palette, rng: rng,
                 density: dna[:cellular_density], steps: dna[:cellular_steps])
      when :bayer, :dither
        bayer(width: width, height: height, palette: palette, density: dna[:bayer_density])
      else
        raise ArgumentError, "unknown generator: #{algorithm}"
      end
    end

    def noise(width:, height:, palette:, rng: Random.new, density: 0.78, octaves: 4, persistence: 0.55)
      validate!(width, height, palette)
      octaves = [[Integer(octaves), 1].max, 8].min
      values = Array.new(height) { Array.new(width, 0.0) }
      total_amplitude = 0.0
      amplitude = 1.0

      octaves.times do |octave|
        cells = 2**octave
        lattice = Array.new(cells + 1) { Array.new(cells + 1) { rng.rand } }
        height.times do |y|
          width.times do |x|
            gx = (x.to_f / [width - 1, 1].max) * cells
            gy = (y.to_f / [height - 1, 1].max) * cells
            ix = [gx.floor, cells - 1].min
            iy = [gy.floor, cells - 1].min
            fx = smoothstep(gx - ix)
            fy = smoothstep(gy - iy)
            top = lerp(lattice[iy][ix], lattice[iy][ix + 1], fx)
            bottom = lerp(lattice[iy + 1][ix], lattice[iy + 1][ix + 1], fx)
            values[y][x] += lerp(top, bottom, fy) * amplitude
          end
        end
        total_amplitude += amplitude
        amplitude *= persistence
      end

      threshold = 1.0 - density
      values.map do |row|
        row.map do |value|
          normalized = value / total_amplitude
          next nil if normalized < threshold
          index = [[(normalized * palette.length).floor, 0].max, palette.length - 1].min
          palette[index]
        end
      end
    end

    def symmetry(width:, height:, palette:, rng: Random.new, seeds: 42, order: 4)
      validate!(width, height, palette)
      raise ArgumentError, 'symmetry order must be 4 or 8' unless [4, 8].include?(order)
      pixels = blank(width, height)
      center_x = (width - 1) / 2.0
      center_y = (height - 1) / 2.0
      seeds.times do
        x = rng.rand(width)
        y = rng.rand(height)
        color = palette.sample(random: rng)
        radius = rng.rand(0..2)
        (-radius..radius).each do |dy|
          (-radius..radius).each do |dx|
            next if dx * dx + dy * dy > radius * radius + 1
            px = x + dx
            py = y + dy
            replicate_rotation(pixels, px, py, center_x, center_y, color, order)
          end
        end
      end
      pixels
    end

    def terrain(width:, height:, palette:, rng: Random.new, roughness: 0.62, horizon: 0.58)
      validate!(width, height, palette)
      colors = palette.length >= 6 ? palette.first(6) : palette.cycle.take(6)
      line = Array.new(width, height * horizon)
      line[0] = height * horizon + rng.rand(-height * 0.04..height * 0.04)
      line[-1] = height * horizon + rng.rand(-height * 0.04..height * 0.04) if width > 1
      segment = width - 1
      displacement = [height * roughness * 0.24, 1.0].max
      while segment > 1
        (0...(width - 1)).step(segment) do |left|
          right = [left + segment, width - 1].min
          middle = left + (right - left) / 2
          next if middle == left || middle == right
          average = (line[left] + line[right]) / 2.0
          line[middle] = average + rng.rand(-displacement..displacement)
        end
        segment /= 2
        displacement *= 0.56
      end
      line.each_index do |x|
        line[x] ||= line[[x - 1, 0].max]
        line[x] = [[line[x], height * 0.30].max, height * 0.82].min
      end
      smooth = line.each_index.map do |x|
        neighbors = line[[x - 1, 0].max..[x + 1, width - 1].min]
        neighbors.sum / neighbors.length
      end

      pixels = Array.new(height) { Array.new(width, colors[0]) }
      width.times do |x|
        height.times do |y|
          depth = y - smooth[x]
          pixels[y][x] = if depth < -height * 0.05
                           colors[0]
                         elsif depth < height * 0.025
                           colors[1]
                         elsif depth < height * 0.12
                           colors[2]
                         elsif depth < height * 0.24
                           colors[3]
                         elsif depth < height * 0.38
                           colors[4]
                         else
                           colors[5]
                         end
        end
      end

      # Little sky details make the terrain read as a scene, not a noisy horizon.
      sun_x = rng.rand((width * 0.18).to_i...[width * 0.82, 1].max.to_i)
      sun_y = rng.rand((height * 0.08).to_i...[height * 0.30, 1].max.to_i)
      sun_radius = [[height / 10, 2].max, 9].min
      (-sun_radius..sun_radius).each do |dy|
        (-sun_radius..sun_radius).each do |dx|
          next if dx * dx + dy * dy > sun_radius * sun_radius
          sx = sun_x + dx
          sy = sun_y + dy
          pixels[sy][sx] = colors[5] if sx.between?(0, width - 1) && sy.between?(0, height - 1)
        end
      end
      star_count = [[(width * height / 180.0).round, 3].max, 80].min
      star_count.times do
        sx = rng.rand(width)
        sy = rng.rand([[height * 0.42, 1].max.to_i, height - 1].min)
        pixels[sy][sx] = colors[5] if sy < smooth[sx] - sun_radius
      end
      pixels
    end

    def cellular(width:, height:, palette:, rng: Random.new, density: 0.46, steps: 4)
      validate!(width, height, palette)
      alive = Array.new(height) { Array.new(width) { rng.rand < density } }
      Integer(steps).times do
        alive = Array.new(height) do |y|
          Array.new(width) do |x|
            neighbors = 0
            (-1..1).each do |dy|
              (-1..1).each do |dx|
                next if dx.zero? && dy.zero?
                nx = x + dx
                ny = y + dy
                neighbors += 1 if nx.between?(0, width - 1) && ny.between?(0, height - 1) && alive[ny][nx]
              end
            end
            neighbors >= 5 || (alive[y][x] && neighbors >= 4)
          end
        end
      end
      colors = Array.new(height) do |y|
        palette[[((y.to_f / [height - 1, 1].max) * (palette.length - 1)).round, palette.length - 1].min]
      end
      Array.new(height) { |y| Array.new(width) { |x| alive[y][x] ? colors[y] : nil } }
    end

    def bayer(width:, height:, palette:, density: 0.52)
      validate!(width, height, palette)
      matrix = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
      Array.new(height) do |y|
        Array.new(width) do |x|
          threshold = (matrix[y % 4][x % 4] + 0.5) / 16.0
          value = ((x.to_f / [width - 1, 1].max) * 0.55) + ((y.to_f / [height - 1, 1].max) * 0.45)
          level = value * density + threshold * (1.0 - density)
          palette[[[(level * palette.length).floor, 0].max, palette.length - 1].min]
        end
      end
    end

    def blank(width, height)
      Array.new(height) { Array.new(width) }
    end

    def validate!(width, height, palette)
      raise ArgumentError, 'width and height must be positive' unless width.positive? && height.positive?
      raise ArgumentError, 'palette must contain at least one color' unless palette.is_a?(Array) && !palette.empty?
    end
    private_class_method :validate!

    def replicate_rotation(pixels, x, y, cx, cy, color, order)
      angle_step = (2.0 * Math::PI) / order
      order.times do |rotation|
        angle = angle_step * rotation
        dx = x - cx
        dy = y - cy
        px = (cx + dx * Math.cos(angle) - dy * Math.sin(angle)).round
        py = (cy + dx * Math.sin(angle) + dy * Math.cos(angle)).round
        pixels[py][px] = color if py.between?(0, pixels.length - 1) && px.between?(0, pixels.first.length - 1)
      end
    end
    private_class_method :replicate_rotation

    def smoothstep(value) = value * value * (3.0 - (2.0 * value))
    def lerp(a, b, ratio) = a + ((b - a) * ratio)
  end

  # Optional Ruby DSL: Dapple::Generator.new { |g| g.algorithm = :terrain; ... }.generate
  class Generator
    attr_accessor :algorithm, :width, :height, :palette, :seed, :params

    def initialize
      @algorithm = :noise
      @width = 48
      @height = 48
      @palette = Palettes.fetch('Sunset')
      @seed = 0
      @params = PatternDNA.new.to_h
      yield self if block_given?
    end

    def generate
      Generators.generate(algorithm: algorithm, width: width, height: height,
                          palette: palette, seed: seed, params: params)
    end
  end
end
