require_relative '../board'
require_relative '../ships/submarine'
require_relative '../ships/warship'
require_relative '../ships/flattop'
require_relative '../ships/battleship'

# Classe base para controlar o posicionamento aleatório dos navios das IAs no tabuleiro.
#
# @abstract Esta classe não deve ser instanciada, pois ela é uma base (mãe), use {easy_bot}, {medium_bot} e {hard_bot}
# @author Jurandir Neto
class BaseAI
  # @return [Board] O tabuleiro onde os navios da IA estão posicionados
  # @return [Array<Ship>] A lista de navios que a IA possui
  attr_reader :board, :fleet

  # Inicializa a estrutura básica das IAs
  # Cria um novo tabuleiro board e define a frota padrão do jogo
  #
  # Requisitos da frota (pelo professor):
  # * 2 Flattops (Porta-aviões)
  # * 2 Warships (Navios de Guerra)
  # * 1 Battleship (Encouraçado)
  # * 1 Submarine (Submarino)
  def initialize
    @board = Board.new
    @fleet = [
      Flattop.new,
      Flattop.new,
      Warship.new,
      Warship.new,
      Battleship.new,
      Submarine.new
    ]
  end

  # Posiciona toda a frota da IA no tabuleiro de forma aleatória.
  #
  # O método percorre cada navio da frota (@fleet) e tenta, repetidamente, encontrar
  # uma posição (x,y) e orientação válida até conseguir posiciona-los
  #
  # @return [void]
  def setup_ships
    @fleet.each do |ship| # Vai percorrer o @fleet para posicionar cada navio
      loop do # Vai fazer as tentativas para posicionar o navio
        x = rand(10)
        y = rand(10)
        orientation = [:horizontal, :vertical].sample

        if @board.place_ship(ship, x, y, orientation)
          break
        end

      end
    end
    puts "A IA posicionou a frota"
  end

  # Define a lógica de tiro de cada IA.
  #
  # @abstract Este método é apenas um contrato. As classes filhas (EasyBot, MediumBot e HardBot)
  # irão implementar a própria estratégia.
  #
  # @param target [Board] o tabuleiro do oponente que receberá o tiro
  # @raise [RuntimeError] Caso o método seja chamado diretamente na BaseAI
  # ou se a classe filha não sobrescrever este método.
  def shoot(target)
    raise "Erro: O método shoot deve ser implementado pela classe filha!"
  end
end