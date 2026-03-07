require_relative '../models/board'
require_relative '../models/player'
require_relative '../engine/shooting_mechanics'
require_relative '../models/ships/ship'

# Gerencia os turnos de uma partida de Batalha Naval.
#
# Responsabilidades:
# - Controlar de quem é o turno (jogador ou IA)
# - Aplicar tiros do jogador e da IA no tabuleiro correto
# - Detectar fim de jogo (derrota de uma das frotas)
#
# Fluxo de turnos:
# 1. Turno do jogador: ele clica em uma célula → {player_shoot} é chamado
#    - Se acertar, continua na mesma vez (opcional, defina @extra_turn_on_hit)
#    - Se errar (água), passa para a IA
# 2. Turno da IA: {ai_turn} é chamado automaticamente pelo GameScreen
#    - A IA atira; se acertar, atira de novo; se errar, volta para o jogador
#
# @author Jurandir Neto
class TurnManager
  # Quem atira agora: :player ou :ai
  attr_reader :current_turn

  # Resultado do último tiro: nil | :WATER | :DAMAGED | :DESTROYED | :REPEATED | :INVALID
  attr_reader :last_result

  # Navio atingido/destruído no último tiro (Ship | nil)
  attr_reader :last_ship

  # Coordenadas do último tiro da IA [x, y]
  attr_reader :last_ai_shot

  # @param player [Player]   instância do jogador humano
  # @param ai               instância de qualquer bot (EasyBot, MediumBot, HardBot)
  # @param extra_turn_on_hit [Boolean] se true, quem acerta ganha mais um turno
  def initialize(player, ai, extra_turn_on_hit: false)
    @player             = player
    @ai                 = ai
    @extra_turn_on_hit  = extra_turn_on_hit
    @current_turn       = :player
    @last_result        = nil
    @last_ship          = nil
    @last_ai_shot       = nil

    # Shooter do jogador aponta para o tabuleiro da IA
    @player_shooter = ShootingMechanics.new(@ai.board)
    # Shooter da IA aponta para o tabuleiro do jogador
    @ai_shooter     = ShootingMechanics.new(@player.board)
  end

  # Executa um tiro do JOGADOR nas coordenadas (x, y) do tabuleiro da IA.
  #
  # Só faz algo se for o turno do jogador e o jogo não acabou.
  # Após o tiro, decide se passa o turno para a IA ou mantém.
  #
  # @param x [Integer] coluna (0‑9)
  # @param y [Integer] linha  (0‑9)
  # @return [Symbol] resultado do tiro (:WATER, :DAMAGED, :DESTROYED, :REPEATED, :INVALID)
  def player_shoot(x, y)
    return @last_result unless @current_turn == :player
    return :GAME_OVER   if game_over?

    result, ship = @player_shooter.shoot(x, y)
    @last_result = result
    @last_ship   = ship

    # Notifica o HardBot se ele precisa registrar acertos/destruições
    if result == :DAMAGED
      # (não aplicável aqui — o hard_bot rastreia o PRÓPRIO tiro)
    elsif result == :DESTROYED && ship
      # nada extra necessário neste lado
    end

    # Troca de turno: só passa para IA se errou na água.
    # Tiros inválidos ou repetidos NÃO consomem o turno do jogador.
    if result == :WATER
      @current_turn = :ai unless game_over?
    end
    # Acertos (:DAMAGED, :DESTROYED) mantêm o turno no jogador.

    result
  end

  # Executa UM tiro da IA no tabuleiro do jogador.
  #
  # Deve ser chamado pelo GameScreen quando current_turn == :ai.
  # A IA escolhe a célula automaticamente via seu metodo shoot.
  # Retorna o resultado e decide se a IA atira de novo ou passa para o jogador.
  #
  # @return [Array(Symbol, Ship|nil, Integer, Integer)] [resultado, navio, x, y]
  def ai_turn
    return [:GAME_OVER, nil, nil, nil] if game_over?
    return [:NOT_AI_TURN, nil, nil, nil] unless @current_turn == :ai

    # A IA decide onde atirar (no tabuleiro do jogador)
    x, y = @ai.shoot(@player.board)
    @last_ai_shot = [x, y]

    result, ship = @ai_shooter.shoot(x, y)
    @last_result = result
    @last_ship   = ship

    # Notifica bots inteligentes sobre o resultado
    if @ai.respond_to?(:register_hit) && (result == :DAMAGED || result == :DESTROYED)
      @ai.register_hit(x, y, @player.board)
    end
    if @ai.respond_to?(:register_sunk) && result == :DESTROYED && ship
      @ai.register_sunk(ship.ship_size)
    end

    # Se acertou, a IA atira de novo; se errou, volta para o jogador
    @current_turn = :player if result == :WATER || result == :REPEATED || result == :INVALID

    [result, ship, x, y]
  end

  # Encerra o turno do jogador sem que ele atire (usado quando move um navio).
  # Passa o controle diretamente para a IA.
  #
  # @return [void]
  def end_player_turn_without_shot
    return if game_over?
    @current_turn = :ai
  end

  # @return [Boolean] true se alguma das frotas foi totalmente destruída
  def game_over?
    player_defeated? || ai_defeated?
  end

  # @return [Boolean] true se TODOS os navios do jogador foram destruídos
  def player_defeated?
    @player.fleet.all? { |ship| ship.status == Ship::DESTROYED }
  end

  # @return [Boolean] true se TODOS os navios da IA foram destruídos
  def ai_defeated?
    @ai.fleet.all? { |ship| ship.status == Ship::DESTROYED }
  end

  # @return [Symbol] :player se o jogador ganhou, :ai se a IA ganhou, nil se em andamento
  def winner
    return :player if ai_defeated?
    return :ai     if player_defeated?
    nil
  end
end


