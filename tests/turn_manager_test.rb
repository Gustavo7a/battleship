require 'minitest/autorun'
require_relative '../lib/engine/turn_manager'
require_relative '../lib/models/player'
require_relative '../lib/models/ai/easy_bot'
require_relative '../lib/models/ai/medium_bot'
require_relative '../lib/models/ai/hard_bot'
require_relative '../lib/models/board'
require_relative '../lib/models/ships/ship'

# Posiciona todos os navios de uma frota de forma aleatória no tabuleiro
def place_fleet(board, fleet)
  fleet.each do |ship|
    loop do
      x           = rand(10)
      y           = rand(10)
      orientation = [:horizontal, :vertical].sample
      break if board.place_ship(ship, x, y, orientation)
    end
  end
end

class TurnManagerTest < Minitest::Test

  def setup
    @player = Player.new(name: "Tester")
    @ai     = EasyBot.new

    # Posiciona as frotas manualmente para que os tiros sejam previsíveis
    place_fleet(@player.board, @player.fleet)
    @ai.setup_ships

    @tm = TurnManager.new(@player, @ai)
  end

  # Turno inicial

  def test_starts_with_player_turn
    assert_equal :player, @tm.current_turn, "A partida deve começar no turno do jogador"
  end

  # Tiro inválido / fora dos limites

  def test_player_shoot_out_of_bounds_returns_invalid
    result = @tm.player_shoot(10, 10)
    assert_equal :INVALID, result
  end

  def test_player_shoot_out_of_bounds_keeps_player_turn
    @tm.player_shoot(-1, 0)
    assert_equal :player, @tm.current_turn, "Tiro inválido não deve mudar o turno"
  end

  # Tiro repetido mantém o turno

  def test_repeated_shot_keeps_player_turn
    # Força MISS em (0,0) para garantir que a célula esteja marcada
    @ai.board.set_status(0, 0, Board::MISS)
    result = @tm.player_shoot(0, 0)
    assert_equal :REPEATED, result
    assert_equal :player, @tm.current_turn, "Tiro repetido não deve mudar o turno"
  end

  # Acerto mantém turno do jogador

  def test_hit_keeps_player_turn
    # Encontra uma célula com navio no tabuleiro da IA
    hit_x, hit_y = find_ship_cell(@ai.board)
    skip "Nenhuma célula de navio encontrada" if hit_x.nil?

    result = @tm.player_shoot(hit_x, hit_y)
    assert_includes [:DAMAGED, :DESTROYED], result
    assert_equal :player, @tm.current_turn, "Acerto deve manter o turno no jogador"
  end

  # Errar passa o turno para a IA

  def test_miss_passes_turn_to_ai
    water_x, water_y = find_water_cell(@ai.board)
    skip "Nenhuma célula de água encontrada" if water_x.nil?

    result = @tm.player_shoot(water_x, water_y)
    assert_equal :WATER, result
    assert_equal :ai, @tm.current_turn, "Erro deve passar o turno para a IA"
  end

  # Turno da IA

  def test_ai_turn_returns_array_with_result
    # Força turno da IA
    water_x, water_y = find_water_cell(@ai.board)
    skip "Nenhuma água encontrada" if water_x.nil?
    @tm.player_shoot(water_x, water_y)   # joga água → passa para IA

    assert_equal :ai, @tm.current_turn
    result, ship, x, y = @tm.ai_turn

    assert_includes [:WATER, :DAMAGED, :DESTROYED], result
    assert_includes 0..9, x
    assert_includes 0..9, y
  end

  def test_ai_miss_returns_turn_to_player
    water_x, water_y = find_water_cell(@ai.board)
    skip "Nenhuma água encontrada" if water_x.nil?
    @tm.player_shoot(water_x, water_y)

    # Repete até a IA errar (máx 200 tentativas)
    200.times do
      break if @tm.current_turn == :player || @tm.game_over?
      @tm.ai_turn
    end

    # Após a IA errar, o turno deve voltar ao jogador (ou o jogo acabou)
    assert @tm.current_turn == :player || @tm.game_over?,
           "Após erro da IA o turno deve voltar ao jogador (ou o jogo terminou)"
  end

  # Fim de jogo

  def test_game_not_over_initially
    refute @tm.game_over?, "Jogo não pode estar encerrado no início"
  end

  def test_player_wins_when_all_ai_ships_destroyed
    sink_all_ships(@ai.board, @ai.fleet, @tm, :player)
    assert @tm.game_over?,  "Jogo deve estar encerrado"
    assert @tm.ai_defeated?, "IA deve estar derrotada"
    assert_equal :player, @tm.winner
  end

  def test_ai_wins_when_all_player_ships_destroyed
    sink_all_ships(@player.board, @player.fleet, @tm, :ai)
    assert @tm.game_over?,      "Jogo deve estar encerrado"
    assert @tm.player_defeated?, "Jogador deve estar derrotado"
    assert_equal :ai, @tm.winner
  end

  def test_winner_nil_when_game_in_progress
    assert_nil @tm.winner, "winner deve ser nil enquanto o jogo está em andamento"
  end

  # Campanha: diferentes bots

  def test_turn_manager_works_with_medium_bot
    player = Player.new(name: "P")
    ai     = MediumBot.new
    place_fleet(player.board, player.fleet)
    ai.setup_ships
    tm = TurnManager.new(player, ai)

    assert_equal :player, tm.current_turn
    refute tm.game_over?
  end

  def test_turn_manager_works_with_hard_bot
    player = Player.new(name: "P")
    ai     = HardBot.new
    place_fleet(player.board, player.fleet)
    ai.setup_ships
    tm = TurnManager.new(player, ai)

    assert_equal :player, tm.current_turn
    refute tm.game_over?
  end

  private

  # Retorna [x, y] de uma célula com navio no tabuleiro dado, ou [nil, nil]
  def find_ship_cell(board)
    10.times do |y|
      10.times do |x|
        c = board.status_at(x, y)
        return [x, y] if c.is_a?(Ship) && c.status != Ship::DESTROYED
      end
    end
    [nil, nil]
  end

  # Retorna [x, y] de uma célula com água (WATER) no tabuleiro dado, ou [nil, nil]
  def find_water_cell(board)
    10.times do |y|
      10.times do |x|
        return [x, y] if board.status_at(x, y) == Board::WATER
      end
    end
    [nil, nil]
  end

  # Afunda toda uma frota diretamente (manipulando o tabuleiro), sem passar pelo TurnManager
  # para não depender da lógica de turnos em si.
  def sink_all_ships(board, fleet, tm, perspective)
    fleet.each do |ship|
      ship.positions.each do |sx, sy|
        board.set_status(sx, sy, Board::HIT)
        ship.receive_hit
      end
    end
  end
end

