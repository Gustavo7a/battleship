require 'minitest/autorun'
require_relative '../lib/models/board'
require_relative '../lib/models/ai/easy_bot'

class EasyBotTest < Minitest::Test
  def setup
    @ai = EasyBot.new
    @opponent_board = Board.new
  end

  def test_return_valid_position
    position = @ai.shoot(@opponent_board)

    assert_instance_of(Array, position, "O retorno deve ser um array [x,y]")
    assert_equal(2, position.size, "O array tem que ter 2 elementos")

    x = position[0]
    y = position[1]

    assert_includes(0..9, x, "X deve estar dentro dos limites do tabuleiro")
    assert_includes(0..9, y, "Y deve estar dentro do limites do tabuleiro")
  end

  def test_dont_shoot_repeated_position
    10.times do |x|
      10.times do |y|
        # Pula a coordenada (5,5)
        next if x == 5 and y == 5

        @opponent_board.set_status(x, y, Board::MISS)
      end
    end
    ia_shoot = @ai.shoot(@opponent_board)
    assert_equal([5,5], ia_shoot, "A IA tem que encontrar a coordenada (5,5)")
  end

end

