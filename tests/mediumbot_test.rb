require 'minitest/autorun'
require_relative '../lib/models/ai/medium_bot'
require_relative '../lib/models/board'

class MediumBotTest < Minitest::Test
  def setup
    @ai = MediumBot.new
    @opponent_board = Board.new
  end

  def test_hunt_mode_is_random
    10.times do |x|
      10.times do |y|
        next if x == 5 && y == 5
        @opponent_board.set_status(x, y, Board::MISS)
      end
    end

    x, y = @ai.shoot(@opponent_board)
    assert_equal([5,5], [x, y], "Se só sobrar uma casa, o modo aleatório deve acha-la")
  end

  def test_return_valid_position
    position = @ai.shoot(@opponent_board)

    assert_instance_of(Array, position, "O retorno deve ser um array [x,y]")
    assert_equal(2, position.size, "O array tem que ter 2 elementos")

    x = position[0]
    y = position[1]

    assert_includes(0..9, x, "X deve estar dentro do limites do tabuleiro")
    assert_includes(0..9, y, "Y deve estar dentro dos limites do tabuleiro")

  end

  def test_dont_shoot_repeated_position
    10.times do |x|
      10.times do |y|
        next if x == 5 and y == 5

        @opponent_board.set_status(x, y, Board::MISS)
      end
    end
    ia_shoot = @ai.shoot(@opponent_board)
    assert_equal([5,5], ia_shoot, "A IA tem que encontrar a coordenada (5, 5)")
  end

  def test_intelligence_queues_neighbors_after_hit
    ship = Warship.new
    @opponent_board.place_ship(ship, 5, 5, :horizontal)

    neighbors = [[5,4], [5,6], [4,5], [6,5]]

    10.times do |x|
      10.times do |y|
        next if x == 5 and y == 5
        next if neighbors.include?([x,y])
        @opponent_board.set_status(x, y, Board::MISS)
      end
    end
    loop do
      x, y = @ai.shoot(@opponent_board)
      if x == 5 && y == 5
        ship.receive_hit
        @opponent_board.set_status(x, y, Board::HIT)
        break
      else
        @opponent_board.set_status(x, y, Board::MISS)
      end
    end
    next_shot = @ai.shoot(@opponent_board)
    valid_neighbors = neighbors.select do |vx, vy|
      @opponent_board.status_at(vx, vy) != Board::MISS
    end
    assert_includes(valid_neighbors, next_shot, "Após acertar o navio, o próximo tiro deve ser um dos vizinhos disponíveis (Modo Alvo)")
  end
end