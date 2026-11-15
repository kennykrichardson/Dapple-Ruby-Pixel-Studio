# frozen_string_literal: true

module Dapple
  # Snapshot history with bounded undo/redo stacks. No-op edits are ignored.
  class History
    attr_reader :limit

    def initialize(limit: 100)
      raise ArgumentError, 'history limit must be positive' unless limit.positive?

      @limit = limit
      @undo = []
      @redo = []
    end

    def commit(before, after)
      return false if before == after

      @undo << deep_copy(before)
      @undo.shift while @undo.length > limit
      @redo.clear
      true
    end

    def undo(current)
      return nil if @undo.empty?

      @redo << deep_copy(current)
      @undo.pop
    end

    def redo(current)
      return nil if @redo.empty?

      @undo << deep_copy(current)
      @undo.shift while @undo.length > limit
      @redo.pop
    end

    def can_undo? = !@undo.empty?
    def can_redo? = !@redo.empty?
    def clear = (@undo.clear; @redo.clear)

    private

    def deep_copy(snapshot)
      if snapshot.is_a?(Hash)
        copy = snapshot.dup
        copy[:pixels] = snapshot.fetch(:pixels).map(&:dup) if snapshot[:pixels]
        copy[:palette] = snapshot[:palette].dup if snapshot[:palette]
        copy[:params] = snapshot[:params].dup if snapshot[:params]
        copy
      else
        snapshot.map(&:dup)
      end
    end
  end
end
