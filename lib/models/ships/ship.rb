# Representa o modelo base de um navio no jogo de Batalha Naval.
# Esta classe gerencia o estado de integridade, tamanho e coordenadas ocupadas.
#
# @author João Francisco
class Ship
  # @return [Integer] o tamanho total do navio (número de células).
  # @return [Array<Array(Integer, Integer)>] lista de coordenadas [x, y] ocupadas.
  # @return [Integer] quantidade de acertos recebidos.
  # @return [Symbol] estado atual (:Intact, :Damaged ou :Destroyed).
  # @return [Symbol, nil] orientação do navio no tabuleiro (:horizontal ou :vertical).
  attr_accessor :ship_size, :positions, :hits, :status, :orientation

  # @group Estados do Navio

  # Navio sem nenhum dano.
  INTACT    = :Intact
  # Navio com pelo menos um acerto, mas ainda flutuando.
  DAMAGED   = :Damaged
  # Navio totalmente destruído.
  DESTROYED = :Destroyed

  # @endgroup

  # Cria uma nova instância de um navio.
  #
  # @param ship_size [Integer] o número de células que o navio ocupa.
  def initialize(ship_size)
    @ship_size = ship_size
    @positions = []
    @hits = 0
    @status = INTACT
    @orientation = nil
  end

  # Registra um acerto no navio e atualiza seu status de integridade.
  #
  # @return [Symbol] o novo status do navio após o dano.
  def receive_hit
    @hits += 1
    if @hits < @ship_size
      @status = DAMAGED
    elsif @hits == @ship_size
      @status = DESTROYED
    end
  end

  # Atualiza as posições do navio após um movimento válido.
  #
  # @param new_positions [Array<Array(Integer, Integer)>] nova lista de coordenadas [x, y].
  # @return [void]
  def move_to(new_positions)
    @positions = new_positions.dup
  end

end
