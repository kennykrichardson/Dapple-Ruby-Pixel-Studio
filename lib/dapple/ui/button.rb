# frozen_string_literal: true

module Dapple
  module UI
    # Shared, compact control styling. Palette cards deliberately retain their
    # own colors; the crimson/gold accents apply only to the editor chrome.
    class Button
      attr_reader :id, :x, :y, :width, :height

      def initialize(id:, label:, x:, y:, width:, height:, tint:, primary: false,
                     swatches: nil, hover_color: '#252329', z: 20)
        @id = id.to_s
        @label_text = label.to_s
        @x, @y, @width, @height = x, y, width, height
        @tint = tint
        @primary = primary
        @swatches = swatches&.take(8)
        @hover_color = hover_color
        @z = z
        @active = false
        @hovered = false
        @pressed = false
        @shape_objects = []
        build_shapes
        refresh
      end

      def include?(px, py)
        px >= x && px < x + width && py >= y && py < y + height
      end

      def active=(value)
        @active = !!value
        refresh
      end

      def hovered=(value)
        @hovered = !!value
        refresh
      end

      def pressed=(value)
        @pressed = !!value
        refresh
      end

      def label=(value)
        @label_text = value.to_s
        @label.remove
        @label = build_label
        refresh
      end

      def remove
        @shape_objects.each(&:remove)
        @label&.remove
      end

      private

      def build_shapes
        @outline = Ruby2D::Rectangle.new(x: x, y: y, width: width, height: height,
                                         color: '#39363B', z: @z)
        @background = Ruby2D::Rectangle.new(x: x + 1, y: y + 1, width: [width - 2, 1].max,
                                            height: [height - 2, 1].max, color: '#17171B', z: @z + 1)
        @top_edge = Ruby2D::Rectangle.new(x: x + 2, y: y + 2, width: [width - 4, 1].max,
                                          height: 1, color: '#454149', z: @z + 2)
        @shape_objects.concat([@outline, @background, @top_edge])

        if @swatches && !@swatches.empty?
          stripe_height = [height * 0.48, 30].min
          @swatches.each_with_index do |color, index|
            stripe_width = width.to_f / @swatches.length
            stripe = Ruby2D::Rectangle.new(x: x + 1 + (index * stripe_width), y: y + 1,
                                           width: stripe_width + 0.25, height: stripe_height,
                                           color: color, z: @z + 2)
            @shape_objects << stripe
          end
          @label = Ruby2D::Text.new(@label_text, x: centered_label_x,
                                    y: y + height - label_size - 6,
                                    size: label_size, color: '#F5F0E6', z: @z + 4)
        else
          @accent = Ruby2D::Rectangle.new(x: x + 3, y: y + 5, width: 3,
                                          height: [height - 10, 1].max,
                                          color: @tint, z: @z + 3)
          @shape_objects << @accent
          @label = build_label
        end
      end

      def build_label
        Ruby2D::Text.new(@label_text, x: centered_label_x, y: centered_label_y,
                         size: label_size, color: '#F5F0E6', z: @z + 4)
      end

      def label_size
        max_size = @swatches ? 14 : 14
        height_limit = (@swatches ? height * 0.27 : height * 0.46).floor
        usable_width = width - (@swatches ? 10 : 22)
        width_limit = (usable_width.to_f / [@label_text.length * 0.55, 1].max).floor
        [[height_limit, width_limit, max_size].min, 9].max
      end

      def centered_label_x
        x + ((width - (@label_text.length * label_size * 0.54)) / 2.0)
      end

      def centered_label_y
        y + ((height - label_size) / 2.0) - 1
      end

      def refresh
        selected = @active || @primary
        border = if @pressed
                   '#F5F0E6'
                 elsif selected
                   @tint
                 elsif @hovered
                   '#9B8150'
                 else
                   '#39363B'
                 end
        fill = if @pressed
                 '#302126'
               elsif @active
                 @tint == '#D92743' ? '#351720' : '#30291B'
               elsif @primary
                 '#321923'
               elsif @hovered
                 @hover_color
               else
                 '#17171B'
               end
        @outline.color = border
        @background.color = fill
        @top_edge.color = selected ? '#73503E' : '#454149'
        @accent.color = @pressed ? '#F5F0E6' : (@hovered || selected ? @tint : '#6B6258') if @accent
        @label.color = '#F5F0E6'
      end
    end
  end
end
