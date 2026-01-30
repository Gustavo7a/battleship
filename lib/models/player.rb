require_relative '../models/board'
require_relative '../engine/shooting_mechanics'

# Representa um jogador da partida.
# Um Player possui:
# - um nome
# - um tabuleiro próprio
# - a capacidade de realizar disparos
#
# A classe delega a lógica de tiro para ShootingMechanics
# e mantém apenas o estado do jogador.
# # @author José Gustavo
class Player
  # @return [Board] tabuleiro do jogador
  # @return [String] nome do jogador
  attr_reader :board, :name, :fleet

  # Cria um novo jogador.
  # @param name [String] nome do jogador
  def initialize(name:)
    @name = name
    reset_board
  end

  # Realiza um disparo em uma posição do tabuleiro adversário.
  # @param x [Integer] coordenada horizontal
  # @param y [Integer] coordenada vertical
  # @return [Symbol] resultado do disparo (:WATER, :DAMAGED, etc.)
  def shoot(x, y)
    @shooter.shoot(x, y)
  end

  # Verifica se o jogador foi derrotado.
  # @return [Boolean] true se todos os navios do jogador foram destruídos
  def defeated?
    @fleet.all? {|ship| ship.status == Ship::DESTROYED}
  end

  # Reseta o tabuleiro e a frota de navios do jogador.
  # Usado, por exemplo, ao avançar para uma nova fase
  # ou iniciar uma nova partida.
  def reset_board
    @board = Board.new
    @fleet = buid_fleet
    @shooter = ShootingMechanics.new(@board)
  end

  # Cria a frota de navios do player
  #   # * 2 Flattop (Porta-aviões).
  #   # * 2 Warship (Navios de Guerra).
  #   # * 1 Battleship (Encouraçado).
  #   # * 1 Submarine (Submarino).
  private
  def buid_fleet
    [
      Flattop.new,
      Flattop.new,
      Warship.new,
      Warship.new,
      Battleship.new,
      Submarine.new
    ]
  end
end
