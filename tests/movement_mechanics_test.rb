require 'minitest/autorun'
require_relative '../lib/models/board'
require_relative '../lib/models/ships/ship'
require_relative '../lib/models/ships/submarine'
require_relative '../lib/models/ships/warship'
require_relative '../lib/engine/movement_mechanics'

# Testa a mecânica de movimentação de navios antes do disparo.
# @author José Gustavo
class MovementMechanicsTest < Minitest::Test

  def setup
    @board    = Board.new
    # Submarine tem size=1 (1 célula) — posicionado em [5,5]
    @sub      = Submarine.new
    @board.place_ship(@sub, 5, 5, :horizontal)
    @mechanics = MovementMechanics.new(@board)
  end

  # ── new_turn ──────────────────────────────────────────────────────────────

  def test_already_moved_false_no_inicio_do_turno
    refute @mechanics.already_moved?
  end

  def test_new_turn_reseta_flag_de_movimento
    @mechanics.move(@sub, :right)
    @mechanics.new_turn
    refute @mechanics.already_moved?, "new_turn deve liberar o movimento"
  end

  # ── move válido ───────────────────────────────────────────────────────────

  def test_move_retorna_moved_quando_valido
    result = @mechanics.move(@sub, :up)
    assert_equal :moved, result
  end

  def test_posicoes_do_navio_sao_atualizadas_apos_movimento
    # Submarine size=1: posição única [5,5] → move para cima → [5,4]
    @mechanics.move(@sub, :up)
    assert_includes @sub.positions, [5, 4]
  end

  def test_celulas_antigas_ficam_com_water_apos_movimento
    @mechanics.move(@sub, :up)
    assert_equal Board::WATER, @board.status_at(5, 5)
  end

  def test_celulas_novas_ficam_com_o_navio_apos_movimento
    @mechanics.move(@sub, :up)
    assert_equal @sub, @board.status_at(5, 4)
  end

  def test_already_moved_true_apos_mover
    @mechanics.move(@sub, :right)
    assert @mechanics.already_moved?
  end

  # ── bloqueio de segundo movimento ─────────────────────────────────────────

  def test_segundo_movimento_retorna_already_moved
    @mechanics.move(@sub, :up)
    result = @mechanics.move(@sub, :left)
    assert_equal :already_moved, result
  end

  def test_posicao_nao_muda_no_segundo_movimento_bloqueado
    @mechanics.move(@sub, :up)
    positions_after_first = @sub.positions.dup
    @mechanics.move(@sub, :left)
    assert_equal positions_after_first, @sub.positions
  end

  # ── colisão ───────────────────────────────────────────────────────────────

  def test_colisao_com_outro_navio_retorna_collision
    # Coloca outro navio diretamente acima do sub (em [5,4])
    outro = Submarine.new
    @board.place_ship(outro, 5, 4, :horizontal)

    result = @mechanics.move(@sub, :up)
    assert_equal :collision, result
  end

  def test_posicao_nao_muda_em_colisao
    outro = Submarine.new
    @board.place_ship(outro, 5, 4, :horizontal)

    @mechanics.move(@sub, :up)
    # sub permanece em [5,5]
    assert_includes @sub.positions, [5, 5]
  end

  # ── fora dos limites ──────────────────────────────────────────────────────

  def test_fora_dos_limites_retorna_out_of_bounds
    sub2      = Submarine.new
    board2    = Board.new
    board2.place_ship(sub2, 0, 9, :horizontal)   # célula [0,9] — borda inferior
    mech2 = MovementMechanics.new(board2)

    result = mech2.move(sub2, :down)
    assert_equal :out_of_bounds, result
  end

  # ── navio destruído ───────────────────────────────────────────────────────

  def test_navio_destruido_nao_pode_mover
    @sub.ship_size.times { @sub.receive_hit }   # afunda o submarino
    result = @mechanics.move(@sub, :up)
    assert_equal :already_destroyed, result
  end

  # ── direção inválida ──────────────────────────────────────────────────────

  def test_direcao_invalida_retorna_invalid_direction
    result = @mechanics.move(@sub, :diagonal)
    assert_equal :invalid_direction, result
  end

  # ── movimento com navio maior (Warship, size=3) ───────────────────────────

  def test_warship_move_horizontal_atualiza_todas_as_celulas
    board2 = Board.new
    war    = Warship.new                         # size=3
    board2.place_ship(war, 2, 2, :horizontal)    # [2,2],[3,2],[4,2]
    mech2  = MovementMechanics.new(board2)

    result = mech2.move(war, :down)
    assert_equal :moved, result
    assert_includes war.positions, [2, 3]
    assert_includes war.positions, [3, 3]
    assert_includes war.positions, [4, 3]
    assert_equal Board::WATER, board2.status_at(2, 2)
    assert_equal war, board2.status_at(2, 3)
  end
end

