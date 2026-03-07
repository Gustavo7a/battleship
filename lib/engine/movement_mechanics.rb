require_relative '../models/board'
require_relative '../models/ships/ship'

# Encapsula a mecânica de movimentação de navios antes do disparo.
#
# Regras:
# - Apenas navios INTACT (sem nenhum acerto) podem ser movidos.
# - Mover um navio CONSOME o turno inteiro — quem move NÃO atira.
# - Cada lado pode mover NO MÁXIMO um navio por turno.
#
# @author Implementação - mecânica de movimento
class MovementMechanics
  # Possíveis resultados de uma tentativa de movimento
  RESULTS = [:moved, :invalid_direction, :out_of_bounds, :collision,
             :already_destroyed, :damaged_ship, :already_moved].freeze

  # @param board [Board] tabuleiro onde o navio está posicionado
  def initialize(board)
    @board           = board
    @moved_this_turn = false
  end

  # Marca o início de um novo turno, liberando o movimento.
  # @return [void]
  def new_turn
    @moved_this_turn = false
  end

  # Indica se o movimento já foi usado neste turno (logo, o disparo está bloqueado).
  # @return [Boolean]
  def already_moved?
    @moved_this_turn
  end

  # Tenta mover um navio uma casa na direção especificada.
  #
  # @param ship [Ship] o navio que se deseja mover.
  # @param direction [Symbol] `:up`, `:down`, `:left` ou `:right`.
  # @return [Symbol] resultado do movimento (ver {RESULTS}).
  def move(ship, direction)
    return :invalid_direction unless valid_directions.include?(direction)
    return :already_moved     if @moved_this_turn
    return :already_destroyed if ship.status == Ship::DESTROYED
    return :damaged_ship      if ship.status == Ship::DAMAGED   # acertado mas não destruído

    success = @board.move_ship(ship, direction)

    if success
      @moved_this_turn = true
      :moved
    else
      dx, dy = board_delta(direction)
      out = ship.positions.any? { |x, y| !@board.inside_bounds?(x + dx, y + dy) }
      out ? :out_of_bounds : :collision
    end
  end

  # Tenta mover um navio aleatório da frota (para uso da IA).
  # Escolhe aleatoriamente entre navios INTACT e tenta cada direção.
  #
  # @param fleet [Array<Ship>] frota de onde escolher o navio
  # @return [Boolean] true se algum navio foi movido
  def move_random(fleet)
    return false if @moved_this_turn

    candidates = fleet.select { |s| s.status == Ship::INTACT }
    candidates.shuffle.each do |ship|
      %i[up down left right].shuffle.each do |dir|
        result = move(ship, dir)
        return true if result == :moved
      end
    end
    false
  end

  private

  def valid_directions
    %i[up down left right]
  end

  def board_delta(direction)
    case direction
    when :up    then [0, -1]
    when :down  then [0,  1]
    when :left  then [-1, 0]
    when :right then [1,  0]
    else [0, 0]
    end
  end
end

