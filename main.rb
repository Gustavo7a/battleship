require 'gosu'
require_relative 'lib/ui/theme'
require_relative 'lib/screens/base_screen'
require_relative 'lib/screens/login_screen'
require_relative 'lib/screens/menu_screen'
require_relative 'lib/screens/game_screen'
require_relative 'lib/screens/placement_screen'
require_relative 'lib/screens/ranking_screen'
require_relative 'lib/screens/options_screen'
require_relative 'lib/screens/campaign_screen'
require_relative 'lib/screens/achievements_screen'
require_relative 'lib/engine/achievement_manager'
require_relative 'lib/ui/achievement_notification'
require_relative 'lib/database/database_manager'
require_relative 'lib/models/board'
require_relative 'lib/models/ships/ship'

class GameWindow < Gosu::Window
  attr_reader :db, :current_user

  def initialize
    super 800, 600
    self.caption     = "Battleship"
    @db              = DatabaseManager.new
    @current_user    = nil
    @achievement_manager = AchievementManager.new
    @campaign_stage  = 1
    show_screen(:login)
  end

  def on_login(user)
    @current_user   = user
    @pending_screen = :menu
  end

  # Abre a PlacementScreen antes de uma missão de campanha
  def start_campaign_mission(stage, difficulty)
    @pending_placement = {
      campaign_stage: stage,
      difficulty:     difficulty,
      current_user:   @current_user
    }
  end

  # Recebe a frota posicionada da PlacementScreen e inicia o GameScreen
  def start_game_with_placement(placements:, fleet:, campaign_stage:, difficulty:, current_user:)
    # Constrói o Board real a partir dos placements
    board = Board.new
    fleet.each do |ship|
      entry = placements[ship.object_id]
      next unless entry
      ship.instance_variable_set(:@hits, 0)
      ship.instance_variable_set(:@status, Ship::INTACT)
      ship.instance_variable_set(:@positions, [])
      ori = entry[:orientation]
      col = entry[:col]
      row = entry[:row]
      board.place_ship(ship, col, row, ori)
    end

    @pending_game = {
      pre_placed_fleet:  fleet,
      pre_placed_board:  board,
      campaign_stage:    campaign_stage,
      difficulty:        difficulty,
      current_user:      current_user
    }
  end

  def on_campaign_mission_won(stage)
    @campaign_stage = [stage + 1, 4].min
    @pending_screen = :campaign
  end

  def show_screen(screen_symbol)
    case screen_symbol
    when :login        then @current_screen = LoginScreen.new(self)
    when :menu         then @current_screen = MenuScreen.new(self)
    when :campaign     then @current_screen = CampaignScreen.new(self, stage: @campaign_stage)
    when :dynamic
      # Modo dinâmico também passa pela PlacementScreen
      @pending_placement = { campaign_stage: nil, difficulty: nil, current_user: @current_user }
    when :ranking      then @current_screen = RankingScreen.new(self)
    when :options      then @current_screen = OptionsScreen.new(self)
    when :achievements then @current_screen = AchievementsScreen.new(self, @achievement_manager)
    else
      @current_screen = MenuScreen.new(self)
    end
  end

  def request_screen(screen_symbol)
    @pending_screen = screen_symbol
  end

  def needs_cursor?
    true
  end

  def update
    # Prioridade 1: lançar GameScreen com frota posicionada
    if @pending_game
      cfg = @pending_game
      @pending_game = nil
      @current_screen = GameScreen.new(
        self,
        current_user:     cfg[:current_user],
        campaign_stage:   cfg[:campaign_stage],
        difficulty:       cfg[:difficulty],
        pre_placed_fleet: cfg[:pre_placed_fleet],
        pre_placed_board: cfg[:pre_placed_board]
      )
      return
    end

    # Prioridade 2: abrir PlacementScreen
    if @pending_placement
      cfg = @pending_placement
      @pending_placement = nil
      @current_screen = PlacementScreen.new(
        self,
        campaign_stage: cfg[:campaign_stage],
        difficulty:     cfg[:difficulty],
        current_user:   cfg[:current_user]
      )
      return
    end

    if @pending_screen
      show_screen(@pending_screen)
      @pending_screen = nil
    end

    @current_screen.update if @current_screen.respond_to?(:update)
  end

  def draw
    draw_rect(0, 0, width, height, Theme::COLOR_BG)
    @current_screen.draw

    if @current_user && !@current_screen.is_a?(LoginScreen)
      draw_user_badge
    end
  end

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

    @current_screen.button_down(id)

    if !TEXT_BLACKLIST.include?(id) && @current_screen.respond_to?(:receive_char)
      char = Gosu.button_id_to_char(id)
      @current_screen.receive_char(char) if char && !char.empty?
    end
  end

  # Repassa button_up para telas que precisam (drag na PlacementScreen)
  def button_up(id)
    @current_screen.button_up(id) if @current_screen.respond_to?(:button_up)
  end

  private

  def draw_user_badge
    font = Gosu::Font.new(16)
    text = "● #{@current_user['username']}"
    tw   = font.text_width(text)
    font.draw_text(text, width - tw - 10, 8, 3, 1.0, 1.0, Theme::COLOR_ACCENT)
  end
end

GameWindow.new.show