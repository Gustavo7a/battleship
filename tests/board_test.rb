require 'minitest/autorun'
require_relative '../lib/models/board'
require_relative '../lib/models/ships/ship'
require_relative '../lib/models/ships/submarine'
require_relative '../lib/engine/shooting_mechanics'

class BoardTest < Minitest::Test
  def setup
    @tabuleiro = Board.new
    @submarino = Submarine.new
    @tiro = ShootingMechanics.new(@tabuleiro)
  end

  def test_posicionar_e_atirar
    # [1] Posicionando
    foi_posicionado = @tabuleiro.place_ship(@submarino, 5, 5, :horizontal)
    assert(foi_posicionado, "Erro: O método place_ship deveria retornar true")

    # [2] Verificando o alvo antes do tiro
    alvo = @tabuleiro.status_at(5, 5)

    # assert_kind_of verifica se o objeto é da classe Ship (ou filha dela)
    assert_kind_of(Ship, alvo, "Erro: Deveria ter um objeto do tipo Ship na posição 5,5")

    # [3] Simulando o tiro
    alvo.receive_hit
    @tabuleiro.set_status(5, 5, Board::HIT)

    # [4] Validação dos hits
    assert_equal(1, @submarino.hits, "Erro: O submarino deveria ter levado 1 dano")

    # Valida se o tabuleiro ficou marcado
    assert_equal(Board::HIT, @tabuleiro.status_at(5, 5), "Erro: O tabuleiro deveria mostrar HIT")
  end

  def test_tiro_na_agua
    # Atirando no 0,0 onde não tem nada
    alvo = @tabuleiro.status_at(0, 0)
    # refute é oposto ao assert
    refute_kind_of(Ship, alvo, "Não deveria ter navio aqui")

    #@tabuleiro.set_status(0, 0, Board::MISS)
    @tiro.shoot(0, 0)
    assert_equal(Board::MISS, @tabuleiro.status_at(0, 0))
  end

end