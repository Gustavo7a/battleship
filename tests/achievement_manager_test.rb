require 'minitest/autorun'
require_relative '../lib/engine/achievement_manager'
require_relative '../lib/models/ships/ship'
require_relative '../lib/models/ships/battleship'
require_relative '../lib/models/ships/submarine'
require_relative '../lib/models/ships/flattop'
require_relative '../lib/models/ships/warship'

class AchievementManagerTest < Minitest::Test
  def setup
    @am = AchievementManager.new
    @am.instance_variable_set(:@unlocked_achievements, [])  # limpa saves
    @am.reset_session
  end

  # --- Almirante ---
  def test_almirante_unlocked_when_no_ships_lost
    fleet = [Battleship.new, Submarine.new]  # todos Intact
    @am.register_victory(fleet)
    assert @am.unlocked?(:almirante), "Deveria desbloquear Almirante"
  end

  def test_almirante_not_unlocked_when_ship_destroyed
    ship = Battleship.new
    ship.instance_variable_set(:@status, :Destroyed)
    fleet = [ship, Submarine.new]
    @am.register_victory(fleet)
    refute @am.unlocked?(:almirante), "Não deveria desbloquear Almirante"
  end

  # --- Capitão de Mar e Guerra ---
  def test_capitao_mar_guerra_after_8_consecutive_hits
    ship = Battleship.new
    8.times { @am.register_shot(:DAMAGED, ship) }
    assert @am.unlocked?(:capitao_mar_guerra), "Deveria desbloquear Capitão de Mar e Guerra"
  end

  def test_capitao_mar_guerra_not_unlocked_with_miss_in_between
    ship = Battleship.new
    7.times { @am.register_shot(:DAMAGED, ship) }
    @am.register_shot(:WATER, nil)
    @am.register_shot(:DAMAGED, ship)
    refute @am.unlocked?(:capitao_mar_guerra), "Não deveria desbloquear sem 8 consecutivos"
  end

  def test_consecutive_hits_reset_on_water
    ship = Battleship.new
    5.times { @am.register_shot(:DAMAGED, ship) }
    @am.register_shot(:WATER)
    assert_equal 0, @am.consecutive_hits, "Contador deve zerar no tiro na água"
  end

  # --- Capitão ---
  def test_capitao_unlocked_after_7_different_ship_types
    type_names = %w[TypeA TypeB TypeC TypeD TypeE TypeF TypeG]
    type_names.each do |type_name|
      ship_class = Object.const_set(type_name, Class.new(Ship) { def initialize; super(2) end })
      @am.register_shot(:DAMAGED, ship_class.new)
    end
    assert @am.unlocked?(:capitao), "Deveria desbloquear Capitão"
  end

  def test_capitao_streak_resets_on_miss
    @am.register_shot(:DAMAGED, Flattop.new)
    @am.register_shot(:WATER)
    assert_equal [], @am.ship_types_hit_streak
  end

  # --- Marinheiro ---
  def test_marinheiro_unlocked_within_time_limit
    @am.instance_variable_set(:@game_start_time, Time.now - 60)  # 1 minuto
    @am.register_victory([])
    assert @am.unlocked?(:marinheiro), "Deveria desbloquear Marinheiro (dentro do limite)"
  end

  def test_marinheiro_not_unlocked_after_time_limit
    @am.instance_variable_set(:@game_start_time, Time.now - 200)  # 200s > 180s
    @am.register_victory([])
    refute @am.unlocked?(:marinheiro), "Não deveria desbloquear Marinheiro (fora do limite)"
  end
end


