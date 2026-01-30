require_relative '../board'
require_relative 'base_ai'

# Implementa o bot de nível fácil.
# Este bot escolhe de forma aleatória as coordenadas para atirar,
# apenas garantindo que não vai atirar no mesmo local (se for Hit ou Miss).
#
# @author Jurandir Neto
class EasyBot < BaseAI

  # Calcula a próxima jogada (tiro) do Bot
  # Gera coordenadas aleatórias até encontrar uma posição que não foi atacada
  #
  # @param opponent_board [Board] O tabuleiro do oponente para leitura.
  #
  # @return [Array<Integer>] Um array contendo as coordenadas [x,y] do alvo escolhido
  # @example
  #   bot = EasyBot.new
  #   bot.shoot(tabuleiro) #=> [5,5]
  def shoot(opponent_board)
    loop do
      x = rand(10)
      y = rand(10)

      if opponent_board.status_at(x, y) != :HIT and opponent_board.status_at(x, y) != :MISS
        return [x,y]
      end
    end
  end
end