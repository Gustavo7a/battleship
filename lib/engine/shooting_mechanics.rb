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
  # @return [Symbol] resultado do disparo:
  # - :WATER -> tiro na água
  # - :DAMAGED -> navio atingido, mas não destruído
  # - :DESTROYED -> navio destruído
  # - :REPEATED -> posição já atingida
  # - :INVALID -> posição fora do tabuleiro
  def shoot(x, y)
    return :INVALID unless @board.inside_bounds?(x, y)
    content = @board.status_at(x, y)
    return :REPEATED if content == Board::HIT or content == Board::MISS


    if content.is_a?(Ship)
      ship = content
      ship.receive_hit
      @board.set_status(x, y, Board::HIT)
      if ship.status == Ship::DESTROYED
        return :DESTROYED
      else
        return :DAMAGED
      end
    else
      @board.set_status(x, y, Board::MISS)
      return :WATER
    end
  end
end