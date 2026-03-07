# Representa o tabuleiro do jogo (grid 10x10).
# Responsável por armazenar o estado das células (água, navio e tiros)
# e gerenciar o posicionamento dos navios.
#
# O grid funciona assim:
# - Se a célula tiver {WATER}, {HIT} ou {MISS} ela contém um *Integer*.
# - Se a célula tiver um navio intacto ela contém a instância do objeto Ship.
#
# @author Jurandir Neto
class Board
  # @!group
  # Representa uma célula vazia (Água), o valor é 0.
  WATER = 0

  # Representa uma parte do navio que foi atingida, o valor é 2.
  HIT = 2

  # Representa um tiro na água (errado), o valor é 3.
  MISS = 3
  # @!endgroup

  #Inicializa um novo tabuleiro 10x10 preenchido com água.
  def initialize
    @grid = Array.new(10) { Array.new(10, WATER) }
  end
  # Verifica o conteúdo de uma coordenada específica.
  #
  # @param x [Integer] A coluna (0 a 9).
  # @param y [Integer] A linha (0 a 9).
  #
  # @return [Integer, Ship, nil] Retorna:
  #
  #  - {WATER},{HIT} ou {MISS} que são integers, se for água ou marcação de tiro.
  #  - O objeto {Ship} se houver um navio intacto naquela posição.
  #  - nil se as coordenadas estiverem fora do tabuleiro.
  def status_at(x, y)
    if inside_bounds?(x, y)
      @grid[y][x]
    end
  end

  #Verifica se as coordenadas estão dentro dos limites do tabuleiro (0 a 9).
  #
  # @param x [Integer] Coordenada X.
  # @param y [Integer] Coordenada Y.
  # @return [Boolean] true se válido, false se fora do mapa.
  def inside_bounds?(x, y)
    x.between?(0, 9) && y.between?(0, 9)
  end

  # Atualiza manualmente o estado de uma célula.
  # Para ser usado pela mecânica de tiro para marcar HIT ou MISS.
  #
  # @param x [Integer] Coordenada X.
  # @param y [Integer] Coordenada Y.
  # @param value [Integer] O novo valor ({HIT}, {MISS}, etc).
  # @return [void]
  def set_status(x, y, value)
    if inside_bounds?(x, y)
      @grid[y][x] = value
    end
  end

  # Tenta posicionar um navio no tabuleiro.
  #
  # Verifica se o navio passa dos limites do tabuleiro e se não sobrepõe outro navio.
  # Se o navio couber ele preenche o grid com a referência do navio (Objeto) e atualiza
  # a lista interna de posições do próprio navio.
  #
  # @param ship [Ship] A instância do navio a ser posicionado.
  # @param x [Integer] A coordenada X inicial da frente do navio.
  # @param y [Integer] A coordenada Y inicial da frente do navio.
  # @param orientation [Symbol] A orientação: `:horizontal` ou `:vertical`.
  #
  # @return [Boolean] true se o navio foi posicionado com sucesso, false se a posição for inválida.
  #
  # @example Posicionando um submarino.
  #   board.place_ship(submarine, 0, 0, :horizontal) #=> true
  def place_ship(ship, x, y, orientation)
    return false unless valid_position?(ship, x, y, orientation)

    size = ship.ship_size

    if orientation == :horizontal
      (0...size).each do |i|
        @grid[y][x + i] = ship
        ship.positions << [x + i, y]
      end
    else # vertical
      (0...size).each do |i|
        @grid[y + i][x] = ship
        ship.positions << [x, y + i]
      end
    end
    true
  end

  # Move um navio uma casa na direção indicada.
  #
  # Valida se as novas posições estão dentro do tabuleiro e não sobrepõem
  # outro navio. Navios destruídos não podem ser movidos.
  #
  # @param ship [Ship] o navio a ser movido.
  # @param direction [Symbol] direção do movimento: `:up`, `:down`, `:left` ou `:right`.
  # @return [Boolean] true se o movimento foi aplicado, false se inválido.
  #
  # @example
  #   board.move_ship(submarine, :right) #=> true
  def move_ship(ship, direction)
    return false if ship.status == Ship::DESTROYED

    dx, dy = direction_delta(direction)
    new_positions = ship.positions.map { |x, y| [x + dx, y + dy] }

    return false unless valid_move?(new_positions, ship)

    # Remove navio das células atuais
    ship.positions.each { |x, y| @grid[y][x] = WATER }

    # Aplica nas novas células
    ship.move_to(new_positions)
    new_positions.each { |x, y| @grid[y][x] = ship }

    true
  end

  private

  # Retorna o delta [dx, dy] para cada direção.
  # @api private
  def direction_delta(direction)
    case direction
    when :up    then [0, -1]
    when :down  then [0,  1]
    when :left  then [-1, 0]
    when :right then [1,  0]
    else [0, 0]
    end
  end

  # Verifica se as novas posições são válidas para o movimento.
  # Células que já pertencem ao próprio navio (antes de mover) são permitidas.
  #
  # @api private
  def valid_move?(new_positions, ship)
    new_positions.all? do |x, y|
      inside_bounds?(x, y) &&
        (@grid[y][x] == WATER || ship.positions.include?([x, y]))
    end
  end

  # Verifica se o navio pode ser colocado na posição desejada.
  #
  # Checa limites do mapa e se as células já estão ocupadas.
  #
  # @api private
  # @param (ver #place_ship)
  # @return [Boolean]
  def valid_position?(ship, x, y, orientation)
    size = ship.ship_size

    if orientation == :horizontal
      return false unless inside_bounds?(x + size - 1, y)
      (0...size).each do |i|
        return false if @grid[y][x + i] != WATER
      end
    else # vertical
      return false unless inside_bounds?(x, y + size - 1)
      (0...size).each do |i|
        return false if @grid[y + i][x] != WATER
      end
    end
    true
  end
end