# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/dapple/history'

class HistorySpec < Minitest::Test
  def test_undo_and_redo_round_trip
    history = Dapple::History.new(limit: 3)
    a = [[nil]]
    b = [['#112233']]
    assert history.commit(a, b)
    assert_equal a, history.undo(b)
    assert_equal b, history.redo(a)
  end

  def test_noop_edits_do_not_consume_history
    history = Dapple::History.new
    assert_equal false, history.commit([[nil]], [[nil]])
    assert_equal false, history.can_undo?
  end

  def test_redo_is_cleared_by_a_new_edit
    history = Dapple::History.new
    a = [[nil]]
    b = [['#111111']]
    c = [['#222222']]
    history.commit(a, b)
    history.undo(b)
    history.commit(a, c)
    assert_equal false, history.can_redo?
  end

  def test_dimension_snapshots_are_copied
    history = Dapple::History.new
    before = { width: 1, height: 1, pixels: [[nil]], params: { octaves: 2 } }
    after = { width: 2, height: 2, pixels: [[nil, nil], [nil, nil]], params: { octaves: 3 } }
    history.commit(before, after)
    before[:pixels][0][0] = '#FFFFFF'
    assert_nil history.undo(after)[:pixels][0][0]
  end
end
