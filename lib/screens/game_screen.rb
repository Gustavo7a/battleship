require_relative 'base_screen'
require_relative '../models/board'
require_relative '../models/player'
require_relative '../models/ai/medium_bot'
require_relative '../engine/achievement_manager'
require_relative '../ui/achievement_notification'

class GameScreen < BaseScreen
  def initialize(window, current_user: nil)
    super(window)
    @current_user        = current_user
    @achievement_manager = AchievementManager.new
    @achievement_manager.reset_session
    @notification = AchievementNotification.new
    @game_start   = Time.now
  end

  def update
    @notification.update
  end

  def draw
    draw_header("BATTLE STATIONS")
    draw_centered_text("In progress...", 180, Theme::COLOR_TEXT, @btn_font)

    # Exibe usuário logado
    if @current_user
      user_text = "Jogador: #{@current_user['username']}"
      @info_font.draw_text(user_text, 10, 10, 2, 1.0, 1.0, Theme::COLOR_ACCENT)
    end

    @notification.draw(@window.width)
  end

  # Registra um tiro do jogador e verifica conquistas.
  # result, ship = player.shoot(x, y)
  # register_shot(result, ship)
  def register_shot(result, ship = nil)
    @achievement_manager.register_shot(result, ship)
    flush_notifications
  end

  # Chamar ao fim da partida.
  # @param player_fleet [Array<Ship>] frota do jogador
  # @param won          [Boolean]
  # @param score        [Integer]
  def register_end(player_fleet:, won:, score: 0)
    newly = @achievement_manager.register_victory(player_fleet)
    newly.each { |key| @notification.enqueue(key) }

    if @current_user
      duration = (Time.now - @game_start).to_i
      @window.db.save_match(
        user_id:  @current_user['id'],
        won:      won,
        score:    score,
        duration: duration
      )
    end
  end

  private

  def flush_notifications
    newly = @achievement_manager.newly_unlocked.dup
    @achievement_manager.newly_unlocked.clear
    newly.each { |key| @notification.enqueue(key) }
  end
end