# frozen_string_literal: true

require 'ruby2d'
require 'time'
require 'fileutils'
require_relative '../dapple'
require_relative 'clipboard'
require_relative 'ui/button'

module Dapple
  class Editor
    WINDOW_WIDTH = 1648
    WINDOW_HEIGHT = 930
    LEFT = { x: 12, y: 92, w: 378, h: 824 }.freeze
    MAIN = { x: 400, y: 92, w: 694, h: 824 }.freeze
    RIGHT = { x: 1102, y: 92, w: 534, h: 824 }.freeze
    ARTBOARD_MAX = 640
    CENTER_X = 747
    CENTER_Y = 478
    EVOLUTION_CARD_SIZE = 118
    EVOLUTION_CARD_GAP = 8
    EVOLUTION_THUMB_SIZE = 80

    COLORS = {
      background: '#09090B', header: '#0D0D10', panel: '#111114', panel_soft: '#17171B',
      panel_hover: '#252329', border: '#39363B', border_soft: '#29272C', text: '#F5F0E6',
      muted: '#C7C0B5', dim: '#8D867D', coral: '#D92743', crimson: '#D92743',
      purple: '#E7C46A', gold: '#E7C46A', cyan: '#F5F0E6', cream: '#F5F0E6',
      lime: '#E7C46A', green: '#E7C46A', pink: '#D92743', danger: '#D92743',
      checker_a: '#19191C', checker_b: '#141417', grid: '#28282D', grid_major: '#444047'
    }.freeze

    TOOLS = {
      brush: ['Brush', COLORS[:crimson]], eraser: ['Eraser', COLORS[:cream]],
      fill: ['Fill Bucket', COLORS[:gold]], picker: ['Eyedropper', COLORS[:cream]],
      line: ['Line', COLORS[:gold]], rectangle: ['Rectangle', COLORS[:cream]],
      ellipse: ['Ellipse', COLORS[:gold]], mirror: ['Mirror Paint', COLORS[:cream]]
    }.freeze

    PALETTE_TINTS = Palettes.names.to_h { |name| [name, COLORS[:gold]] }.freeze

    GENE_SLIDERS = {
      density: [:noise_density, 0.05, 1.0, 0.05], octaves: [:octaves, 1, 7, 1],
      seeds: [:symmetry_seeds, 1, 250, 5], roughness: [:terrain_roughness, 0.1, 1.0, 0.05],
      persistence: [:persistence, 0.2, 0.9, 0.05], cellular_density: [:cellular_density, 0.1, 0.9, 0.05],
      cellular_steps: [:cellular_steps, 1, 8, 1], horizon: [:terrain_horizon, 0.25, 0.78, 0.03],
      bayer_density: [:bayer_density, 0.05, 0.95, 0.05]
    }.freeze

    attr_reader :document, :dna, :seed

    def initialize
      @document = Document.new(width: 128, height: 128)
      @history = History.new(limit: 100)
      @palette_name = 'Mono'
      @palette = Palettes.fetch(@palette_name).dup
      @palette_offset = 0
      @selected_color = @palette[3]
      @algorithm = :terrain
      @dna = PatternDNA.new
      @seed = Random.new_seed % 2_147_483_647
      @tool = :brush
      @brush_size = 1
      @symmetry_mode = 1
      @show_grid = true
      @fill_empty_only = false
      @export_scale = 16
      @zoom = 1.0
      @pan_x = 0
      @pan_y = 0
      @status = 'Welcome to Dapple. Make something delightfully strange.'
      @project_name = 'Moonlit Landscape'
      @buttons = {}
      @painting = false
      @last_cell = nil
      @drag_start = nil
      @drag_before = nil
      @drag_changed = {}
      @input_mode = nil
      @input_buffer = +''
      @input_selected = false
      @keys_down = {}
      @evolution = []
      @thumbs = []
      @thumbnail_bounds = []
      @pixel_canvases = {}
      @checker_tiles = []
      @grid_lines = []
      @ghost = nil
      @ghost_visible = false
      @gene_sliders = {}
      @gene_slider_bounds = {}
      @dragging_slider = nil
      @slider_before = nil
      @slider_changed = false
      @seed_edit_original = nil
      @selected_evolution = nil

      window_width, window_height = fitted_window_size
      Ruby2D::Window.set(title: 'Dapple • A Pixel Studio by Kenny Richardson', width: window_width,
                         height: window_height, background: COLORS[:background], fps_cap: 60,
                         resizable: true, viewport_width: WINDOW_WIDTH, viewport_height: WINDOW_HEIGHT,
                         viewport: :stretch, close_on_esc: false)
      build_shell
      build_left_rail
      build_main_workspace
      build_right_rail
      build_canvas
      restored = load_autosave
      if restored
        generate_evolution
      else
        generate(@algorithm, record: false)
      end
      rebuild_canvas_geometry
      render_all_pixels
      update_all_labels
      bind_events
    end

    def self.maximize_native_window
      return unless RUBY_PLATFORM.match?(/mswin|mingw|cygwin/i)

      script = <<~POWERSHELL
        Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public static class DappleWindowNative {
          [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr handle, int command);
        }
        "@
        $app = Get-Process | Where-Object { $_.MainWindowTitle.StartsWith('Dapple') -and $_.MainWindowTitle.Contains('Kenny Richardson') } | Select-Object -First 1
        if ($null -ne $app -and $app.MainWindowHandle -ne [IntPtr]::Zero) {
          [DappleWindowNative]::ShowWindowAsync($app.MainWindowHandle, 3) | Out-Null
        }
      POWERSHELL
      system('powershell.exe', '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-STA', '-Command', script,
             out: File::NULL, err: File::NULL)
    rescue StandardError
      false
    end

    private

    # ----------------------------------------------------------------------
    # Interface composition
    # ----------------------------------------------------------------------
    def build_shell
      build_brand_header
      add_panel(LEFT)
      add_panel(MAIN)
      add_panel(RIGHT)
    end

    def build_brand_header
      Ruby2D::Rectangle.new(x: 0, y: 0, width: WINDOW_WIDTH, height: 82, color: COLORS[:header], z: 1)
      Ruby2D::Rectangle.new(x: 0, y: 80, width: WINDOW_WIDTH, height: 2, color: COLORS[:border], z: 2)
      # Restrained crimson wavework gives the header a bespoke identity without
      # competing with the pixel artwork or the controls.
      4.times do |wave|
        points = (0..32).map do |step|
          x = 590 + step * 34
          y = 54 + (Math.sin((step * 0.42) + (wave * 0.65)) * (7 + wave * 2)) + wave * 3
          [x, y]
        end
        points.each_cons(2) do |a, b|
          Ruby2D::Line.new(x1: a[0], y1: a[1], x2: b[0], y2: b[1],
                           color: wave.even? ? '#51202B' : '#351820', stroke_width: 1.4, z: 3)
        end
      end
      # Pixel-mark logo.
      [[54, 39], [66, 27], [66, 39], [66, 51], [78, 39]].each do |x, y|
        Ruby2D::Rectangle.new(x: x, y: y, width: 9, height: 9, color: COLORS[:crimson], z: 5)
      end
      add_text('Dapple', 100, 23, size: 31, color: COLORS[:text], z: 6)
      Ruby2D::Rectangle.new(x: 242, y: 18, width: 1, height: 46, color: COLORS[:border], z: 5)
      add_text('• A Pixel Studio by Kenny Richardson', 266, 34, size: 17, color: COLORS[:muted], z: 6)
    end

    def add_panel(area)
      Ruby2D::Rectangle.new(x: area[:x], y: area[:y], width: area[:w], height: area[:h],
                            color: COLORS[:panel], z: 1)
      Ruby2D::Rectangle.new(x: area[:x], y: area[:y], width: area[:w], height: 2,
                            color: COLORS[:border], z: 2)
    end

    def build_left_rail
      x = 34
      add_text('TOOLS', x, 108, size: 17, color: COLORS[:text])
      add_text('Pick a tool. Cause a little chaos.', x, 132, size: 12, color: COLORS[:muted])
      tool_ids = TOOLS.keys
      tool_ids.each_with_index do |id, index|
        col = index % 2
        row = index / 2
        add_button(id, TOOLS[id][0], x + col * 180, 158 + row * 42, 166, 34,
                   tint: TOOLS[id][1])
      end

      add_divider(34, 337, 334)
      add_text('BRUSH FOOTPRINT', 34, 354, size: 14, color: COLORS[:text])
      [1, 2, 3, 4, 6, 8].each_with_index do |size, index|
        add_button("brush_#{size}".to_sym, "#{size} px", 34 + index * 56, 382, 48, 34,
                   tint: COLORS[:gold])
      end

      add_text('SYMMETRY ENGINE', 34, 436, size: 14, color: COLORS[:text])
      add_button(:symmetry_off, 'Off', 34, 462, 104, 36, tint: COLORS[:cream])
      add_button(:symmetry_4, '4-Fold', 149, 462, 104, 36, tint: COLORS[:gold])
      add_button(:symmetry_8, '8-Fold', 264, 462, 104, 36, tint: COLORS[:crimson])

      add_divider(34, 514, 334)
      add_text('COLOR UNIVERSES', 34, 531, size: 15, color: COLORS[:text])
      Palettes.names.each_with_index do |name, index|
        col = index % 4
        row = index / 4
        palette = Palettes.fetch(name)
        add_button("palette_#{name.downcase}".to_sym, name, 34 + col * 86, 558 + row * 80,
                   78, 68, tint: COLORS[:gold], swatches: palette)
      end

      add_divider(34, 724, 334)
      add_text('PALETTE LAB', 34, 741, size: 15, color: COLORS[:text])
      add_button(:hex_color, 'Hex Color', 34, 769, 166, 36, tint: COLORS[:gold])
      add_button(:palette_import, 'Import Palette', 202, 769, 166, 36, tint: COLORS[:cream])
      add_button(:gradient, 'Gradient Ramp', 34, 812, 166, 36, tint: COLORS[:gold])
      add_button(:remap, 'Remap Art', 202, 812, 166, 36, tint: COLORS[:cream])

      add_text('ACTIVE COLORS', 34, 862, size: 12, color: COLORS[:muted])
      @swatches = []
      @swatch_bounds = []
      @current_color_chip = Ruby2D::Rectangle.new(x: 34, y: 863, width: 13, height: 13,
                                                  color: @selected_color, z: 8)
      @current_color_text = add_text(@selected_color, 163, 862, size: 11, color: COLORS[:text])
      add_button(:swatch_prev, '‹', 314, 884, 22, 24, tint: COLORS[:gold])
      add_button(:swatch_next, '›', 342, 884, 22, 24, tint: COLORS[:gold])
      rebuild_swatches
    end

    def build_main_workspace
      add_button(:undo, 'Undo', 420, 104, 76, 34, tint: COLORS[:cream])
      add_button(:redo, 'Redo', 503, 104, 76, 34, tint: COLORS[:cream])
      add_button(:grid_toggle, 'Grid', 588, 104, 78, 34, tint: COLORS[:gold])
      add_text('CANVAS', 681, 112, size: 12, color: COLORS[:dim])
      [32, 48, 64, 96, 128].each_with_index do |size, index|
        add_button("canvas_#{size}".to_sym, size.to_s, 744 + index * 49, 104, 43, 34,
                   tint: COLORS[:gold])
      end
      add_button(:zoom_out, '−', 1000, 104, 34, 34, tint: COLORS[:cream])
      @zoom_text = add_text('100%', 1038, 113, size: 12, color: COLORS[:text])
      add_button(:zoom_in, '+', 1060, 104, 28, 34, tint: COLORS[:cream])

      @document_name = add_text(@project_name, 420, 852, size: 13, color: COLORS[:muted])
      @status_text = add_text(@status, 420, 879, size: 11, color: COLORS[:dim])
      @count_text = add_text('0 PIXELS', 973, 879, size: 12, color: COLORS[:gold])
      @dimension_text = add_text('48 × 48', 905, 852, size: 12, color: COLORS[:text])
    end

    def build_right_rail
      x = 1122
      add_text('PROJECT VAULT', x, 100, size: 17, color: COLORS[:text])
      action_width = 119
      action_gap = 8
      [[:import_png, 'Import PNG'], [:save_project, 'Save .Dapple'],
       [:load_project, 'Load Project'], [:export_png, 'Export PNG']].each_with_index do |(id, label), index|
        add_button(id, label, x + index * (action_width + action_gap), 126,
                   action_width, 30, primary: id == :export_png,
                   tint: id == :export_png ? COLORS[:crimson] : COLORS[:gold])
      end
      add_text('Autosave is automatic  ·  Exports go to /exports', x, 163, size: 10, color: COLORS[:dim])
      add_divider(x, 184, 502)

      add_text('PATTERN DNA LAB', x, 194, size: 17, color: COLORS[:text])
      add_text('Change a gene. The composition regenerates.', x, 216, size: 11, color: COLORS[:muted])
      add_text('ALGORITHM', x, 235, size: 10, color: COLORS[:dim])
      [[:algorithm_noise, 'Noise'], [:algorithm_symmetry, 'Symmetry'], [:algorithm_terrain, 'Terrain'],
       [:algorithm_cellular, 'Cellular'], [:algorithm_bayer, 'Bayer'], [:fill_empty, 'Fill Empty Only']].each_with_index do |(id, label), index|
        col = index % 3
        row = index / 3
        add_button(id, label, x + col * 168, 249 + row * 31, 158, 27,
                   tint: id == :fill_empty ? COLORS[:gold] : COLORS[:cream])
      end
      add_divider(x, 312, 502)

      add_text('LIVE GENES', x, 322, size: 14, color: COLORS[:text])
      gene_labels = [
        [:density, 'Noise Density'], [:octaves, 'Noise Octaves'], [:seeds, 'Symmetry Seeds'],
        [:roughness, 'Terrain Roughness'], [:persistence, 'Noise Persistence'],
        [:cellular_density, 'Cellular Density'], [:cellular_steps, 'Cellular Steps'],
        [:horizon, 'Terrain Horizon'], [:bayer_density, 'Bayer Density']
      ]
      gene_labels.each_with_index do |(id, label), index|
        build_gene_control(id, label, x + 12, 340 + index * 13)
      end

      seed_y = 459
      add_text('SEED', x + 2, seed_y + 9, size: 10, color: COLORS[:dim])
      @seed_field_bounds = [1170, seed_y, 154, 30]
      @seed_field_outline = Ruby2D::Rectangle.new(x: 1169, y: seed_y - 1, width: 156, height: 32,
                                                   color: COLORS[:gold], z: 17)
      @seed_field_bg = Ruby2D::Rectangle.new(x: 1170, y: seed_y, width: 154, height: 30,
                                              color: '#19171A', z: 18)
      @seed_text = nil
      render_seed_text
      add_button(:seed_copy, 'Copy', 1332, seed_y, 58, 30, tint: COLORS[:gold])
      add_button(:seed_set, 'Set Seed', 1398, seed_y, 112, 30, primary: true, tint: COLORS[:crimson])
      add_button(:seed_random, 'Roll', 1518, seed_y, 100, 30, tint: COLORS[:gold])

      add_divider(x, 497, 502)
      add_text('EVOLUTION CHAMBER', x, 507, size: 17, color: COLORS[:text])
      add_text('Nine nearby mutations · select art to apply, seed to copy', x, 529, size: 10, color: COLORS[:muted])
      build_evolution_grid
    end

    def build_gene_control(id, label, x, y)
      add_text(label, x, y + 1, size: 10, color: COLORS[:muted])
      track_x = 1284
      track_y = y + 6
      track_width = 248
      track = Ruby2D::Rectangle.new(x: track_x, y: track_y, width: track_width, height: 3,
                                    color: '#343238', z: 9)
      fill = Ruby2D::Rectangle.new(x: track_x, y: track_y, width: 1, height: 3,
                                   color: COLORS[:crimson], z: 10)
      knob = Ruby2D::Circle.new(x: track_x, y: track_y + 1.5, radius: 5,
                                color: COLORS[:gold], z: 11)
      value = add_text('', 1547, y, size: 10, color: COLORS[:text])
      @gene_sliders[id] = { track: track, fill: fill, knob: knob, value: value,
                            x: track_x, y: track_y, width: track_width }
      @gene_slider_bounds[id] = [track_x - 8, y - 2, track_width + 16, 14]
    end

    def build_evolution_grid
      @thumbnail_bounds = []
      @thumbnail_seed_bounds = []
      @thumbs = []
      @thumb_meta = []
      @evolution_card_borders = []

      card_size = EVOLUTION_CARD_SIZE
      gap = EVOLUTION_CARD_GAP
      grid_width = (card_size * 3) + (gap * 2)
      origin_x = 1122 + ((502 - grid_width) / 2.0)
      origin_y = 543

      9.times do |index|
        col = index % 3
        row = index / 3
        x = origin_x + (col * (card_size + gap))
        y = origin_y + (row * (card_size + gap))
        Ruby2D::Rectangle.new(x: x, y: y, width: card_size, height: card_size,
                              color: COLORS[:panel_soft], z: 18)
        border = Ruby2D::Rectangle.new(x: x, y: y, width: card_size, height: card_size,
                                       fill: false, stroke_width: 1,
                                       stroke_color: COLORS[:border], z: 23)
        @evolution_card_borders << border

        thumb_x = x + ((card_size - EVOLUTION_THUMB_SIZE) / 2.0)
        thumb_y = y + 4
        canvas = Ruby2D::Canvas.new(width: EVOLUTION_THUMB_SIZE, height: EVOLUTION_THUMB_SIZE,
                                    x: thumb_x, y: thumb_y, z: 20)
        @thumbs << canvas
        @thumb_meta << [
          add_text('', x + 6, y + 87, size: 9, color: COLORS[:gold], z: 22),
          add_text('', x + 6, y + 101, size: 8, color: COLORS[:muted], z: 22)
        ]
        @thumbnail_seed_bounds << [x + 4, y + 85, card_size - 8, 14]
        @thumbnail_bounds << [x, y, card_size, 85]
      end
    end

    def build_canvas
      rebuild_canvas_geometry
      render_all_pixels
    end

    def rebuild_canvas_geometry
      @checker_tiles.each(&:remove)
      @grid_lines.each(&:remove)
      @pixel_canvases.each_value(&:remove)
      @pixel_canvases.clear
      @checker_tiles = []
      @grid_lines = []

      max_dimension = [@document.width, @document.height].max
      base_cell = ARTBOARD_MAX.to_f / max_dimension
      @cell_size = [[(base_cell * @zoom).round, 2].max, 16].min
      @canvas_width = @document.width * @cell_size
      @canvas_height = @document.height * @cell_size
      @canvas_x = CENTER_X - (@canvas_width / 2.0) + @pan_x
      @canvas_y = CENTER_Y - (@canvas_height / 2.0) + @pan_y

      # Transparency grid uses 4×4 pixel tiles to stay light even at 128².
      tile_pixels = 4
      (0...@document.height).step(tile_pixels) do |y|
        (0...@document.width).step(tile_pixels) do |x|
          w = [tile_pixels, @document.width - x].min * @cell_size
          h = [tile_pixels, @document.height - y].min * @cell_size
          @checker_tiles << Ruby2D::Rectangle.new(
            x: @canvas_x + (x * @cell_size), y: @canvas_y + (y * @cell_size),
            width: w, height: h,
            color: ((x / tile_pixels) + (y / tile_pixels)).even? ? COLORS[:checker_a] : COLORS[:checker_b], z: 3
          )
        end
      end
      @canvas_frame&.remove
      @canvas_frame = Ruby2D::Rectangle.new(x: @canvas_x - 12, y: @canvas_y - 12,
                                            width: @canvas_width + 24, height: @canvas_height + 24,
                                            color: COLORS[:border], z: 2)

      if @show_grid
        (0..@document.width).each do |index|
          major = (index % 8).zero? || index == @document.width
          @grid_lines << Ruby2D::Line.new(
            x1: @canvas_x + (index * @cell_size), y1: @canvas_y,
            x2: @canvas_x + (index * @cell_size), y2: @canvas_y + @canvas_height,
            color: major ? COLORS[:grid_major] : COLORS[:grid], stroke_width: 1, z: 10
          )
        end
        (0..@document.height).each do |index|
          major = (index % 8).zero? || index == @document.height
          @grid_lines << Ruby2D::Line.new(
            x1: @canvas_x, y1: @canvas_y + (index * @cell_size),
            x2: @canvas_x + @canvas_width, y2: @canvas_y + (index * @cell_size),
            color: major ? COLORS[:grid_major] : COLORS[:grid], stroke_width: 1, z: 10
          )
        end
      end
      tile_size = 16
      (0...@document.height).step(tile_size) do |tile_y|
        (0...@document.width).step(tile_size) do |tile_x|
          tile_width = [tile_size, @document.width - tile_x].min
          tile_height = [tile_size, @document.height - tile_y].min
          @pixel_canvases[[tile_x, tile_y]] = Ruby2D::Canvas.new(
            width: tile_width * @cell_size, height: tile_height * @cell_size,
            x: @canvas_x + (tile_x * @cell_size), y: @canvas_y + (tile_y * @cell_size), z: 5
          )
        end
      end
      @ghost ||= Ruby2D::Rectangle.new(x: -100, y: -100, width: 1, height: 1,
                                       color: COLORS[:cyan], z: 14)
      @ghost.opacity = 0.36 if @ghost.respond_to?(:opacity=)
    end

    # ----------------------------------------------------------------------
    # Drawing and incremental rendering
    # ----------------------------------------------------------------------
    def bind_events
      Ruby2D::Window.on :mouse_down do |event|
        next unless left_button?(event)
        handle_mouse_down(event.x, event.y)
      end
      Ruby2D::Window.on :mouse_held do |event|
        if @dragging_slider && left_button?(event)
          update_gene_slider(@dragging_slider, event.x)
        elsif @painting && left_button?(event)
          @tool == :brush || @tool == :eraser || @tool == :mirror ? paint_at(event.x, event.y) : preview_shape(event.x, event.y)
        end
      end
      Ruby2D::Window.on :mouse_up do |event|
        if left_button?(event)
          @pressed_button.pressed = false if @pressed_button
          @pressed_button = nil
          finish_pointer_action
          finish_gene_slider
        end
      end
      Ruby2D::Window.on :mouse_move do |event|
        update_hover(event.x, event.y)
        update_brush_ghost(event.x, event.y)
      end
      Ruby2D::Window.on :key_down do |event|
        key = event.key.to_s.downcase
        @keys_down[key] = true
        if @input_mode
          handle_input_key(shifted_key(key))
        else
          handle_shortcut(event)
        end
      end
      Ruby2D::Window.on :key_up do |event|
        @keys_down.delete(event.key.to_s.downcase)
      end
    end

    def handle_mouse_down(x, y)
      if @input_mode
        return
      end
      if @seed_field_bounds
        sx, sy, sw, sh = @seed_field_bounds
        if x >= sx && x < sx + sw && y >= sy && y < sy + sh
          begin_seed_edit
          return
        end
      end
      slider_id = @gene_slider_bounds.find do |_id, (sx, sy, sw, sh)|
        x >= sx && x <= sx + sw && y >= sy && y <= sy + sh
      end&.first
      if slider_id
        @dragging_slider = slider_id
        @slider_before = snapshot_document
        @slider_changed = false
        update_gene_slider(slider_id, x)
        return
      end
      button = @buttons.values.find { |candidate| candidate.include?(x, y) }
      if button
        @pressed_button.pressed = false if @pressed_button && @pressed_button != button
        @pressed_button = button
        button.pressed = true
        activate_button(button.id)
        return
      end
      swatch = @swatch_bounds.find { |sx, sy, sw, sh, _color| x >= sx && x < sx + sw && y >= sy && y < sy + sh }
      if swatch
        @selected_color = swatch[4]
        rebuild_swatches
        update_all_labels
        return
      end
      seed_variant = @thumbnail_seed_bounds.index do |sx, sy, sw, sh|
        x >= sx && x < sx + sw && y >= sy && y < sy + sh
      end
      if seed_variant
        variant = @evolution[seed_variant]
        copied = variant && Clipboard.copy(variant[:seed].to_s)
        set_status(copied ? "Evolution seed #{variant[:seed]} copied. Paste it into the seed field with Ctrl+V." : 'Clipboard unavailable; select the seed in the main field instead.')
        return
      end
      variant = @thumbnail_bounds.index { |tx, ty, tw, th| x >= tx && x < tx + tw && y >= ty && y < ty + th }
      if variant
        breed_variant(variant)
        return
      end
      cell = canvas_cell_at(x, y)
      return unless cell

      if @tool == :picker
        color = @document.pixel_at(*cell)
        if color
          @selected_color = color
          update_all_labels
          set_status("Picked #{color}.")
        else
          set_status('That pixel is transparent. Nothing to pick.')
        end
        return
      end
      if @tool == :fill
        before = snapshot_document
        changed = flood_fill(*cell, @selected_color)
        render_cells(changed)
        finish_edit(before)
        return
      end
      @painting = true
      @drag_start = cell
      @last_cell = nil
      @drag_changed = {}
      @drag_before = snapshot_document
      if [:brush, :eraser, :mirror].include?(@tool)
        paint_cell(*cell)
      else
        preview_shape(x, y)
      end
    end

    def finish_pointer_action
      return unless @painting
      if [:line, :rectangle, :ellipse].include?(@tool) && @drag_start && @last_cell
        points = case @tool
                 when :line then Raster.line(*@drag_start, *@last_cell)
                 when :rectangle then Raster.rectangle(*@drag_start, *@last_cell)
                 when :ellipse then Raster.ellipse(*@drag_start, *@last_cell)
                 end
        apply_tool_points(points)
      end
      @painting = false
      @last_cell = nil
      @drag_start = nil
      @drag_changed = {}
      finish_edit(@drag_before)
      @drag_before = nil
    end

    def paint_at(x, y)
      cell = canvas_cell_at(x, y)
      unless cell
        @last_cell = nil
        return
      end
      return if cell == @last_cell
      points = @last_cell ? Raster.line(*@last_cell, *cell).drop(1) : [cell]
      apply_tool_points(points)
      @last_cell = cell
    end

    def paint_cell(x, y)
      apply_tool_points([[x, y]])
      @last_cell = [x, y]
    end

    def apply_tool_points(points)
      changed = []
      points.each do |x, y|
        symmetry_points(x, y).each do |sx, sy|
          color = @tool == :eraser ? nil : @selected_color
          result = @document.paint(sx, sy, color, brush_size: @brush_size)
          changed.concat(result)
        end
      end
      changed.uniq.each do |x, y|
        @drag_changed[[x, y]] = true
      end
      render_cells(changed.uniq)
    end

    def symmetry_points(x, y)
      points = if @symmetry_mode == 1
                 [[x, y]]
               else
                 cx = (@document.width - 1) / 2.0
                 cy = (@document.height - 1) / 2.0
                 order = @symmetry_mode == 4 ? 4 : 8
                 order.times.map do |index|
                   angle = (2.0 * Math::PI * index) / order
                   dx = x - cx
                   dy = y - cy
                   [(cx + dx * Math.cos(angle) - dy * Math.sin(angle)).round,
                    (cy + dx * Math.sin(angle) + dy * Math.cos(angle)).round]
                 end
               end
      # Mirror remains active even when radial symmetry is switched off.
      points << [@document.width - 1 - x, y] if @tool == :mirror
      Raster.clip(points, @document.width, @document.height).uniq
    end

    def flood_fill(start_x, start_y, replacement)
      target = @document.pixel_at(start_x, start_y)
      return [] if target == replacement
      queue = [[start_x, start_y]]
      head = 0
      visited = {}
      changed = []
      while head < queue.length
        x, y = queue[head]
        head += 1
        key = [x, y]
        next if visited[key]
        visited[key] = true
        next unless x.between?(0, @document.width - 1) && y.between?(0, @document.height - 1)
        next unless @document.pixel_at(x, y) == target
        @document.set_pixel(x, y, replacement)
        changed << [x, y]
        queue << [x + 1, y] << [x - 1, y] << [x, y + 1] << [x, y - 1]
      end
      changed
    end

    def preview_shape(mouse_x, mouse_y)
      @last_cell = canvas_cell_at(mouse_x, mouse_y)
      update_brush_ghost(mouse_x, mouse_y)
    end

    # Each 16×16 tile is a batched Ruby2D Canvas. A stroke clears and redraws
    # only the tiles touched by changed pixels, rather than rebuilding the artboard.
    def render_cells(cells)
      tile_size = 16
      dirty_tiles = cells.map do |x, y|
        [(x / tile_size) * tile_size, (y / tile_size) * tile_size]
      end.uniq
      dirty_tiles.each { |tile_x, tile_y| render_pixel_tile(tile_x, tile_y) }
      update_all_labels
    end

    def render_pixel_tile(tile_x, tile_y)
      canvas = @pixel_canvases[[tile_x, tile_y]]
      return unless canvas
      canvas.clear
      tile_size = 16
      end_x = [tile_x + tile_size, @document.width].min
      end_y = [tile_y + tile_size, @document.height].min
      (tile_y...end_y).each do |y|
        (tile_x...end_x).each do |x|
          color = @document.pixel_at(x, y)
          next unless color
          canvas.fill_rectangle(
            x: (x - tile_x) * @cell_size, y: (y - tile_y) * @cell_size,
            width: @cell_size, height: @cell_size, color: color
          )
        end
      end
      canvas.update if canvas.respond_to?(:update)
    end

    def render_all_pixels
      @pixel_canvases.each_key { |tile_x, tile_y| render_pixel_tile(tile_x, tile_y) }
      update_all_labels
    end

    def canvas_cell_at(x, y)
      return nil unless x >= @canvas_x && y >= @canvas_y &&
                        x < @canvas_x + @canvas_width && y < @canvas_y + @canvas_height
      [((x - @canvas_x) / @cell_size).floor, ((y - @canvas_y) / @cell_size).floor]
    end

    def update_brush_ghost(mouse_x, mouse_y)
      cell = canvas_cell_at(mouse_x, mouse_y)
      unless cell
        @ghost.x = -100
        @ghost.y = -100
        return
      end
      x, y = cell
      offset = (@brush_size - 1) / 2
      @ghost.x = @canvas_x + ((x - offset) * @cell_size)
      @ghost.y = @canvas_y + ((y - offset) * @cell_size)
      @ghost.width = @brush_size * @cell_size
      @ghost.height = @brush_size * @cell_size
      @ghost.color = @tool == :eraser ? COLORS[:pink] : COLORS[:cyan]
    end

    # ----------------------------------------------------------------------
    # DNA generation and evolution
    # ----------------------------------------------------------------------
    def generate(kind = @algorithm, record: true, before_snapshot: nil, force_replace: false)
      before = (before_snapshot || snapshot_document) if record
      @algorithm = kind.to_sym
      fresh = Generators.generate(algorithm: @algorithm, width: @document.width,
                                  height: @document.height, palette: @palette,
                                  seed: @seed, params: @dna)
      if !force_replace && (@fill_empty_only || @dna[:fill_empty_only])
        current = @document.to_a
        fresh = fresh.each_with_index.map do |row, y|
          row.each_with_index.map { |color, x| current[y][x] || color }
        end
      end
      @document.replace!(fresh)
      @history.commit(before, snapshot_document) if record
      rebuild_canvas_geometry
      render_all_pixels
      generate_evolution
      update_button_states
      set_status("#{@algorithm.to_s.upcase} regenerated from seed #{@seed}.")
      autosave
    rescue StandardError => error
      set_status("Generator error: #{error.message}")
    end

    def generate_evolution
      @selected_evolution = nil
      @evolution = 9.times.map do |index|
        rng = Random.new(@seed + (index + 1) * 7919)
        variant_dna = @dna.mutate(rng: rng, strength: 0.10 + (index * 0.006))
        variant_seed = (@seed + (index + 1) * 104_729) % 2_147_483_647
        pixels = Generators.generate(algorithm: @algorithm, width: 18, height: 18,
                                     palette: @palette, seed: variant_seed, params: variant_dna)
        { dna: variant_dna, seed: variant_seed, pixels: pixels }
      end
      @thumbs.each_with_index do |canvas, index|
        canvas.clear
        variant = @evolution[index]
        pixels = variant[:pixels]
        cell_x = EVOLUTION_THUMB_SIZE.to_f / 18
        cell_y = EVOLUTION_THUMB_SIZE.to_f / 18
        pixels.each_with_index do |row, y|
          row.each_with_index do |color, x|
            next unless color
            canvas.fill_rectangle(x: x * cell_x, y: y * cell_y, width: cell_x + 0.2, height: cell_y + 0.2, color: color)
          end
        end
        canvas.update if canvas.respond_to?(:update)
        @thumb_meta[index][0].content = "Seed: #{variant[:seed]}"
        dna = variant[:dna]
        detail = case @algorithm
                 when :terrain then "Terrain  ·  R#{format('%.2f', dna[:terrain_roughness])}"
                 when :cellular then "Cellular  ·  D#{format('%.2f', dna[:cellular_density])}"
                 when :bayer then "Bayer  ·  D#{format('%.2f', dna[:bayer_density])}"
                 when :symmetry then "Symmetry  ·  #{dna[:symmetry_seeds]}"
                 else "Noise  ·  D#{format('%.2f', dna[:noise_density])}  ·  O#{dna[:octaves]}"
                 end
        @thumb_meta[index][1].content = detail
      end
      update_evolution_card_states
    end

    def update_evolution_card_states
      return unless @evolution_card_borders

      @evolution_card_borders.each_with_index do |border, index|
        border.stroke_color = index == @selected_evolution ? COLORS[:crimson] : COLORS[:border]
      end
    end

    def breed_variant(index)
      variant = @evolution[index]
      return unless variant
      before = snapshot_document
      @dna = variant[:dna]
      @seed = variant[:seed]
      generate(@algorithm, before_snapshot: before, force_replace: true)
      @selected_evolution = index
      update_evolution_card_states
      set_status("Variant #{index + 1} applied to the canvas. One undo restores the previous artwork.")
    end

    def change_gene(gene, direction)
      before = snapshot_document
      case gene
      when :density
        @dna[:noise_density] = clamp(@dna[:noise_density] + (0.05 * direction), 0.05, 1.0)
      when :octaves
        @dna[:octaves] = clamp(@dna[:octaves] + direction, 1, 7)
      when :seeds
        @dna[:symmetry_seeds] = clamp(@dna[:symmetry_seeds] + (5 * direction), 1, 250)
      when :roughness
        @dna[:terrain_roughness] = clamp(@dna[:terrain_roughness] + (0.05 * direction), 0.1, 1.0)
      when :persistence
        @dna[:persistence] = clamp(@dna[:persistence] + (0.05 * direction), 0.2, 0.9)
      when :cellular_density
        @dna[:cellular_density] = clamp(@dna[:cellular_density] + (0.05 * direction), 0.1, 0.9)
      when :cellular_steps
        @dna[:cellular_steps] = clamp(@dna[:cellular_steps] + direction, 1, 8)
      when :horizon
        @dna[:terrain_horizon] = clamp(@dna[:terrain_horizon] + (0.03 * direction), 0.25, 0.78)
      when :bayer_density
        @dna[:bayer_density] = clamp(@dna[:bayer_density] + (0.05 * direction), 0.05, 0.95)
      end
      regenerate_after_gene(before, gene)
    end

    def regenerate_after_gene(before, gene, force_replace: false)
      pixels = Generators.generate(algorithm: @algorithm, width: @document.width,
                                   height: @document.height, palette: @palette,
                                   seed: @seed, params: @dna)
      if !force_replace && (@fill_empty_only || @dna[:fill_empty_only])
        current = @document.to_a
        pixels = pixels.each_with_index.map { |row, y| row.each_with_index.map { |c, x| current[y][x] || c } }
      end
      @document.replace!(pixels)
      @history.commit(before, snapshot_document)
      rebuild_canvas_geometry
      render_all_pixels
      generate_evolution
      update_all_labels
      set_status("DNA mutation: #{gene.to_s.upcase}. Same seed, altered recipe.")
      autosave
    end

    # ----------------------------------------------------------------------
    # Actions, palettes, project persistence, and prompts
    # ----------------------------------------------------------------------
    def activate_button(id)
      id = id.to_s
      case id
      when 'brush', 'eraser', 'fill', 'picker', 'line', 'rectangle', 'ellipse', 'mirror'
        @tool = id.to_sym
        update_button_states
        set_status("#{id.to_s.upcase} tool selected.")
      when 'symmetry_off' then @symmetry_mode = 1; update_button_states; set_status('Symmetry disabled for live brush painting.')
      when 'symmetry_4'
        before = snapshot_document
        @symmetry_mode = 4
        @dna[:symmetry_order] = 4
        update_button_states
        if @algorithm == :symmetry
          generate(:symmetry, before_snapshot: before)
        else
          @history.commit(before, snapshot_document)
          set_status('Four-fold radial symmetry enabled.')
        end
      when 'grid_toggle' then @show_grid = !@show_grid; rebuild_canvas_geometry; render_all_pixels; update_button_states
      when 'undo' then undo
      when 'redo' then redo_action
      when 'symmetry_8'
        before = snapshot_document
        @symmetry_mode = 8
        @dna[:symmetry_order] = 8
        update_button_states
        if @algorithm == :symmetry
          generate(:symmetry, before_snapshot: before)
        else
          @history.commit(before, snapshot_document)
          set_status('Eight-fold radial symmetry enabled.')
        end
      when /\Abrush_(\d+)\z/ then @brush_size = Regexp.last_match(1).to_i; update_button_states; update_all_labels
      when 'palette_import'
        path = choose_open_file(title: 'Import palette', filter: 'Palette files (*.gpl;*.json)|*.gpl;*.json|All files (*.*)|*.*')
        perform_action { import_palette(path) } if path
      when /\Apalette_(.+)\z/ then set_palette(Regexp.last_match(1).capitalize)
      when /\Acanvas_(\d+)\z/ then resize_canvas(Regexp.last_match(1).to_i)
      when 'hex_color' then begin_input(:hex, 'Enter a hex color, e.g. #FF886D')
      when 'gradient' then begin_input(:gradient, 'Gradient: #START,#END[,STEPS]')
      when 'remap' then remap_existing_art
      when 'swatch_prev' then @palette_offset = [@palette_offset - 6, 0].max; rebuild_swatches
      when 'swatch_next' then @palette_offset = [@palette_offset + 6, [((@palette.length - 1) / 6) * 6, 0].max].min; rebuild_swatches
      when 'import_png'
        path = choose_open_file(title: 'Import PNG artwork', filter: 'PNG images (*.png)|*.png|All files (*.*)|*.*')
        perform_action { import_png(path) } if path
      when 'save_project'
        path = choose_save_file(title: 'Save Dapple project', filter: 'Dapple project (*.dapple)|*.dapple',
                                default_name: "#{@project_name.to_s.gsub(/[^a-zA-Z0-9_-]+/, '-')}.dapple")
        perform_action { save_project(path) } if path
      when 'load_project'
        path = choose_open_file(title: 'Open Dapple project', filter: 'Dapple project (*.dapple)|*.dapple')
        perform_action { load_project(path) } if path
      when 'export_png'
        perform_action { export_png }
      when 'fill_empty'
        before = snapshot_document
        @fill_empty_only = !@fill_empty_only
        @dna[:fill_empty_only] = @fill_empty_only
        update_button_states
        generate(@algorithm, before_snapshot: before)
      when 'export_scale'
        scales = [4, 8, 16, 24, 32]
        @export_scale = scales.fetch((scales.index(@export_scale).to_i + 1) % scales.length)
        @buttons[id.to_sym].label = "SCALE #{@export_scale}×"
      when 'seed_set' then begin_seed_edit
      when 'seed_copy'
        set_status(Clipboard.copy(@seed.to_s) ? "Seed #{@seed} copied." : 'Clipboard unavailable on this system.')
      when 'seed_random'
        before = snapshot_document
        @seed = Random.new_seed % 2_147_483_647
        regenerate_after_gene(before, :seed, force_replace: true)
      when 'algorithm_noise' then generate(:noise)
      when 'algorithm_symmetry' then generate(:symmetry)
      when 'algorithm_terrain' then generate(:terrain)
      when 'algorithm_cellular' then generate(:cellular)
      when 'algorithm_bayer' then generate(:bayer)
      when 'gene_density_down' then change_gene(:density, -1)
      when 'gene_density_up' then change_gene(:density, 1)
      when 'gene_octaves_down' then change_gene(:octaves, -1)
      when 'gene_octaves_up' then change_gene(:octaves, 1)
      when 'gene_seeds_down' then change_gene(:seeds, -1)
      when 'gene_seeds_up' then change_gene(:seeds, 1)
      when 'gene_roughness_down' then change_gene(:roughness, -1)
      when 'gene_roughness_up' then change_gene(:roughness, 1)
      when 'gene_persistence_down' then change_gene(:persistence, -1)
      when 'gene_persistence_up' then change_gene(:persistence, 1)
      when 'gene_cellular_density_down' then change_gene(:cellular_density, -1)
      when 'gene_cellular_density_up' then change_gene(:cellular_density, 1)
      when 'gene_cellular_steps_down' then change_gene(:cellular_steps, -1)
      when 'gene_cellular_steps_up' then change_gene(:cellular_steps, 1)
      when 'gene_horizon_down' then change_gene(:horizon, -1)
      when 'gene_horizon_up' then change_gene(:horizon, 1)
      when 'gene_bayer_density_down' then change_gene(:bayer_density, -1)
      when 'gene_bayer_density_up' then change_gene(:bayer_density, 1)
      when 'zoom_in' then change_zoom(0.1)
      when 'zoom_out' then change_zoom(-0.1)
      end
      autosave if @input_mode.nil?
    end

    def set_palette(name)
      @palette_name = name
      @palette = Palettes.fetch(name).dup
      @palette_offset = 0
      @selected_color = @palette[[[@palette.length / 2, 0].max, @palette.length - 1].min]
      rebuild_swatches
      generate_evolution
      update_all_labels
      update_button_states
      set_status("#{name} palette activated. Existing artwork remains untouched until remapped.")
    end

    def rebuild_swatches
      @swatches.each(&:remove)
      @swatches = []
      @swatch_bounds = []
      @palette.slice(@palette_offset, 6).to_a.each_with_index do |color, index|
        palette_index = @palette_offset + index
        x = 34 + index * 45
        outline = Ruby2D::Rectangle.new(x: x - 2, y: 885, width: 40, height: 24,
                                       color: color == @selected_color ? COLORS[:gold] : COLORS[:border], z: 8)
        swatch = Ruby2D::Rectangle.new(x: x, y: 887, width: 36, height: 20, color: color, z: 9)
        @swatches << outline << swatch
        @swatch_bounds << [x, 887, 36, 20, color, palette_index]
      end
    end

    def remap_existing_art
      return if @palette.empty? || @document.painted_count.zero?

      before = snapshot_document
      remapped = {}
      @document.each_pixel do |x, y, color|
        next unless color

        destination = (remapped[color] ||= Palettes.nearest(color, @palette))
        @document.set_pixel(x, y, destination)
      end
      @history.commit(before, snapshot_document)
      rebuild_canvas_geometry
      render_all_pixels
      autosave
      set_status('Existing artwork remapped to the active palette.')
    end

    def resize_canvas(size)
      before = snapshot_document
      @document.resize!(size, size, preserve: true)
      @history.commit(before, snapshot_document)
      rebuild_canvas_geometry
      render_all_pixels
      update_all_labels
      generate_evolution
      autosave
      set_status("Canvas resized to #{size} × #{size}. Existing pixels were preserved.")
    end

    def change_zoom(delta)
      @zoom = clamp(@zoom + delta, 0.5, 1.0)
      rebuild_canvas_geometry
      render_all_pixels
      set_status("Canvas zoom: #{(@zoom * 100).round}%.")
    end

    def import_png(path)
      pixels = ImageImporter.pixels(path, width: @document.width, height: @document.height,
                                    palette: @palette, quantize: true)
      before = snapshot_document
      @document.replace!(pixels)
      @history.commit(before, snapshot_document)
      rebuild_canvas_geometry
      render_all_pixels
      generate_evolution
      autosave
      set_status("Imported #{File.basename(path)} as editable #{@document.width} × #{@document.height} pixels.")
    end

    def save_project(path)
      destination = normalize_project_path(path)
      Project.save(destination, document: @document, palette_name: @palette_name,
                   palette: @palette, algorithm: @algorithm, params: @dna, seed: @seed)
      @project_name = File.basename(destination, '.dapple')
      set_status("Project saved: #{File.basename(destination)}.")
    end

    def load_project(path)
      path = normalize_project_path(path)
      state = Project.load(path)
      @project_name = File.basename(path, '.dapple')
      @document = state[:document]
      @palette_name = state[:palette_name]
      @palette = state[:palette]
      @palette_offset = 0
      @algorithm = state[:algorithm]
      @dna = state[:params]
      @fill_empty_only = @dna[:fill_empty_only]
      @symmetry_mode = @dna[:symmetry_order]
      @seed = state[:seed]
      @palette_offset = 0
      @history.clear
      @selected_color = @palette.first
      rebuild_swatches
      rebuild_canvas_geometry
      render_all_pixels
      generate_evolution
      update_button_states
      autosave
      set_status("Loaded #{File.basename(path)}. Your project is back.")
    end

    def export_png
      export_dir = File.expand_path('../../exports', __dir__)
      FileUtils.mkdir_p(export_dir)
      stem = @project_name.to_s.gsub(/[^a-zA-Z0-9_-]+/, '-').gsub(/\A-+|-+\z/, '')
      stem = 'dapple-artwork' if stem.empty?
      filename = "#{stem}-#{@document.width}x#{@document.height}-#{Time.now.strftime('%Y%m%d-%H%M%S-%6N')}.png"
      destination = File.join(export_dir, filename)
      Exporter.export(@document, destination, scale: @export_scale)
      set_status("PNG exported to exports/#{filename} at #{@export_scale}×.")
    end

    def autosave
      Project.save(Project.autosave_path, document: @document, palette_name: @palette_name,
                   palette: @palette, algorithm: @algorithm, params: @dna, seed: @seed)
    rescue StandardError => error
      @status = "Autosave skipped: #{error.message}"
    end

    def load_autosave
      path = Project.autosave_path
      return false unless File.file?(path)
      state = Project.load(path)
      @document = state[:document]
      @project_name = 'Recovered masterpiece'
      @palette_name = state[:palette_name]
      @palette = state[:palette]
      @palette_offset = 0
      @algorithm = state[:algorithm]
      @dna = state[:params]
      @fill_empty_only = @dna[:fill_empty_only]
      @symmetry_mode = @dna[:symmetry_order]
      @seed = state[:seed]
      @palette_offset = 0
      @selected_color = @palette.first
      rebuild_swatches
      set_status('Autosaved project restored.')
      true
    rescue StandardError
      set_status('Autosave found but could not be restored. Starting fresh.')
    end

    def begin_input(mode, prompt)
      return begin_seed_edit if mode == :seed
      @input_mode = mode
      @input_buffer = +''
      @input_selected = false
      @prompt_back = Ruby2D::Rectangle.new(x: 420, y: 360, width: 808, height: 190,
                                           color: COLORS[:panel_soft], z: 40)
      @prompt_outline = Ruby2D::Rectangle.new(x: 416, y: 356, width: 816, height: 198,
                                              color: COLORS[:coral], z: 39)
      @prompt_label = Ruby2D::Text.new(prompt, x: 452, y: 390, size: 22, color: COLORS[:text], z: 41)
      @prompt_value = Ruby2D::Text.new('_', x: 452, y: 446, size: 19, color: COLORS[:lime], z: 41)
      @prompt_help = Ruby2D::Text.new('ENTER  CONFIRM     ESC  CANCEL     BACKSPACE  DELETE',
                                      x: 452, y: 510, size: 13, color: COLORS[:muted], z: 41)
    end

    def handle_input_key(key)
      raw = key.to_s
      normalized = raw.downcase

      if (control_held? && normalized == 'v') || (shift_held? && normalized == 'insert')
        paste_into_input
        return
      end

      if control_held?
        case normalized
        when 'a'
          @input_selected = true
          if @input_mode == :seed
            refresh_input_prompt
          else
            @prompt_value.content = "#{@input_buffer}  [ALL SELECTED]_"
          end
        when 'c'
          Clipboard.copy(@input_buffer)
        when 'x'
          Clipboard.copy(@input_buffer)
          @input_buffer = +''
          @input_selected = false
          refresh_input_prompt
        end
        return
      end

      return if normalized.include?('control') || normalized.include?('ctrl') || normalized.include?('shift')

      if normalized == 'escape'
        if @input_mode == :seed && @seed_edit_original
          @seed = @seed_edit_original
          @seed_edit_original = nil
          close_input
          update_all_labels
          return
        end
        close_input
      elsif normalized == 'enter' || normalized == 'return'
        process_input
      elsif normalized == 'backspace' || normalized == 'delete'
        if @input_selected
          @input_buffer = +''
          @input_selected = false
        else
          @input_buffer = @input_buffer[0...-1]
        end
        refresh_input_prompt
      elsif normalized == 'space'
        append_input(' ')
      elsif raw.length == 1 && raw.match?(/[[:print:]]/)
        append_input(raw)
      end
    end

    def paste_into_input
      pasted = Clipboard.paste
      if pasted.nil? || pasted.empty?
        set_status('Clipboard is empty or unavailable.')
        return
      end
      pasted = pasted.strip if @input_mode == :seed
      if @input_mode == :seed && !pasted.match?(/\A[+-]?\d+\z/)
        set_status('The seed clipboard must contain an integer.')
        return
      end
      @input_buffer = +'' if @input_selected
      @input_selected = false
      @input_buffer << pasted
      refresh_input_prompt
      set_status('Clipboard text pasted into the input field.')
    end

    def append_input(character)
      @input_buffer = +'' if @input_selected
      @input_selected = false
      if @input_mode == :seed && !character.match?(/[0-9+-]/)
        return
      end
      @input_buffer << character
      refresh_input_prompt
    end

    def refresh_input_prompt
      if @input_mode == :seed
        @rendered_seed = nil
        render_seed_text
      else
        @prompt_value.content = "#{@input_buffer}_"
      end
    end

    def process_input
      value = @input_buffer.strip
      mode = @input_mode
      close_input
      case mode
      when :seed
        before = snapshot_document
        raise ArgumentError, 'enter or paste an integer seed' if value.empty?
        @seed = Integer(value, 10)
        @seed_edit_original = nil
        regenerate_after_gene(before, :seed, force_replace: true)
      when :hex
        @selected_color = Palettes.normalize(value)
        @palette = (@palette + [@selected_color]).uniq.last(32)
        @palette_offset = ((@palette.length - 1) / 6) * 6
        rebuild_swatches
        generate_evolution
        update_all_labels
        set_status("Custom color #{@selected_color} added to the palette.")
      when :palette_import then import_palette(value)
      when :gradient
        parts = value.split(',').map(&:strip)
        raise ArgumentError, 'use #START,#END[,STEPS]' unless parts.length.between?(2, 3)
        @palette = Palettes.gradient(parts[0], parts[1], (parts[2] || '6').to_i)
        @palette_offset = 0
        @palette_name = 'Gradient'
        @selected_color = @palette.first
        rebuild_swatches
        generate_evolution
        update_all_labels
        set_status('Gradient ramp generated and loaded.')
      when :import_png then import_png(value)
      when :save_project then save_project(value)
      when :load_project then load_project(value)
      when :export_png then export_png
      end
      autosave
    rescue StandardError => error
      set_status("Action failed: #{error.message}")
    end

    def close_input
      [@prompt_back, @prompt_outline, @prompt_label, @prompt_value, @prompt_help].compact.each(&:remove)
      was_seed = @input_mode == :seed
      @input_mode = nil
      @input_buffer = +''
      @input_selected = false
      if was_seed && @seed_field_outline
        @seed_field_outline.color = COLORS[:gold]
        @rendered_seed = nil
        render_seed_text
      end
    end

    def normalize_project_path(path)
      value = File.expand_path(path.start_with?('~') ? File.expand_path(path) : path)
      value.end_with?('.dapple') ? value : "#{value}.dapple"
    end

    def perform_action
      yield
    rescue StandardError => error
      set_status("Action failed: #{error.message}")
    end

    def import_palette(path)
      @palette = Palettes.import(path)
      @palette_offset = 0
      @palette_name = 'Imported'
      @selected_color = @palette.first
      rebuild_swatches
      update_all_labels
      generate_evolution
      set_status("Imported #{@palette.length} palette colors from #{File.basename(path)}.")
    end

    # Windows uses the real .NET OpenFileDialog/SaveFileDialog. Linux desktops
    # fall back to zenity or kdialog when available.
    def choose_open_file(title:, filter:, initial_dir: Dir.pwd)
      choose_file_with_dialog(:open, title: title, filter: filter, initial_dir: initial_dir)
    end

    def choose_save_file(title:, filter:, default_name:, initial_dir: Dir.pwd)
      choose_file_with_dialog(:save, title: title, filter: filter, initial_dir: initial_dir,
                              default_name: default_name)
    end

    def choose_file_with_dialog(kind, title:, filter:, initial_dir:, default_name: nil)
      if RUBY_PLATFORM.match?(/mswin|mingw|cygwin/i)
        type = kind == :save ? 'SaveFileDialog' : 'OpenFileDialog'
        extra = kind == :save ? "$dialog.FileName = '#{default_name.to_s.gsub("'", "''")}'; " : ''
        script = [
          'Add-Type -AssemblyName System.Windows.Forms;',
          "$dialog = New-Object System.Windows.Forms.#{type};",
          "$dialog.Title = '#{title.gsub("'", "''")}';",
          "$dialog.Filter = '#{filter.gsub("'", "''")}';",
          '$dialog.InitialDirectory = $env:DAPPLE_DIALOG_DIR;',
          (kind == :save ? '$dialog.DefaultExt = "dapple"; $dialog.AddExtension = $true;' : ''),
          extra,
          'if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::WriteLine($dialog.FileName) }'
        ].join(' ')
        output = IO.popen({ 'DAPPLE_DIALOG_DIR' => initial_dir }, ['powershell.exe', '-NoProfile', '-NonInteractive', '-STA', '-Command', script], &:read).to_s.strip
        return output.empty? ? nil : output
      end

      if system('which zenity > /dev/null 2>&1')
        command = ['zenity', kind == :save ? '--file-selection' : '--file-selection',
                   '--title', title, '--file-filter', filter]
        command << '--save' if kind == :save
        command << '--filename' << File.join(initial_dir, default_name) if kind == :save
        output = IO.popen(command, &:read).to_s.strip
        return output.empty? ? nil : output
      end

      if system('which kdialog > /dev/null 2>&1')
        command = kind == :save ? ['kdialog', '--getsavefilename', File.join(initial_dir, default_name), filter, '--title', title] :
                                  ['kdialog', '--getopenfilename', initial_dir, filter, '--title', title]
        output = IO.popen(command, &:read).to_s.strip
        return output.empty? ? nil : output
      end

      set_status('No native file dialog is available on this system.')
      nil
    rescue StandardError => error
      set_status("File dialog failed: #{error.message}")
      nil
    end

    # History snapshots include document dimensions and generation metadata,
    # so undoing a resize or DNA mutation restores a coherent project state.
    def snapshot_document
      { width: @document.width, height: @document.height, pixels: @document.to_a,
        palette_name: @palette_name, palette: @palette.dup, algorithm: @algorithm,
        params: @dna.to_h, seed: @seed, symmetry_mode: @symmetry_mode }
    end

    def restore_snapshot(snapshot)
      @document = Document.new(width: snapshot.fetch(:width), height: snapshot.fetch(:height))
      @document.replace!(snapshot.fetch(:pixels))
      @palette_name = snapshot.fetch(:palette_name, @palette_name)
      @palette = snapshot.fetch(:palette, @palette).dup
      @algorithm = snapshot.fetch(:algorithm, @algorithm).to_sym
      @dna = PatternDNA.new(**snapshot.fetch(:params, @dna.to_h))
      @seed = snapshot.fetch(:seed, @seed)
      @symmetry_mode = snapshot.fetch(:symmetry_mode, @dna[:symmetry_order])
      @palette_offset = 0
      @fill_empty_only = @dna[:fill_empty_only]
      @selected_color = @palette.first unless @palette.include?(@selected_color)
      rebuild_swatches
    end

    # ----------------------------------------------------------------------
    # History and keyboard
    # ----------------------------------------------------------------------
    def finish_edit(before)
      return unless before
      after = snapshot_document
      if @history.commit(before, after)
        autosave
        set_status('Stroke committed. One clean undo step.')
      end
      update_all_labels
    end

    def undo
      previous = @history.undo(snapshot_document)
      unless previous
        set_status('Nothing to undo.')
        return
      end
      restore_snapshot(previous)
      rebuild_canvas_geometry
      render_all_pixels
      autosave
      set_status('Undone.')
    end

    def redo_action
      next_state = @history.redo(snapshot_document)
      unless next_state
        set_status('Nothing to redo.')
        return
      end
      restore_snapshot(next_state)
      rebuild_canvas_geometry
      render_all_pixels
      autosave
      set_status('Redone.')
    end

    def handle_shortcut(event)
      key = event.key.to_s.downcase
      shift = shift_held?
      control = control_held?
      case key
      when 'b' then @tool = :brush
      when 'e' then @tool = :eraser
      when 'f' then @tool = :fill
      when 'i' then @tool = :picker
      when 'l' then @tool = :line
      when 'r' then @tool = :rectangle
      when 'o' then @tool = :ellipse
      when 'm' then @tool = :mirror
      when 'g' then @show_grid = !@show_grid; rebuild_canvas_geometry; render_all_pixels
      when 'z' then shift ? redo_action : undo
      when 'y' then redo_action
      when '[' then @brush_size = [@brush_size - 1, 1].max
      when ']' then @brush_size = [@brush_size + 1, 32].min
      when '=', '+' then change_zoom(0.1)
      when '-', '_' then change_zoom(-0.1)
      when 'left' then @pan_x -= 24; rebuild_canvas_geometry; render_all_pixels
      when 'right' then @pan_x += 24; rebuild_canvas_geometry; render_all_pixels
      when 'up' then @pan_y -= 24; rebuild_canvas_geometry; render_all_pixels
      when 'down' then @pan_y += 24; rebuild_canvas_geometry; render_all_pixels
      when 's' then activate_button('save_project') if control
      when 'escape' then Ruby2D::Window.close
      end
      update_button_states
      update_all_labels
    end

    # ----------------------------------------------------------------------
    # UI helpers and state labels
    # ----------------------------------------------------------------------
    # Start in a comfortable decorated window, then maximize the native
    # Windows window after the first frame. Windows itself sizes it to the
    # work area, keeping the taskbar and native title bar available.
    def fitted_window_size
      screen_width, screen_height = display_dimensions
      scale = [[(screen_width - 100).to_f / WINDOW_WIDTH,
                (screen_height - 140).to_f / WINDOW_HEIGHT, 0.92].min, 0.62].max
      [(WINDOW_WIDTH * scale).round, (WINDOW_HEIGHT * scale).round]
    end

    def display_dimensions
      if ENV['DAPPLE_SCREEN_WIDTH'] && ENV['DAPPLE_SCREEN_HEIGHT']
        width = Integer(ENV['DAPPLE_SCREEN_WIDTH'])
        height = Integer(ENV['DAPPLE_SCREEN_HEIGHT'])
        return [width, height] if width.positive? && height.positive?
      end

      if RUBY_PLATFORM.match?(/mswin|mingw|cygwin/i)
        command = ['powershell.exe', '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command',
                   'Add-Type -AssemblyName System.Windows.Forms; $b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds; Write-Output ("{0},{1}" -f $b.Width,$b.Height)']
        output = IO.popen(command, &:read).to_s.strip
        if (match = output.match(/\A(\d+)\s*,\s*(\d+)\z/))
          width, height = match.captures.map(&:to_i)
          return [width, height] if width.positive? && height.positive?
        end
      end
      [1366, 768]
    rescue StandardError
      [1366, 768]
    end

    def add_button(id, label, x, y, width, height, primary: false, tint: COLORS[:gold], swatches: nil)
      @buttons[id] = UI::Button.new(id: id, label: label, x: x, y: y,
                                    width: width, height: height, tint: tint, primary: primary,
                                    swatches: swatches, hover_color: COLORS[:panel_hover])
    end

    def add_text(content, x, y, size:, color:, z: 6)
      Ruby2D::Text.new(content, x: x, y: y, size: size, color: color, z: z)
    end

    def add_divider(x, y, width)
      Ruby2D::Rectangle.new(x: x, y: y, width: width, height: 1, color: COLORS[:border_soft], z: 4)
    end

    def update_hover(x, y)
      @buttons.each_value { |button| button.hovered = button.include?(x, y) }
    end

    def update_button_states
      @buttons.each do |id, button|
        name = id.to_s
        active = case name
                 when 'brush', 'eraser', 'fill', 'picker', 'line', 'rectangle', 'ellipse', 'mirror' then @tool.to_s == name
                 when 'symmetry_off' then @symmetry_mode == 1
                 when 'symmetry_4' then @symmetry_mode == 4
                 when 'symmetry_8' then @symmetry_mode == 8
                 when 'grid_toggle' then @show_grid
                 when 'undo' then @history.can_undo?
                 when 'redo' then @history.can_redo?
                 when /\Abrush_(\d+)\z/ then @brush_size == Regexp.last_match(1).to_i
                 when /\Apalette_(.+)\z/ then @palette_name.downcase == Regexp.last_match(1)
                 when /\Acanvas_(\d+)\z/ then @document.width == Regexp.last_match(1).to_i
                 when 'algorithm_noise' then @algorithm == :noise
                 when 'algorithm_symmetry' then @algorithm == :symmetry
                 when 'algorithm_terrain' then @algorithm == :terrain
                 when 'algorithm_cellular' then @algorithm == :cellular
                 when 'algorithm_bayer' then @algorithm == :bayer
                 when 'fill_empty' then @fill_empty_only
                 else false
                 end
        button.active = active
      end
    end

    def render_seed_text
      value = @input_mode == :seed ? @input_buffer : @seed.to_s
      value = ' ' if value.empty?
      return if @seed_text && @rendered_seed == value

      @seed_text&.remove
      font_size = [[(132.0 / [value.length * 0.62, 1].max).floor, 17].min, 10].max
      color = @input_mode == :seed ? COLORS[:cream] : COLORS[:gold]
      @seed_text = Ruby2D::Text.new(value, x: 1180, y: 465 + ((18 - font_size) / 2.0),
                                    size: font_size, color: color, z: 22)
      @rendered_seed = value
    end

    def update_all_labels
      @document_name.content = @project_name if @document_name
      @dimension_text.content = "#{@document.width} × #{@document.height}" if @dimension_text
      @status_text.content = @status if @status_text
      @count_text.content = "#{@document.painted_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} PIXELS" if @count_text
      @zoom_text.content = "#{(@zoom * 100).round}%" if @zoom_text
      render_seed_text if @seed_field_bg
      @current_color_chip.color = @selected_color if @current_color_chip
      @current_color_text.content = @selected_color if @current_color_text
      update_gene_slider_visuals if @gene_sliders && !@gene_sliders.empty?
      update_button_states if @buttons
    end

    def update_gene_slider_visuals
      @gene_sliders.each do |id, slider|
        param, minimum, maximum, = GENE_SLIDERS.fetch(id)
        value = @dna[param]
        ratio = (value.to_f - minimum) / (maximum - minimum).to_f
        ratio = clamp(ratio, 0.0, 1.0)
        slider[:fill].width = [slider[:width] * ratio, 1].max
        slider[:knob].x = slider[:x] + slider[:width] * ratio
        slider[:value].content = value.is_a?(Integer) ? value.to_s : format('%.2f', value)
      end
    end

    def begin_seed_edit
      @input_mode = :seed
      @input_buffer = @seed.to_s
      @input_selected = true
      @seed_edit_original = @seed
      @seed_field_outline.color = COLORS[:crimson]
      @rendered_seed = nil
      render_seed_text
      set_status('Seed field focused. Paste with Ctrl+V, then press Enter to apply.')
    end

    def update_gene_slider(id, mouse_x)
      param, minimum, maximum, step = GENE_SLIDERS.fetch(id)
      slider = @gene_sliders.fetch(id)
      ratio = clamp((mouse_x - slider[:x]).to_f / slider[:width], 0.0, 1.0)
      raw = minimum + (maximum - minimum) * ratio
      value = ((raw / step).round * step).round(4)
      value = clamp(value, minimum, maximum)
      current = @dna[param]
      value = value.round if current.is_a?(Integer)
      return if value == current

      @dna[param] = value
      @slider_changed = true
      preview_generation_from_dna
      update_all_labels
    end

    def preview_generation_from_dna
      pixels = Generators.generate(algorithm: @algorithm, width: @document.width,
                                    height: @document.height, palette: @palette,
                                    seed: @seed, params: @dna)
      if @fill_empty_only || @dna[:fill_empty_only]
        current = @document.to_a
        pixels = pixels.each_with_index.map do |row, y|
          row.each_with_index.map { |color, x| current[y][x] || color }
        end
      end
      @document.replace!(pixels)
      rebuild_canvas_geometry
      render_all_pixels
      generate_evolution
      set_status("Tuning #{id_label_for_slider(@dragging_slider)} · release to commit")
    rescue StandardError => error
      set_status("Slider update failed: #{error.message}")
    end

    def id_label_for_slider(id)
      id.to_s.tr('_', ' ').capitalize
    end

    def finish_gene_slider
      return unless @dragging_slider
      if @slider_changed && @slider_before
        @history.commit(@slider_before, snapshot_document)
        autosave
        set_status("#{id_label_for_slider(@dragging_slider)} updated. One undo restores the previous composition.")
      end
      @dragging_slider = nil
      @slider_before = nil
      @slider_changed = false
    end

    def set_status(message)
      @status = message
      update_all_labels
    end

    def left_button?(event)
      return event.button?(:left) if event.respond_to?(:button?)
      [:left, 'left', 1].include?(event.button)
    end

    def shift_held?
      @keys_down.keys.any? { |key| key.include?('shift') }
    end

    def shifted_key(key)
      return key unless shift_held?
      return key.upcase if key.match?(/\A[a-z]\z/)

      { '1' => '!', '2' => '@', '3' => '#', '4' => '$', '5' => '%',
        '6' => '^', '7' => '&', '8' => '*', '9' => '(', '0' => ')',
        '-' => '_', '=' => '+', '[' => '{', ']' => '}', '\\' => '|',
        ';' => ':', "'" => '"', ',' => '<', '.' => '>', '/' => '?',
        '`' => '~' }.fetch(key, key)
    end

    def control_held?
      @keys_down.keys.any? { |key| key.include?('control') || key.include?('ctrl') }
    end

    def clamp(value, low, high)
      [[value, low].max, high].min
    end
  end
end
