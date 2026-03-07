require 'minitest/autorun'
require_relative '../lib/models/player'
require_relative '../lib/models/board'
require_relative '../lib/models/ships/flattop'
require_relative '../lib/models/ships/warship'
require_relative '../lib/models/ships/battleship'
require_relative '../lib/models/ships/submarine'

class PlayerTest < Minitest::Test

  def setup
    @player = Player.new(name: "Gustavo")
  end

  def test_initial_state
    assert_equal "Gustavo", @player.name
    assert_instance_of Board, @player.board
    assert_equal 6, @player.fleet.size
  end

  def test_fleet_composition
    ships = @player.fleet.map(&:class)
    assert_equal 2,ships.count(Flattop)
    assert_equal 2,ships.count(Warship)
    assert_equal 1,ships.count(Battleship)
    assert_equal 1,ships.count(Submarine)
  end

  def test_player_not_defeated_initially
    refute @player.defeated?
  end

  def test_player_defeated_when_all_ships_destroyed
    @player.fleet.each do |ship|
      ship.instance_variable_set(:@status, Ship::DESTROYED)
    end
    assert @player.defeated?
  end

  def test_reset_board_creates_new_board
    old_board = @player.board
    @player.reset_board
    refute_equal old_board, @player.board
  end

  def test_reset_board_recreates_fleet
    @player.reset_board
    assert_equal 6, @player.fleet.size
  end

  def test_shoot_returns_result
    result = @player.shoot(1,1)
    assert_instance_of Array, result
    assert_equal 2, result.size
  end
end

