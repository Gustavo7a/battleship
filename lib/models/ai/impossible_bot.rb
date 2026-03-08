require_relative '../board'
require_relative 'base_ai'

# Bot de nível impossível — Davy Jones.
#
# Mecânica em dois estágios:
#
# 1. **Fase livre** (FREE_TURNS turnos da IA): o bot dispara intencionalmente
#    em células de água, concedendo ao jogador FREE_TURNS oportunidades de
#    vencer antes de qualquer retaliação.
#
# 2. **Fase vingança**: esgotados os turnos livres, o bot localiza TODAS as
#    posições de navios no tabuleiro do adversário (conhecimento total) e as
#    abate em sequência, uma célula por tick, até destruir a frota inteira.
#
# Como o TurnManager mantém o turno da IA enquanto ela acerta (:DAMAGED /
# :DESTROYED), a fase vingança corre sem interrupção do jogador.
#
# @author João Francisco
class ImpossibleBot < BaseAI
  FREE_TURNS = 30

  attr_reader :free_turns_used

  def initialize
    super
    @free_turns_used = 0
    @revenge_targets = nil  # Array<[x,y]> preenchido ao entrar na fase vingança
  end

  # Retorna true enquanto o bot ainda concede turnos livres ao jogador.
  # Durante esse período o bot simplesmente passa a vez (não atira).
  def pass_turn?
    @free_turns_used < FREE_TURNS
  end

  # Consome um turno livre. Chamado pelo GameScreen em vez de ai_turn.
  def consume_free_turn
    @free_turns_used += 1
  end

  # Turnos livres que ainda restam ao jogador.
  def free_turns_remaining
    [FREE_TURNS - @free_turns_used, 0].max
  end

  # Retorna as coordenadas do próximo tiro (fase vingança apenas).
  #
  # @param opponent_board [Board] tabuleiro do jogador
  # @return [Array(Integer, Integer)]
  def shoot(opponent_board)
    revenge_shot(opponent_board)
  end

  private

  # Retorna a próxima célula de navio na fila de vingança.
  def revenge_shot(board)
    populate_targets(board) if @revenge_targets.nil?

    # Remove da frente células já acertadas (resultado de tiros anteriores desta fase)
    @revenge_targets.shift while @revenge_targets.first &&
                                   board.status_at(*@revenge_targets.first) == Board::HIT

    @revenge_targets.empty? ? fallback_cell(board) : @revenge_targets.first
  end

  # Coleta, em varredura linha-a-linha, todas as células que ainda contêm navios.
  def populate_targets(board)
    @revenge_targets = []
    10.times do |y|
      10.times do |x|
        @revenge_targets << [x, y] if board.status_at(x, y).is_a?(Ship)
      end
    end
  end

  # Célula de fallback — retorna a primeira célula válida disponível.
  def fallback_cell(board)
    10.times do |y|
      10.times do |x|
        c = board.status_at(x, y)
        return [x, y] if c == Board::WATER || c.is_a?(Ship)
      end
    end
    [0, 0]
  end
end