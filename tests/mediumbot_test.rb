require 'minitest/autorun'
require_relative '../lib/models/ai/medium_bot'
require_relative '../lib/models/board'
require_relative '../lib/models/ships/warship'

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

    # Bloqueia tudo menos (5,5) e seus vizinhos
    neighbors = [[5,4], [5,6], [4,5], [6,5]]
    10.times do |x|
      10.times do |y|
        next if x == 5 and y == 5
        next if neighbors.include?([x,y])
        @opponent_board.set_status(x, y, Board::MISS)
      end
    end

    # Faz a IA atirar até acertar (5,5)
    loop do
      x, y = @ai.shoot(@opponent_board)
      if x == 5 && y == 5
        ship.receive_hit
        @opponent_board.set_status(x, y, Board::HIT)
        # Notifica o bot sobre o acerto (como o TurnManager faria)
        @ai.register_hit(x, y, @opponent_board)
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

  def test_register_sunk_clears_target_queue
    ship = Warship.new
    @opponent_board.place_ship(ship, 3, 3, :horizontal)

    # Notifica o acerto antes de marcar HIT no board (vizinhos ainda são válidos)
    @ai.register_hit(3, 3, @opponent_board)
    @opponent_board.set_status(3, 3, Board::HIT)

    queue = @ai.instance_variable_get(:@target_queue)
    refute_empty(queue, "Após acerto, a fila de alvos não pode estar vazia")

    # Simula destruição do navio
    @ai.register_sunk(ship.ship_size)

    assert_empty(queue, "Após afundar, a fila de alvos deve ser limpa")
    assert_nil(@ai.instance_variable_get(:@first_hit), "Após afundar, @first_hit deve ser nil")
  end

  def test_skip_already_hit_targets_in_queue
    # Coloca um alvo na fila que já foi atingido
    @ai.instance_variable_set(:@target_queue, [[5, 5]])
    @opponent_board.set_status(5, 5, Board::HIT)

    coord = @ai.shoot(@opponent_board)
    refute_equal([5, 5], coord, "Não deve atirar onde já é HIT")
    assert(@opponent_board.inside_bounds?(coord[0], coord[1]))
  end

  def test_axis_filtering_horizontal
    ship = Warship.new
    @opponent_board.place_ship(ship, 3, 5, :horizontal)

    # Primeiro acerto em (3,5)
    @opponent_board.set_status(3, 5, Board::HIT)
    @ai.register_hit(3, 5, @opponent_board)

    # Segundo acerto em (4,5) — mesmo Y → horizontal
    @opponent_board.set_status(4, 5, Board::HIT)
    @ai.register_hit(4, 5, @opponent_board)

    queue = @ai.instance_variable_get(:@target_queue)
    # Todos os alvos na fila devem ter y == 5 (horizontal)
    queue.each do |qx, qy|
      assert_equal(5, qy, "Após detectar eixo horizontal, fila deve ter apenas alvos na mesma linha")
    end
  end
end