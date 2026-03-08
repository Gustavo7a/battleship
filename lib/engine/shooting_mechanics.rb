require_relative '../models/board'
require_relative '../models/ships/ship'

# Responsável por aplicar as regras de disparos no tabuleiro.
# A classe valida:
# - limtes do tabuleiro
# - tiros repetidos
# - acertos, danos e dstruição de navios
# Retorna símbolos represenrando o resultado do disparo.
# # @author José Gustavo
class ShootingMechanics
  # Possíveis resultados de um disparo
  RESULTS = [:WATER, :DAMAGED, :DESTROYED, :REPEATED, :INVALID].freeze

  # @param board [Board] tabuleiro onde os tiros serão aplicados
  def initialize(board)
    @board = board
  end

  # Executa um disparo em uma posição do tabuleiro.
  # @param x [Integer] coordenada horizontal
  # @param y [Integer] coordenada vertical
  #
  # @return [Array(Symbol, Ship|nil)] par [resultado, navio_atingido]:
  # - resultado: :WATER, :DAMAGED, :DESTROYED, :REPEATED ou :INVALID
  # - navio_atingido: objeto Ship se houve acerto, nil caso contrário
  def shoot(x, y)
    return [:INVALID, nil] unless @board.inside_bounds?(x, y)
    content = @board.status_at(x, y)
    return [:REPEATED, nil] if content == Board::HIT or content == Board::MISS

    if content.is_a?(Ship)
      ship = content
      ship.receive_hit
      @board.set_status(x, y, Board::HIT)
      if ship.status == Ship::DESTROYED
        return [:DESTROYED, ship]
      else
        return [:DAMAGED, ship]
      end
    else
      @board.set_status(x, y, Board::MISS)
      [:WATER, nil]
    end
  end
end