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
require_relative 'lib/screens/congratulations_screen'
require_relative 'lib/screens/davy_jones_defeat_screen'
require_relative 'lib/engine/achievement_manager'
require_relative 'lib/ui/achievement_notification'
require_relative 'lib/database/database_manager'
require_relative 'lib/models/board'
require_relative 'lib/models/ships/ship'

class GameWindow < Gosu::Window
  DESIGN_W = 800.0
  DESIGN_H = 600.0

  attr_reader :db, :current_user, :achievement_manager, :bg_music, :waves_music, :bg_image,
              :font_title, :font_btn, :font_info
  attr_accessor :sfx_enabled, :music_enabled

  def dw = DESIGN_W.to_i
  def dh = DESIGN_H.to_i
  def scale_x = width.to_f  / DESIGN_W
  def scale_y = height.to_f / DESIGN_H
  def mx = mouse_x / scale_x
  def my = mouse_y / scale_y

  def initialize
    super 800, 600
    self.caption     = "Battleship"
    @db              = DatabaseManager.new
    @current_user    = nil
    @achievement_manager = AchievementManager.new
    @campaign_stage  = 1
    @sfx_enabled     = true
    @music_enabled   = true
    @bg_music = Gosu::Song.new(File.join('assets', 'musics', 'musica_de_marinheiro.wav'))
    @bg_music.volume = 0.05
    @bg_music.play(true)
    @waves_music = Gosu::Song.new(File.join('assets', 'sfx', 'waves.wav'))
    @waves_music.volume = 0.15
    begin
      @bg_image = Gosu::Image.new(File.join('assets', 'images', 'background.jpg'))
    rescue
      @bg_image = nil
    end
    @font_title = Gosu::Font.new(50)
    @font_btn   = Gosu::Font.new(22)
    @font_info  = Gosu::Font.new(18)
    show_screen(:login)
  end

  def toggle_music
    @music_enabled = !@music_enabled
    if @current_screen.is_a?(GameScreen) || @current_screen.is_a?(PlacementScreen)
      @music_enabled ? @waves_music.play(true) : @waves_music.stop
    else
      @music_enabled ? @bg_music.play(true) : @bg_music.stop
    end
  end

  def toggle_sfx
    @sfx_enabled = !@sfx_enabled
  end

  def on_login(user)
    @current_user        = user
    @achievement_manager = AchievementManager.new(user_id: user['id'])
    @campaign_stage      = @db.get_campaign_stage(user['id'])
    self.fullscreen      = true unless fullscreen?
    @pending_screen      = :menu
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
    new_stage = [stage + 1, 5].min
    if new_stage > @campaign_stage
      @campaign_stage = new_stage
      @db.set_campaign_stage(@current_user['id'], @campaign_stage) if @current_user
    end
    # Missão 4 (Davy Jones): tela de parabenização especial
    @pending_screen = stage == 4 ? :congratulations : :campaign
  end

  def show_screen(screen_symbol)
    # Só altera fullscreen ao voltar para o login (raramente usado)
    self.fullscreen = false if screen_symbol == :login && fullscreen?
    # Retomando telas de menu: reinicia a música se habilitada
    menu_screens = %i[login menu campaign ranking options achievements congratulations davy_jones_defeat]
    if menu_screens.include?(screen_symbol)
      @waves_music.stop if @waves_music.playing?
      @bg_music.play(true) if @music_enabled && !@bg_music.playing?
    end
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
    when :congratulations     then @current_screen = CongratulationsScreen.new(self)
    when :davy_jones_defeat   then @current_screen = DavyJonesDefeatScreen.new(self)
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
      self.fullscreen = true
      @waves_music.play(true) if @music_enabled && !@waves_music.playing?
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
      @bg_music.stop
      @waves_music.play(true) if @music_enabled
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
    draw_rect(0, 0, width, height, Theme::COLOR_BG, -10)
    if @current_screen.is_a?(GameScreen)
      @current_screen.draw
      draw_user_badge(width) if @current_user && !@current_screen.is_a?(LoginScreen)
    else
      sx = width  > 0 ? width.to_f  / DESIGN_W : 1.0
      sy = height > 0 ? height.to_f / DESIGN_H : 1.0
      Gosu.scale(sx, sy) do
        @current_screen.draw
        draw_user_badge(dw) if @current_user && !@current_screen.is_a?(LoginScreen)
      end
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
      # Delega ao GameScreen para tratar pausa antes de ir ao menu
      if @current_screen.respond_to?(:handle_escape)
        @current_screen.handle_escape
        return
      end
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

  def draw_user_badge(ref_w = dw)
    font = Gosu::Font.new(16)
    text = "\u25cf #{@current_user['username']}"
    tw   = font.text_width(text)
    font.draw_text(text, ref_w - tw - 10, 8, 3, 1.0, 1.0, Theme::COLOR_ACCENT)
  end
end

GameWindow.new.show