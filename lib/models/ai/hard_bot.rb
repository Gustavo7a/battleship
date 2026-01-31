require_relative '../board'
require_relative 'base_ai'

# Implementação do bot difícil
#
# Esse bot depende dos seguintes modos:
# 1. Modo procura: Utiliza um algoritmo de mapa de densidade de probabilidade.
#   Ele simula todas as posições possíveis para os navios restantes e gera um heatmap,
#   atirando na coordenada com maior chance de conter um navio.
# 2. Modo alvo: Ativado após acertar {register_hit}.
#   Empilha os vizinhos do alvo atingido e atira neles até afundar o navio.
#
# @see BaseAI Para entender o funcionamento do HardBot.
#
# @author Jurandir Neto
class HardBot < BaseAI

  # Inicializa o HardBot.
  #
  # Define a lista de navios do inimigo para calcular a probabilidade
  # e prepara a pilha de alvos potenciais.
  #
  # @note A lista @enemy_ships_size define os navios que o bot vai procurar.
  #   Conforme navios são afundados pelo {register_sunk}, eles são removidos dessa lista.
  def initialize
    super
    @enemy_ships_size = [6, 6, 4, 4, 3, 1]
    @potential_targets = []
  end

  # Decide a coordenada do próximo tiro.
  #
  # A lógica para decidir funciona assim:
  # 1. Se tiver alvos pendentes na pilha @potential_targets, processa o modo alvo.
  # 2. Caso contrário, calcula o mapa de probabilidade e executa o modo de procura.
  #
  # @param opponent_board [Board] O tabuleiro do oponente para análise de tiros anteriores.
  # @return [Array<Integer>] Um array [x, y] com as coordenadas do tiro escolhido.
  def shoot(opponent_board)

    return process_targets(opponent_board) unless @potential_targets.empty?

    probability_grid = calculate_probability_map(opponent_board)
    best_move = find_highest_probability(probability_grid)

    best_move
  end

  # Registra um acerto (HIT) e adiciona os vizinhos à lista de alvos.
  #
  # Agora utiliza inteligência espacial através do metodo {detect_direction}:
  # * Se detectar um padrão *Horizontal*, adiciona apenas vizinhos da Esquerda/Direita.
  # * Se detectar um padrão *Vertical*, adiciona apenas vizinhos de Cima/Baixo.
  # * Se não houver padrão claro (:unknown), adiciona todos os 4 vizinhos.
  #
  # @param x [Integer] Coordenada X do acerto.
  # @param y [Integer] Coordenada Y do acerto.
  # @param opponent_board [Board] Tabuleiro para validar quais vizinhos são válidos.
  # @return [void]
  def register_hit(x, y, opponent_board)
    direction = detect_direction(opponent_board, x, y)

    if direction == :horizontal || direction == :unknown
      add_valid_neighbor(x - 1, y, opponent_board) # Esq
      add_valid_neighbor(x + 1, y, opponent_board) # Dir
    end

    if direction == :vertical || direction == :unknown
      add_valid_neighbor(x, y - 1, opponent_board) # Baixo
      add_valid_neighbor(x, y + 1, opponent_board) # Cima
    end
  end

  # Registra que um navio foi afundado (DESTROYED).
  #
  # Realiza duas ações:
  # 1. Limpa a pilha de alvos potenciais, pois o navio focado já morreu.
  # 2. Remove o tamanho do navio da lista @enemy_ships_size, ajustando o cálculo
  #    de probabilidade para ignorar navios desse tamanho nos próximos turnos.
  #
  # @param ship_size [Integer] O tamanho do navio que acabou de afundar.
  # @return [void]
  def register_sunk(ship_size)
    @potential_targets.clear

    index = @enemy_ships_size.index(ship_size)

    if index
      @enemy_ships_size.delete_at(index)
    else
      puts "Tentou remover navio de tamanho #{ship_size} que não está na lista"
    end
  end


    private

  # Gera uma matriz 10x10 para fazer o Heatmap.
  #
  # Itera sobre cada tamanho de navio restante em @enemy_ships_size.
  # Para cada navio, testa todas as posições possíveis no tabuleiro (Horizontal e Vertical).
  # Cada posição válida incrementa o valor das células correspondentes na matriz.
  #
  # @param board [Board] O tabuleiro atual com o histórico de tiros.
  # @return [Array<Array<Integer>>] Matriz 10x10 onde valores mais altos indicam maior probabilidade.
  def calculate_probability_map(board)

    heatmap = Array.new(10) {Array.new(10, 0)}

    @enemy_ships_size.each do |size|

      10.times do |y|
        10.times do |x|

          if can_place_ship?(board, x, y, size, :horizontal)
            (0...size).each do |i|
              heatmap[y][x + i] += 1
            end
          end
          if can_place_ship?(board, x, y, size, :vertical)
            (0...size).each do |i|
              heatmap[y + i][x] += 1
            end
          end
        end
      end
    end
    heatmap
  end

  # Verifica se é possível posicionar um navio em uma coordenada.
  #
  # Valida se o navio:
  # 1. Cabe dentro dos limites do mapa (0..9).
  # 2. Não sobrepõe nenhum tiro já realizado ({Board::MISS} ou {Board::HIT}).
  #
  # @param board [Board] O tabuleiro.
  # @param x [Integer] Coordenada X inicial.
  # @param y [Integer] Coordenada Y inicial.
  # @param size [Integer] Tamanho do navio.
  # @param orientation [Symbol] :horizontal ou :vertical.
  # @return [Boolean] true se o navio cabe, false caso contrário.
  def can_place_ship?(board, x, y, size, orientation)
    if orientation == :horizontal
      return false if (x + size) > 10
      (0...size).each do |i|
        content = board.status_at(x + i,y)
        return false if content == Board::MISS || content == Board::HIT
      end
    else # vertical
      return false if (y + size) > 10
      (0...size).each do |i|
        content = board.status_at(x,y + i)
        return false if content == Board::MISS || content == Board::HIT
      end
    end
    true
  end

  # Encontra a coordenada com a maior probabilidade no heatmap.
  #
  # Varre a matriz em busca do maior valor. Em caso de empate (várias células
  # com a mesma probabilidade máxima), armazena todas e sorteia uma aleatoriamente.
  #
  # @param grid [Array<Array<Integer>>] A matriz de calor gerada por {calculate_probability_map}.
  # @return [Array<Integer>] A coordenada [x, y] escolhida.
  def find_highest_probability(grid)

    biggest_probability = -1
    best_position = []
    10.times do |y|
      10.times do |x|
        current_prob = grid[y][x]

        if current_prob > biggest_probability
          biggest_probability = current_prob
          best_position = [[x, y]]
        elsif current_prob == biggest_probability
          best_position << [x,y]
        end
      end
    end
    best_position.sample
  end

  # Processa a pilha de alvos potenciais (Modo Alvo).
  #
  # Retira o último alvo da pilha. Se esse alvo já foi atingido anteriormente,
  # ele é descartado e o metodo tenta o próximo recursivamente.
  #
  # @param opponent_board [Board] O tabuleiro.
  # @return [Array<Integer>] A coordenada do alvo válido.
  def process_targets(opponent_board)

    target = @potential_targets.pop
    status = opponent_board.status_at(target[0], target[1])

    if status == Board::HIT || status == Board::MISS
      return shoot(opponent_board)
    end
    target
  end

  # Adiciona um vizinho válido na lista de alvos potenciais.
  #
  # Só adiciona a coordenada se ela estiver dentro do tabuleiro e ainda
  # não tiver sido alvo de um tiro (nem HIT nem MISS).
  #
  # @param x [Integer] Coordenada X.
  # @param y [Integer] Coordenada Y.
  # @param board [Board] O tabuleiro para validação.
  def add_valid_neighbor(x, y, board)
    if board.inside_bounds?(x, y)
      content = board.status_at(x,y)
      if content != Board::HIT && content != Board::MISS
        @potential_targets << [x, y] unless @potential_targets.include?([x,y])
      end
    end
  end

  # Tenta determinar a orientação do navio baseado em acertos vizinhos.
  #
  # Verifica se existe um HIT imediatamente ao lado ou acima/abaixo da coordenada atual.
  #
  # @param board [Board] O tabuleiro atual.
  # @param x [Integer] Coordenada X do tiro atual.
  # @param y [Integer] Coordenada Y do tiro atual.
  # @return [Symbol] :horizontal, :vertical ou :unknown (se não houver vizinhos atingidos).
  def detect_direction(board, x, y)
    left = (x > 0 && board.status_at(x-1, y) == Board::HIT)
    right = (x < 9 && board.status_at(x+1, y) == Board::HIT)
    up = (y > 0 && board.status_at(x, y-1) == Board::HIT)
    down = (y < 9 && board.status_at(x, y+1) == Board::HIT)

    return :horizontal if left || right
    return :vertical if up || down
    :unknown
  end
end