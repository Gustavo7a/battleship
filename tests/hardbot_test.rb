require 'minitest/autorun'
require_relative '../lib/models/ai/hard_bot'
require_relative '../lib/models/board'
require_relative '../lib/engine/shooting_mechanics'

class HardBotTest < Minitest::Test
  def setup
    @board = Board.new
    @bot = HardBot.new
  end

  def test_initial_state
    # Verificar se começa com a lista de navios do inimigo
    ships = @bot.instance_variable_get(:@enemy_ships_size)
    assert_equal [6, 6, 4, 4, 3, 1], ships
    # Verificar se começa com a lista de alvos vazia
    targets = @bot.instance_variable_get(:@potential_targets)
    assert_empty(targets)
  end

  def test_shoot_valid_coordinates
    # O tabuleiro está vazio ai o bot usa o heatmap para chutar
    coord = @bot.shoot(@board)

    assert_instance_of(Array, coord)
    assert_equal(2, coord.size)
    assert @board.inside_bounds?(coord[0], coord[1]), "O tiro #{coord} deve ser dentro do mapa"
  end

  def test_hit_4_neighbours
    # o primeiro tiro é no meio do mapa
    # já que não tem nenhum tiro em volta ele vai considerar a direção como :unknown
    @bot.register_hit(5,5,@board)

    targets = @bot.instance_variable_get(:@potential_targets)

    assert_equal(4, targets.size)
    assert_includes(targets, [5, 4]) # Cima
    assert_includes(targets, [5, 6]) # Baixo
    assert_includes(targets, [4, 5]) # Esq
    assert_includes(targets, [6, 5]) # Dir
  end

  def test_register_hit
    # Acerto na coordenada 0, 0.
    @bot.register_hit(0,0,@board)

    targets = @bot.instance_variable_get(:@potential_targets)

    assert_equal(2, targets.size)
    assert_includes(targets, [1, 0]) # Dir
    assert_includes(targets, [0, 1]) # Baixo

    refute_includes(targets, [-1, 0]) #fora do mapa
    refute_includes(targets, [0, -1]) #fora do mapa
  end

  def test_detect_vertical_hit
    #Definimos que tem um tiro em (5,4)
    @board.set_status(5,4, Board::HIT)

    #O bot acerta o 5,5
    @bot.register_hit(5,5,@board)

    targets = @bot.instance_variable_get(:@potential_targets)

    assert_includes(targets, [5, 6]) #Tiro na vertical

    refute_includes(targets, [4, 5], "Deveria focar na vertical")
    refute_includes(targets, [6, 5], "Deveria focar na vertical")
  end

  def test_detect_horizontal_hit
    #Definimos que tem um tiro em (4,5)
    @board.set_status(4,5,Board::HIT)
    #o Bot acerta em (5,5)
    @bot.register_hit(5,5,@board)

    targets = @bot.instance_variable_get(:@potential_targets)
    assert_includes(targets, [6, 5]) #Tiro na horizontal
    refute_includes(targets, [5, 4], "Deveria focar na horizontal")
    refute_includes(targets, [5, 6], "Deveria focar na horizontal")
  end

  def test_shoot_priorize_potentialtargets
    #Adicionando um alvo potencial na lista do bot
    @bot.instance_variable_set(:@potential_targets, [[9, 9]])

    #Ele deve retornar [9,9] na hora, ignorando qualquer calculo
    coord = @bot.shoot(@board)
    assert_equal([9,9], coord)

    assert_empty(@bot.instance_variable_get(:@potential_targets))
  end

  def test_skip_hits
    #O bot tem o alvo [5,5], mas essa coordenada já foi atingida
    @bot.instance_variable_set(:@potential_targets, [[5, 5]])
    @board.set_status(5,5, Board::HIT)
    #O bot tem que ignorar essa coordenada e calcular uma nova coordenada
    coord = @bot.shoot(@board)
    refute_equal([5, 5], coord, "Não deveria atirar onde já é HIT")
    assert(@board.inside_bounds?(coord[0], coord[1]))
  end

  def test_remove_ships
    #A pilha começa com alvos
    @bot.instance_variable_set(:@potential_targets, [[1, 2], [3, 4]])

    #pegando a quantidade inicial de navios que o bot sabe que existe
    initial_ships = @bot.instance_variable_get(:@enemy_ships_size).count(6)

    #Registra que afundou um navio de tamanho 6
    @bot.register_sunk(6)

    #Tem que limpar da pilha
    assert_empty(@bot.instance_variable_get(:@potential_targets))
    #verificar se removeu o navio de tamanho 6
    current_ships_count = @bot.instance_variable_get(:@enemy_ships_size).count(6)
    assert_equal(initial_ships - 1, current_ships_count)
  end
end
