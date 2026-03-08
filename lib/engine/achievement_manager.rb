require 'json'
require_relative '../models/ships/ship'

# Gerencia o sistema de conquistas (medalhas) do jogo.
#
# Conquistas disponíveis:
# - :almirante         → Vença sem perder nenhum navio.
# - :capitao_mar_guerra → Acerte 8 tiros consecutivos.
# - :capitao           → Acerte navios de 7 tipos diferentes seguidos (sem errar).
# - :marinheiro        → Vença em menos de 3 minutos.
# - :alma_negra      → Derrote o Davy Jones na missão impossível.
#
# @author Jurandir Neto
class AchievementManager
  SAVE_FILE = 'achievements.json'.freeze

  # Definição das medalhas
  ACHIEVEMENTS = {
    almirante: {
      name: 'Almirante',
      description: 'Vença a partida sem perder nenhum navio!',
      icon: '★'
    },
    capitao_mar_guerra: {
      name: 'Capitão de Mar e Guerra',
      description: 'Acerte 8 tiros consecutivos.',
      icon: '⚓'
    },
    capitao: {
      name: 'Capitão',
      description: 'Acerte navios de 7 tipos diferentes em sequência.',
      icon: '⚔'
    },
    marinheiro: {
      name: 'Marinheiro',
      description: 'Vença em menos de 3 minutos.',
      icon: '⏱'
    },
    jack_sparrow: {
      name: 'Alma Negra',
      description: 'Você mostrou o motivo de ser o mais temido dos mares. Derrotou o temido Davy Jones na missão impossível!',
      icon: '☠'
    }
  }.freeze

  # Tempo limite em segundos para a conquista do Marinheiro
  MARINHEIRO_TIME_LIMIT = 180

  attr_reader :unlocked_achievements, :consecutive_hits, :ship_types_hit_streak

  # @param user_id [Integer, String, nil] ID do usuário. Nil usa a chave 'guest'.
  def initialize(user_id: nil)
    @user_id                  = user_id ? user_id.to_s : 'guest'
    @unlocked_achievements    = []
    @consecutive_hits         = 0
    @ship_types_hit_streak    = []   # tipos de navios acertados em sequência
    @game_start_time          = Time.now
    load_achievements
  end

  # Reinicia os contadores internos para uma nova partida.
  def reset_session
    @consecutive_hits      = 0
    @ship_types_hit_streak = []
    @game_start_time       = Time.now
    @newly_unlocked        = []
    @impossible_victory    = false
  end

  # Sinaliza que esta partida foi uma vitória contra o Davy Jones (missão impossível).
  # Deve ser chamado antes de +register_victory+.
  def flag_impossible_victory
    @impossible_victory = true
  end

  # Deve ser chamado após cada disparo do jogador.
  #
  # @param result   [Symbol] resultado do tiro (:WATER, :DAMAGED, :DESTROYED, :REPEATED, :INVALID)
  # @param ship     [Ship, nil] navio atingido (pode ser nil se result for :WATER)
  def register_shot(result, ship = nil)
    case result
    when :DAMAGED, :DESTROYED
      @consecutive_hits += 1
      check_capitao_mar_guerra

      if ship
        ship_type = ship.class.name
        @ship_types_hit_streak << ship_type
        check_capitao
      end
    when :WATER
      # Sequência quebrada
      @consecutive_hits      = 0
      @ship_types_hit_streak = []
    else
      # :REPEATED ou :INVALID — não afetam as sequências
    end
  end

  # Deve ser chamado ao fim da partida com vitória do jogador.
  #
  # @param player_fleet [Array<Ship>] frota do jogador (para checar Almirante)
  def register_victory(player_fleet)
    check_almirante(player_fleet)
    check_marinheiro
    check_jack_sparrow if @impossible_victory
    save_achievements
    @newly_unlocked
  end

  # Retorna as conquistas desbloqueadas nesta sessão.
  # @return [Array<Symbol>]
  def newly_unlocked
    @newly_unlocked ||= []
  end

  # Verifica se uma conquista já foi desbloqueada (permanentemente).
  # @param key [Symbol]
  # @return [Boolean]
  def unlocked?(key)
    @unlocked_achievements.include?(key)
  end

  # Retorna o tempo decorrido desde o início da partida (em segundos).
  # @return [Float]
  def elapsed_time
    Time.now - @game_start_time
  end

  private

  # --- Verificações individuais ---

  # Almirante: vencer sem perder nenhum navio.
  def check_almirante(player_fleet)
    all_intact = player_fleet.none? { |ship| ship.status == Ship::DESTROYED }
    unlock(:almirante) if all_intact
  end

  # Capitão de Mar e Guerra: 8 acertos consecutivos.
  def check_capitao_mar_guerra
    unlock(:capitao_mar_guerra) if @consecutive_hits >= 8
  end

  # Capitão: acertar navios de 7 tipos diferentes em sequência sem errar.
  def check_capitao
    unique_types = @ship_types_hit_streak.uniq
    unlock(:capitao) if unique_types.size >= 7
  end

  # Marinheiro: vencer em menos de MARINHEIRO_TIME_LIMIT segundos.
  def check_marinheiro
    unlock(:marinheiro) if elapsed_time <= MARINHEIRO_TIME_LIMIT
  end

  # Jack Sparrow: derrotar o Davy Jones na missão impossível.
  def check_jack_sparrow
    unlock(:jack_sparrow)
  end

  # Desbloqueia uma conquista (se ainda não desbloqueada).
  def unlock(key)
    return if @unlocked_achievements.include?(key)
    @unlocked_achievements << key
    @newly_unlocked ||= []
    @newly_unlocked << key
  end

  # --- Persistência ---

  def save_achievements
    raw  = File.exist?(SAVE_FILE) ? File.read(SAVE_FILE) : ''
    data = raw.strip.empty? ? {} : JSON.parse(raw)
    data[@user_id] = @unlocked_achievements.map(&:to_s)
    File.write(SAVE_FILE, JSON.generate(data))
  rescue => e
    warn "AchievementManager: falha ao salvar conquistas \u2013 #{e.message}"
  end

  def load_achievements
    @newly_unlocked = []
    return unless File.exist?(SAVE_FILE)
    raw = File.read(SAVE_FILE)
    return if raw.strip.empty?
    data = JSON.parse(raw)
    user_data = data[@user_id] || []
    @unlocked_achievements = user_data.map(&:to_sym)
  rescue => e
    warn "AchievementManager: falha ao carregar conquistas \u2013 #{e.message}"
    @unlocked_achievements = []
  end
end


