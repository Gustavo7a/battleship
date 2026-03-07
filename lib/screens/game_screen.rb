require_relative 'base_screen'
require_relative '../models/board'
require_relative '../models/player'
require_relative '../models/ai/easy_bot'
require_relative '../models/ai/medium_bot'
require_relative '../models/ai/hard_bot'
require_relative '../models/ships/ship'
require_relative '../models/ships/flattop'
require_relative '../models/ships/warship'
require_relative '../models/ships/battleship'
require_relative '../models/ships/submarine'
require_relative '../engine/turn_manager'
require_relative '../engine/achievement_manager'
require_relative '../ui/achievement_notification'

# Tela de jogo principal.
#
# Gerencia a partida completa:
# - Posiciona os navios do jogador e da IA
# - Controla turnos via TurnManager
# - Recebe cliques do jogador e converte em tiros no grid da IA
# - Dispara o turno da IA automaticamente após o turno do jogador
# - Detecta fim de jogo e notifica o GameWindow
#
# Modos de uso
# Partida avulsa (Dynamic):   GameScreen.new(window, current_user: user)
# Partida de campanha:        GameScreen.new(window, current_user: user,
#                                            campaign_stage: 1, difficulty: :easy)
#
# @author Jurandir Neto
class GameScreen < BaseScreen

  # Margem e tamanho de cada célula do grid (apenas lógica, sem sprites reais)
  CELL_SIZE    = 30
  GRID_MARGIN  = 20

  # Origem do grid do INIMIGO (jogador clica aqui para atirar)
  ENEMY_GRID_X = 420
  ENEMY_GRID_Y = 130

  # Origem do grid do JOGADOR (visual de referência)
  PLAYER_GRID_X = 20
  PLAYER_GRID_Y = 130

  def initialize(window, current_user: nil, campaign_stage: nil, difficulty: nil,
                 pre_placed_fleet: nil, pre_placed_board: nil)
    super(window)

    @current_user     = current_user
    @campaign_stage   = campaign_stage
    @difficulty       = difficulty
    @pre_placed_fleet = pre_placed_fleet    # Array<Ship> já posicionados
    @pre_placed_board = pre_placed_board    # Board já montado

    @achievement_manager = AchievementManager.new
    @achievement_manager.reset_session
    @notification = AchievementNotification.new
    @game_start   = Time.now

    @status_message = "Sua vez — clique no tabuleiro do inimigo para atirar!"
    @game_over      = false
    @ai_timer       = 0
    @grid_font      = Gosu::Font.new(11)   # fonte compacta para labels A-J / 1-10

    # Sprite de água
    begin
      @water_tile = Gosu::Image.new(
        File.join("assets", "images", "agua.png"),
        tileable: true
      )
    rescue
      @water_tile = nil
    end

    setup_game
  end

  # Loop principal
  def update
    @notification.update
    return if @game_over

    # Turno da IA: aguarda alguns frames para dar sensação de "pensando"
    if @turn_manager.current_turn == :ai
      @ai_timer += 1
      if @ai_timer >= 40   # ~40 frames de delay (~0.67 s a 60 fps)
        @ai_timer = 0
        execute_ai_turn
      end
    end
  end

  def draw
    draw_header(header_title)

    draw_status_bar
    draw_player_grid
    draw_enemy_grid
    draw_fleet_info

    @notification.draw(@window.width)

    if @game_over
      draw_game_over_overlay
    end
  end

  # Input

  def button_down(id)
    if @game_over
      handle_game_over_input(id)
      return
    end

    if id == Gosu::MS_LEFT && @turn_manager.current_turn == :player
      handle_player_click
    end
  end

  # Resultado da partida

  def register_shot(result, ship = nil)
    @achievement_manager.register_shot(result, ship)
    flush_notifications
  end

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

  # Setup

  def setup_game
    @player = Player.new(name: player_name)
    @ai     = build_ai

    if @pre_placed_fleet && @pre_placed_board
      # Usa a frota e board vindos da PlacementScreen
      @player.use_pre_placed(@pre_placed_fleet, @pre_placed_board)
    else
      auto_place_player_ships
    end

    @ai.setup_ships
    @turn_manager = TurnManager.new(@player, @ai)
  end

  def player_name
    @current_user ? @current_user['username'] : "Player"
  end

  def build_ai
    case @difficulty
    when :easy   then EasyBot.new
    when :hard   then HardBot.new
    else              MediumBot.new   # default e :medium
    end
  end

  # Posiciona os navios do jogador aleatoriamente (sem sprites ainda)
  def auto_place_player_ships
    @player.fleet.each do |ship|
      loop do
        x           = rand(10)
        y           = rand(10)
        orientation = [:horizontal, :vertical].sample
        break if @player.board.place_ship(ship, x, y, orientation)
      end
    end
  end

  def header_title
    if @campaign_stage
      labels = { 1 => "Missão 1 – Fácil", 2 => "Missão 2 – Médio", 3 => "Missão 3 – Difícil" }
      "CAMPANHA: #{labels[@campaign_stage] || 'Batalha'}"
    else
      "BATALHA NAVAL"
    end
  end

  # Lógica de turnos

  # Converte clique do mouse em coordenada do grid inimigo e dispara
  def handle_player_click
    mx = @window.mouse_x
    my = @window.mouse_y

    # Origem real do grid = ENEMY_GRID + LABEL_OFFSET
    grid_ox = ENEMY_GRID_X + LABEL_OFFSET
    grid_oy = ENEMY_GRID_Y + LABEL_OFFSET

    x = ((mx - grid_ox) / CELL_SIZE).to_i
    y = ((my - grid_oy) / CELL_SIZE).to_i

    return unless @ai.board.inside_bounds?(x, y)

    result = @turn_manager.player_shoot(x, y)

    case result
    when :REPEATED, :INVALID
      @status_message = "Já atirou aqui! Escolha outra célula."
    when :WATER
      @status_message = "Água! Vez da IA..."
    when :DAMAGED
      ship = @turn_manager.last_ship
      @status_message = "Acertou! #{ship&.class&.name} danificado. Atire de novo!"
      register_shot(result, ship)
    when :DESTROYED
      ship = @turn_manager.last_ship
      @status_message = "#{ship&.class&.name} DESTRUÍDO! Atire de novo!"
      register_shot(result, ship)
    end

    check_game_over
  end

  # Executa o turno da IA e atualiza mensagem de status
  def execute_ai_turn
    result, ship, x, y = @turn_manager.ai_turn

    coord_str = x && y ? "(#{x}, #{y})" : "?"

    case result
    when :WATER
      @status_message = "IA atirou em #{coord_str} — Água! Sua vez."
    when :DAMAGED
      @status_message = "IA atirou em #{coord_str} — ACERTOU! IA atira de novo..."
    when :DESTROYED
      @status_message = "IA atirou em #{coord_str} — #{ship&.class&.name} DESTRUÍDO! IA atira de novo..."
    when :GAME_OVER
      check_game_over
      return
    end

    check_game_over
  end

  def check_game_over
    return unless @turn_manager.game_over?
    @game_over = true

    won   = @turn_manager.winner == :player
    score = calculate_score(won)

    @status_message = won ? "Vitória! Você afundou todos os navios do inimigo!" : "Derrota! Todos os seus navios afundaram."

    register_end(player_fleet: @player.fleet, won: won, score: score)

    # Notifica o GameWindow para atualizar o progresso de campanha
    if @campaign_stage && won
      @window.on_campaign_mission_won(@campaign_stage)
    end
  end

  def calculate_score(won)
    base   = won ? 1000 : 0
    bonus  = @ai.fleet.count { |s| s.status == Ship::DESTROYED } * 100
    base + bonus
  end

  # Desenho dos grids

  CELL_COLOR_WATER     = Gosu::Color.new(0xff_1e3a5f)
  CELL_COLOR_HIT       = Gosu::Color.new(0xff_e53e3e)
  CELL_COLOR_MISS      = Gosu::Color.new(0xff_4a5568)
  CELL_COLOR_SHIP      = Gosu::Color.new(0xff_2b6cb0)
  CELL_COLOR_DESTROYED = Gosu::Color.new(0xff_742a2a)
  CELL_COLOR_HOVER     = Gosu::Color.new(0x88_ffd700)
  CELL_GRID_COLOR      = Gosu::Color.new(0xff_0a1628)
  CELL_GAP             = 2
  LABEL_COLOR          = Gosu::Color.new(0xff_94a3b8)
  # Espaço reservado para os labels laterais (números) e superiores (letras)
  LABEL_OFFSET         = 16

  def draw_player_grid
    # "SUA FROTA" acima dos labels
    @info_font.draw_text("SUA FROTA", PLAYER_GRID_X, PLAYER_GRID_Y - 20, 2, 1.0, 1.0, Theme::COLOR_ACCENT)
    gx = PLAYER_GRID_X + LABEL_OFFSET   # grid começa após os números laterais
    gy = PLAYER_GRID_Y + LABEL_OFFSET   # grid começa após as letras superiores
    grid_px = 10 * CELL_SIZE
    @window.draw_rect(gx, gy, grid_px, grid_px, CELL_GRID_COLOR)
    draw_grid_labels(gx, gy)
    draw_grid(@player.board, gx, gy, show_ships: true, interactive: false)
  end

  def draw_enemy_grid
    label = @turn_manager&.current_turn == :player ? "FROTA INIMIGA  ← clique para atirar" : "FROTA INIMIGA  (IA pensando...)"
    @info_font.draw_text(label, ENEMY_GRID_X, ENEMY_GRID_Y - 20, 2, 1.0, 1.0, Theme::COLOR_ACCENT)
    gx = ENEMY_GRID_X + LABEL_OFFSET
    gy = ENEMY_GRID_Y + LABEL_OFFSET
    grid_px = 10 * CELL_SIZE
    @window.draw_rect(gx, gy, grid_px, grid_px, CELL_GRID_COLOR)
    draw_grid_labels(gx, gy)
    draw_grid(@ai.board, gx, gy, show_ships: false, interactive: true)
  end

  # Desenha letras A-J acima e números 1-10 à esquerda do grid.
  # ox/oy são a origem do próprio grid, o canto superior esquerdo da célula A1. As labels ficam fora dessa área.
  def draw_grid_labels(ox, oy)
    col_letters = %w[A B C D E F G H I J]

    col_letters.each_with_index do |letter, i|
      lx = ox + i * CELL_SIZE + (CELL_SIZE - @grid_font.text_width(letter)) / 2
      ly = oy - LABEL_OFFSET + 2
      @grid_font.draw_text(letter, lx, ly, 2, 1.0, 1.0, LABEL_COLOR)
    end

    10.times do |i|
      num   = (i + 1).to_s
      lx    = ox - LABEL_OFFSET + (LABEL_OFFSET - @grid_font.text_width(num)) / 2
      ly    = oy + i * CELL_SIZE + (CELL_SIZE - @grid_font.height) / 2
      @grid_font.draw_text(num, lx, ly, 2, 1.0, 1.0, LABEL_COLOR)
    end
  end

  def draw_grid(board, ox, oy, show_ships:, interactive:)
    cell_inner = CELL_SIZE - CELL_GAP   # 28px de conteúdo + 2px de grade

    10.times do |y|
      10.times do |x|
        cx = ox + x * CELL_SIZE + 1
        cy = oy + y * CELL_SIZE + 1

        content  = board.status_at(x, y)
        is_water = water_cell?(content, show_ships)

        # Hover no grid inimigo (somente células ainda não atiradas)
        hover = false
        if interactive && !@game_over && @turn_manager.current_turn == :player
          hit_x = ox + x * CELL_SIZE
          hit_y = oy + y * CELL_SIZE
          mx = @window.mouse_x
          my = @window.mouse_y
          hover = mx.between?(hit_x, hit_x + CELL_SIZE - 1) &&
                  my.between?(hit_y, hit_y + CELL_SIZE - 1)
        end

        if is_water && @water_tile
          # Recorta o tile de água para o tamanho da célula usando draw com subimagem
          # Usa scale para ajustar o tile
          scale = cell_inner.to_f / @water_tile.width
          @water_tile.draw(cx, cy, 1, scale, scale)
          # Overlay de hover dourado por cima do tile
          @window.draw_rect(cx, cy, cell_inner, cell_inner, CELL_COLOR_HOVER) if hover
        else
          # Células de navio, acerto, erro ou fallback sem sprite
          color = hover ? CELL_COLOR_HOVER : cell_color(content, show_ships)
          @window.draw_rect(cx, cy, cell_inner, cell_inner, color)
        end
      end
    end
  end

  # Retorna true se a célula deve exibir água
  def water_cell?(content, show_ships)
    case content
    when Board::WATER
      true   # água pura
    else
      # Navio da IA que está oculto para o jogador também parece água
      content.is_a?(Ship) && !show_ships && content.status != Ship::DESTROYED
    end
  end

  def cell_color(content, show_ships)
    case content
    when Board::MISS  then CELL_COLOR_MISS
    when Board::HIT   then CELL_COLOR_HIT
    when Board::WATER then CELL_COLOR_WATER
    else
      if content.is_a?(Ship)
        if content.status == Ship::DESTROYED
          CELL_COLOR_DESTROYED
        elsif show_ships
          CELL_COLOR_SHIP
        else
          CELL_COLOR_WATER  # oculta navios da IA
        end
      else
        CELL_COLOR_WATER
      end
    end
  end

  # Status bar
  def draw_status_bar
    bar_y = 95
    @window.draw_rect(0, bar_y, @window.width, 28, Gosu::Color.new(0xff_1a202c))
    @info_font.draw_text(@status_message.to_s, 10, bar_y + 5, 2, 1.0, 1.0, Theme::COLOR_TEXT)

    turn_text = @turn_manager ? "Vez: #{@turn_manager.current_turn == :player ? 'JOGADOR' : 'IA'}" : ""
    tw = @info_font.text_width(turn_text)
    @info_font.draw_text(turn_text, @window.width - tw - 10, bar_y + 5, 2, 1.0, 1.0, Theme::COLOR_ACCENT)
  end

  # Informações de frota

  def draw_fleet_info
    base_y = PLAYER_GRID_Y + LABEL_OFFSET + 10 * CELL_SIZE + 8
    alive  = @player.fleet.count { |s| s.status != Ship::DESTROYED }
    sunk   = @ai.fleet.count    { |s| s.status == Ship::DESTROYED }

    @info_font.draw_text("Seus navios vivos: #{alive}/#{@player.fleet.size}", PLAYER_GRID_X, base_y, 2, 1.0, 1.0, Theme::COLOR_TEXT)
    @info_font.draw_text("Navios inimigos afundados: #{sunk}/#{@ai.fleet.size}", ENEMY_GRID_X, base_y, 2, 1.0, 1.0, Theme::COLOR_TEXT)
  end

  # Game Over

  def draw_game_over_overlay
    won = @turn_manager.winner == :player

    # Z alto para aparecer na frente de todos os elementos
    z = 10
    overlay_color = Gosu::Color.new(0xcc_000000)
    @window.draw_rect(0, 0, @window.width, @window.height, overlay_color, z)

    result_text  = won ? "VITÓRIA!" : "DERROTA"
    result_color = won ? Theme::COLOR_ACCENT : Gosu::Color.new(0xff_e53e3e)

    # Caixa central
    box_w = 500
    box_h = 280
    box_x = (@window.width  - box_w) / 2
    box_y = (@window.height - box_h) / 2
    @window.draw_rect(box_x, box_y, box_w, box_h, Gosu::Color.new(0xee_0d1f35), z + 1)
    @window.draw_rect(box_x, box_y, box_w, 4, result_color, z + 2)

    # Título
    tx = box_x + (box_w - @title_font.text_width(result_text)) / 2
    @title_font.draw_text(result_text, tx, box_y + 20, z + 3, 1.0, 1.0, result_color)

    # Mensagem
    msg = @status_message.to_s
    mx2 = box_x + (box_w - @btn_font.text_width(msg)) / 2
    @btn_font.draw_text(msg, mx2, box_y + 95, z + 3, 1.0, 1.0, Theme::COLOR_TEXT)

    # Mensagem extra de campanha
    if @campaign_stage && won && @campaign_stage < 3
      extra = "Próxima missão desbloqueada!"
      ex = box_x + (box_w - @info_font.text_width(extra)) / 2
      @info_font.draw_text(extra, ex, box_y + 130, z + 3, 1.0, 1.0, Theme::COLOR_ACCENT)
    elsif @campaign_stage && won && @campaign_stage >= 3
      extra = "Campanha completa! Você é o almirante!"
      ex = box_x + (box_w - @info_font.text_width(extra)) / 2
      @info_font.draw_text(extra, ex, box_y + 130, z + 3, 1.0, 1.0, Theme::COLOR_ACCENT)
    end

    # Botões
    btn_w = 200
    btn_h = 44
    gap   = 30
    total = btn_w * 2 + gap
    bx    = (@window.width - total) / 2
    by    = box_y + box_h - btn_h - 20

    if @campaign_stage
      draw_btn_z("Voltar à Campanha", bx,            by, btn_w, btn_h, z + 4)
      draw_btn_z("Menu Principal",    bx + btn_w + gap, by, btn_w, btn_h, z + 4)
    else
      draw_btn_z("Jogar Novamente",   bx,            by, btn_w, btn_h, z + 4)
      draw_btn_z("Menu Principal",    bx + btn_w + gap, by, btn_w, btn_h, z + 4)
    end
  end

  # Versão de draw_btn que respeita z-index para aparecer na frente do overlay de Game Over
  def draw_btn_z(text, x, y, w, h, z)
    mx = @window.mouse_x
    my = @window.mouse_y
    is_hover = mx.between?(x, x + w) && my.between?(y, y + h)

    bg     = is_hover ? Theme::COLOR_HOVER : Theme::COLOR_BTN
    border = is_hover ? Theme::COLOR_ACCENT : Gosu::Color.new(0xff_334155)
    t = 2

    @window.draw_rect(x, y, w, h, bg, z)
    @window.draw_rect(x, y,         w, t, border, z + 1)
    @window.draw_rect(x, y + h - t, w, t, border, z + 1)
    @window.draw_rect(x, y,         t, h, border, z + 1)
    @window.draw_rect(x + w - t, y, t, h, border, z + 1)

    tx = x + (w - @btn_font.text_width(text)) / 2
    ty = y + (h - @btn_font.height) / 2
    @btn_font.draw_text(text, tx, ty, z + 2, 1.0, 1.0, Theme::COLOR_TEXT)
  end

  def handle_game_over_input(id)
    return unless id == Gosu::MS_LEFT

    mx = @window.mouse_x
    my = @window.mouse_y

    btn_w = 200
    btn_h = 44
    gap   = 30
    total = btn_w * 2 + gap
    bx    = (@window.width - total) / 2

    box_h = 280
    box_y = (@window.height - box_h) / 2
    by    = box_y + box_h - btn_h - 20

    left_hover  = mx.between?(bx,            bx + btn_w)            && my.between?(by, by + btn_h)
    right_hover = mx.between?(bx + btn_w + gap, bx + btn_w * 2 + gap) && my.between?(by, by + btn_h)

    if @campaign_stage
      @window.request_screen(:campaign) if left_hover
      @window.request_screen(:menu)     if right_hover
    else
      @window.request_screen(:dynamic)  if left_hover
      @window.request_screen(:menu)     if right_hover
    end
  end

  def flush_notifications
    newly = @achievement_manager.newly_unlocked.dup
    @achievement_manager.newly_unlocked.clear
    newly.each { |key| @notification.enqueue(key) }
  end
end