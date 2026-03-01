require 'gosu'
require_relative 'lib/ui/theme'
require_relative 'lib/screens/base_screen'
require_relative 'lib/screens/login_screen'
require_relative 'lib/screens/menu_screen'
require_relative 'lib/screens/game_screen'
require_relative 'lib/screens/ranking_screen'
require_relative 'lib/screens/options_screen'
require_relative 'lib/screens/campaign_screen'
require_relative 'lib/screens/achievements_screen'
require_relative 'lib/engine/achievement_manager'
require_relative 'lib/ui/achievement_notification'
require_relative 'lib/database/database_manager'

class GameWindow < Gosu::Window
  # Banco de dados acessível por qualquer tela via window.db
  attr_reader :db, :current_user

  def initialize
    super 800, 600
    self.caption  = "Battleship"
    @db           = DatabaseManager.new
    @current_user = nil
    @achievement_manager = AchievementManager.new
    show_screen(:login)
  end

  # Callback chamado pela LoginScreen após autenticação bem-sucedida.
  # A troca de tela é adiada para o próximo frame (evita crash no meio do button_down).
  def on_login(user)
    @current_user   = user
    @pending_screen = :menu
  end

  def show_screen(screen_symbol)
    case screen_symbol
    when :login        then @current_screen = LoginScreen.new(self)
    when :menu         then @current_screen = MenuScreen.new(self)
    when :campaign     then @current_screen = CampaignScreen.new(self)
    when :dynamic      then @current_screen = GameScreen.new(self, current_user: @current_user)
    when :ranking      then @current_screen = RankingScreen.new(self)
    when :options      then @current_screen = OptionsScreen.new(self)
    when :achievements then @current_screen = AchievementsScreen.new(self, @achievement_manager)
    else
      @current_screen = MenuScreen.new(self)
    end
  end

  # Agenda a troca de tela para o próximo frame (seguro dentro de button_down).
  def request_screen(screen_symbol)
    @pending_screen = screen_symbol
  end

  def needs_cursor?
    true
  end

  def update
    if @pending_screen
      show_screen(@pending_screen)
      @pending_screen = nil
    end
    @current_screen.update if @current_screen.respond_to?(:update)
  end

  def draw
    draw_rect(0, 0, width, height, Theme::COLOR_BG)
    @current_screen.draw

    # Exibe usuário logado no canto superior direito (em todas as telas pós-login)
    if @current_user && !@current_screen.is_a?(LoginScreen)
      draw_user_badge
    end
  end

  # IDs de teclas especiais que NÃO devem ser tratadas como caractere de texto
  TEXT_BLACKLIST = [
    Gosu::KB_RETURN, Gosu::KB_ENTER,
    Gosu::KB_BACKSPACE, Gosu::KB_TAB,
    Gosu::KB_ESCAPE, Gosu::KB_DELETE,
    Gosu::KB_LEFT, Gosu::KB_RIGHT, Gosu::KB_UP, Gosu::KB_DOWN,
    Gosu::MS_LEFT, Gosu::MS_RIGHT, Gosu::MS_MIDDLE
  ].freeze

  def button_down(id)
    if id == Gosu::KB_ESCAPE
      if @current_screen.is_a?(LoginScreen) || @current_screen.is_a?(MenuScreen)
        close
      else
        @pending_screen = :menu
      end
      return
    end

    # Sempre repassa o evento para a tela atual (Enter, Backspace, cliques, etc.)
    @current_screen.button_down(id)

    # Adicionalmente, repassa o caractere imprimível para telas com input de texto
    if !TEXT_BLACKLIST.include?(id) && @current_screen.respond_to?(:receive_char)
      char = Gosu.button_id_to_char(id)
      @current_screen.receive_char(char) if char && !char.empty?
    end
  end

  private

  def draw_user_badge
    font   = Gosu::Font.new(16)
    text   = "● #{@current_user['username']}"
    tw     = font.text_width(text)
    font.draw_text(text, width - tw - 10, 8, 3, 1.0, 1.0, Theme::COLOR_ACCENT)
  end
end

GameWindow.new.show