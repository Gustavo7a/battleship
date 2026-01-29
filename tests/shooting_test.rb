require 'minitest/autorun'
require_relative '../lib/models/board'
require_relative '../lib/models/ships/ship'
require_relative '../lib/models/ships/submarine'
require_relative '../lib/engine/shooting_mechanics'
class ShootingTest < Minitest::Test
  def setup
    @tabuleiro = Board.new
    @submarino = Submarine.new
    @tiro = ShootingMechanics.new(@tabuleiro)
  end

  def test_tiro_repetido
    resultado = @tiro.shoot(0, 0)
    assert_equal(:WATER, resultado)
    assert_equal(Board::MISS, @tabuleiro.status_at(0, 0))

    resultado2 = @tiro.shoot(0, 0)
    assert_equal(:REPEATED, resultado2)
    assert_equal(Board::MISS, @tabuleiro.status_at(0, 0))
  end

  def test_tiro_fora_do_tabuleiro
    resultado = @tiro.shoot(-1, 0)
    assert_equal(:INVALID, resultado)
  end

  def test_acertou_tiro
    @tabuleiro.place_ship(@submarino, 5, 5, :horizontal)

    resultado = @tiro.shoot(5, 5)
    assert_equal(:DESTROYED, resultado)
    assert_equal(Board::HIT, @tabuleiro.status_at(5, 5))
    assert_equal(1, @submarino.hits)
  end
end

