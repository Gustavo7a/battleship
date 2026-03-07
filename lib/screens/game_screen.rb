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
require_relative '../engine/movement_mechanics'
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

  # Fases do turno do jogador
  PHASE_MOVE  = :move    # pode mover UM navio INTACTO (opcional) — depois ainda pode atirar
  PHASE_SHOOT = :shoot   # atira no tabuleiro inimigo

  # Origem do grid do INIMIGO (jogador clica aqui para atirar)
  ENEMY_GRID_X = 420
  ENEMY_GRID_Y = 110

  # Origem do grid do JOGADOR (visual de referência)
  PLAYER_GRID_X = 20
  PLAYER_GRID_Y = 110

  # Y inicial do painel inferior (abaixo dos dois grids)
  BOTTOM_PANEL_Y = 110 + 16 + 10 * 30 + 6   # GRID_Y + LABEL_OFFSET + grid_height + margem

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

    @status_message = "Selecione um navio para mover (ou pule) e depois atire!"
    @game_over      = false
    @ai_timer       = 0
    @grid_font      = Gosu::Font.new(11)

    # Movimento de navios: disponível APENAS no modo dinâmico (sem campanha)
    @movement_enabled = @campaign_stage.nil?

    # Fase do turno: começa em MOVE só se o movimento estiver habilitado
    @turn_phase    = @movement_enabled ? PHASE_MOVE : PHASE_SHOOT
    @selected_ship = nil

    # Histórico das últimas ações (máx 4 linhas) exibido no painel inferior
    @action_log     = []

    # Controle interno do turno da IA: :decide -> :move_done ou :shoot
    @ai_phase       = :decide

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

    if @turn_manager.current_turn == :ai
      @ai_timer += 1
      if @ai_timer >= 40
        @ai_timer = 0
        execute_ai_turn
      end
    end
  end

  def draw
    draw_header(header_title)

    draw_player_grid
    draw_enemy_grid
    draw_bottom_panel

    @notification.draw(@window.width)

    draw_game_over_overlay if @game_over
  end

  # Input

  def button_down(id)
    if @game_over
      handle_game_over_input(id)
      return
    end

    return unless @turn_manager.current_turn == :player

    if id == Gosu::MS_LEFT
      handle_player_click
    end

    # Teclas de direção: movem o navio selecionado (fase MOVE, só modo dinâmico)
    if @movement_enabled && @turn_phase == PHASE_MOVE && @selected_ship
      dir = { Gosu::KB_UP => :up, Gosu::KB_DOWN => :down,
              Gosu::KB_LEFT => :left, Gosu::KB_RIGHT => :right }[id]
      apply_movement(dir) if dir
    end

    # ENTER ou ESPAÇO: pula a fase de movimento (só modo dinâmico)
    if @movement_enabled && @turn_phase == PHASE_MOVE && (id == Gosu::KB_RETURN || id == Gosu::KB_SPACE)
      skip_movement
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
    @turn_manager     = TurnManager.new(@player, @ai)
    @move_mechanics   = MovementMechanics.new(@player.board)
  end

  def player_name
    @current_user ? @current_user['username'] : "Player"
  end

  def build_ai
    case @difficulty
    when :easy   then EasyBot.new
    when :hard   then HardBot.new
    when :medium then MediumBot.new
    else
      # Modo dinâmico (sem dificuldade definida): usa HardBot
      # Campanha sem dificuldade explícita: usa MediumBot como fallback
      @campaign_stage ? MediumBot.new : HardBot.new
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

  # Roteador principal do clique do jogador: decide se é MOVER ou DISPARAR
  def handle_player_click
    mx = @window.mouse_x
    my = @window.mouse_y

    if @movement_enabled && @turn_phase == PHASE_MOVE
      handle_move_click(mx, my)
    else
      handle_shoot_click(mx, my)
    end
  end

  # --- Fase MOVER ---

  # Clique no grid do JOGADOR seleciona um navio; clique no botão "Pular" pula a fase
  def handle_move_click(mx, my)
    # Botão "Pular" — posição espelhada do draw_bottom_panel
    skip_bx = PLAYER_GRID_X
    skip_by = BOTTOM_PANEL_Y + 10 + 22   # panel_y + 10 (frota) + 22 (linha frota)
    if over_skip_button_at?(skip_bx, skip_by, 150, 34)
      skip_movement
      return
    end

    # Clique numa célula do grid do jogador → seleciona navio
    gx = PLAYER_GRID_X + LABEL_OFFSET
    gy = PLAYER_GRID_Y + LABEL_OFFSET
    x = ((mx - gx) / CELL_SIZE).to_i
    y = ((my - gy) / CELL_SIZE).to_i

    return unless @player.board.inside_bounds?(x, y)
    return if mx < gx || my < gy   # clique na área de label

    content = @player.board.status_at(x, y)
    if content.is_a?(Ship) && content.status == Ship::INTACT
      @selected_ship = content
      log_action("#{content.class.name} selecionado — use ↑↓←→ para mover.")
    elsif content.is_a?(Ship) && content.status == Ship::DAMAGED
      log_action("#{content.class.name} já foi acertado e não pode ser movido!")
    end
  end

  # Aplica o movimento do navio selecionado na direção dada.
  # Após mover, o jogador ainda pode atirar neste turno.
  def apply_movement(direction)
    result = @move_mechanics.move(@selected_ship, direction)
    case result
    when :moved
      log_action("Você moveu #{@selected_ship.class.name}. Agora atire!")
      @selected_ship = nil
      @turn_phase    = PHASE_SHOOT
    when :out_of_bounds
      log_action("Movimento inválido — fora do tabuleiro!")
    when :collision
      log_action("Movimento inválido — outro navio no caminho!")
    when :damaged_ship
      log_action("Não pode mover — navio já foi acertado!")
    when :already_destroyed
      log_action("Este navio foi destruído!")
    when :already_moved
      log_action("Você já moveu um navio neste turno!")
    else
      log_action("Movimento inválido.")
    end
  end

  # Pula a fase de movimento e vai direto para o disparo
  def skip_movement
    @selected_ship  = nil
    @turn_phase     = PHASE_SHOOT
    log_action("Movimento pulado — clique no tabuleiro inimigo para atirar.")
  end

  # --- Fase DISPARAR ---

  # Converte clique do mouse em coordenada do grid inimigo e dispara
  def handle_shoot_click(mx, my)
    # Origem real do grid = ENEMY_GRID + LABEL_OFFSET
    grid_ox = ENEMY_GRID_X + LABEL_OFFSET
    grid_oy = ENEMY_GRID_Y + LABEL_OFFSET

    x = ((mx - grid_ox) / CELL_SIZE).to_i
    y = ((my - grid_oy) / CELL_SIZE).to_i

    return unless @ai.board.inside_bounds?(x, y)
    return if mx < grid_ox || my < grid_oy   # clique na área de label

    result = @turn_manager.player_shoot(x, y)

    case result
    when :REPEATED, :INVALID
      log_action("Já atirou aqui! Escolha outra célula.")
    when :WATER
      log_action("Você atirou em (#{x + 1}, #{y + 1}) — Água! Vez da IA.")
      start_player_turn
    when :DAMAGED
      ship = @turn_manager.last_ship
      log_action("Você acertou #{ship&.class&.name}! Atire de novo.")
      register_shot(result, ship)
    when :DESTROYED
      ship = @turn_manager.last_ship
      log_action("Você DESTRUIU #{ship&.class&.name}! Atire de novo.")
      register_shot(result, ship)
    end

    check_game_over
  end

  # Reinicia as variáveis de movimento para um novo turno do jogador
  def start_player_turn
    @turn_phase    = @movement_enabled ? PHASE_MOVE : PHASE_SHOOT
    @selected_ship = nil
    @move_mechanics.new_turn if @movement_enabled
  end

  # Executa o turno da IA em duas fases com timer separado:
  #   :decide — (só modo dinâmico) tenta mover um navio. Depois passa para :shoot.
  #   :shoot  — dispara.
  def execute_ai_turn
    if @ai_phase == :decide
      if @movement_enabled
        @ai.new_turn
        log_action("IA moveu um navio.") if @ai.try_move_ship
      end
      @ai_phase = :shoot
      return   # aguarda próximo tick do timer para atirar
    end

    # Fase :shoot — IA atira
    @ai_phase = :decide   # reset para o próximo turno

    result, ship, x, y = @turn_manager.ai_turn
    coord_str = x && y ? "(#{x + 1}, #{y + 1})" : "?"

    case result
    when :WATER
      log_action("IA atirou em #{coord_str} — Água!")
      start_player_turn
    when :DAMAGED
      log_action("IA atirou em #{coord_str} — Acertou #{ship&.class&.name}!")
    when :DESTROYED
      log_action("IA DESTRUIU #{ship&.class&.name}!")
      start_player_turn if @turn_manager.current_turn == :player
    when :GAME_OVER
      check_game_over
      return
    else
      start_player_turn
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
  CELL_COLOR_SELECTED  = Gosu::Color.new(0xff_00e5ff)   # ciano — navio selecionado para mover
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

        # Navio selecionado para mover: destaque ciano (só modo dinâmico)
        is_selected = @movement_enabled && !interactive && @selected_ship &&
                      content.is_a?(Ship) && content.equal?(@selected_ship)

        # Hover no grid inimigo (somente células ainda não atiradas)
        hover = false
        if interactive && !@game_over && @turn_manager.current_turn == :player && @turn_phase == PHASE_SHOOT
          hit_x = ox + x * CELL_SIZE
          hit_y = oy + y * CELL_SIZE
          mx = @window.mouse_x
          my = @window.mouse_y
          hover = mx.between?(hit_x, hit_x + CELL_SIZE - 1) &&
                  my.between?(hit_y, hit_y + CELL_SIZE - 1)
        end

        if is_selected
          @window.draw_rect(cx, cy, cell_inner, cell_inner, CELL_COLOR_SELECTED)
        elsif is_water && @water_tile
          scale = cell_inner.to_f / @water_tile.width
          @water_tile.draw(cx, cy, 1, scale, scale)
          @window.draw_rect(cx, cy, cell_inner, cell_inner, CELL_COLOR_HOVER) if hover
        else
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

  # ── Painel Inferior Unificado ──────────────────────────────────────────────

  # Desenha o painel abaixo dos grids com: turno atual, log de ações,
  # contadores de frota e (se for fase MOVE) o botão de pular + dica.
  def draw_bottom_panel
    panel_y = BOTTOM_PANEL_Y
    panel_h = @window.height - panel_y
    panel_w = @window.width

    # Fundo escuro do painel
    @window.draw_rect(0, panel_y, panel_w, panel_h, Gosu::Color.new(0xff_0d1f35), 1)
    # Linha separadora no topo do painel
    @window.draw_rect(0, panel_y, panel_w, 2, Gosu::Color.new(0xff_1e4a7a), 2)

    # ── Coluna esquerda: alinhada com o grid do jogador ──
    left_x = PLAYER_GRID_X
    y      = panel_y + 10

    alive = @player.fleet.count { |s| s.status != Ship::DESTROYED }
    @info_font.draw_text("Seus navios vivos: #{alive}/#{@player.fleet.size}",
                         left_x, y, 2, 1.0, 1.0, Theme::COLOR_TEXT)
    y += 24

    # Botão Pular + dica (só no modo dinâmico, fase MOVE, vez do jogador)
    if @movement_enabled && !@game_over && @turn_manager&.current_turn == :player && @turn_phase == PHASE_MOVE
      draw_skip_button(left_x, y)
      y += 42
      if @selected_ship
        hint = "#{@selected_ship.class.name} selecionado — ↑ ↓ ← → para mover"
        @info_font.draw_text(hint, left_x, y, 2, 1.0, 1.0, CELL_COLOR_SELECTED)
      else
        @info_font.draw_text("Clique num navio da SUA FROTA para selecionar",
                             left_x, y, 2, 1.0, 1.0, LABEL_COLOR)
      end
    end

    # ── Coluna direita: alinhada com o grid inimigo ──
    right_x = ENEMY_GRID_X
    ry      = panel_y + 10

    sunk = @ai.fleet.count { |s| s.status == Ship::DESTROYED }
    @info_font.draw_text("Navios inimigos afundados: #{sunk}/#{@ai.fleet.size}",
                         right_x, ry, 2, 1.0, 1.0, Theme::COLOR_TEXT)
    ry += 24

    turn_label = @turn_manager&.current_turn == :player ? "◆ Sua vez" : "◆ IA pensando..."
    turn_color = @turn_manager&.current_turn == :player ? Theme::COLOR_ACCENT : Gosu::Color.new(0xff_94a3b8)
    @info_font.draw_text(turn_label, right_x, ry, 2, 1.0, 1.0, turn_color)
    ry += 26

    # ── Log de ações: abaixo de "Sua vez", alinhado à direita ──
    @info_font.draw_text("Últimas ações:", right_x, ry, 2, 1.0, 1.0, LABEL_COLOR)
    ry += 20
    @action_log.last(4).each_with_index do |entry, i|
      color = (i == @action_log.last(4).size - 1) ? Theme::COLOR_TEXT : Gosu::Color.new(0xff_64748b)
      @info_font.draw_text("• #{entry}", right_x, ry + i * 20, 2, 1.0, 1.0, color)
    end
  end

  # Botão "Pular [ENTER]" desenhado no painel inferior
  def draw_skip_button(bx, by)
    bw = 150
    bh = 34
    hover  = over_skip_button_at?(bx, by, bw, bh)
    bg     = hover ? Theme::COLOR_HOVER  : Gosu::Color.new(0xff_14421a)
    border = hover ? Theme::COLOR_ACCENT : Gosu::Color.new(0xff_2d6a2d)
    t = 2

    @window.draw_rect(bx, by, bw, bh, bg, 2)
    @window.draw_rect(bx,          by,          bw, t, border, 3)
    @window.draw_rect(bx,          by + bh - t, bw, t, border, 3)
    @window.draw_rect(bx,          by,          t,  bh, border, 3)
    @window.draw_rect(bx + bw - t, by,          t,  bh, border, 3)

    label = "Pular [ENTER]"
    tx = bx + (bw - @btn_font.text_width(label)) / 2
    ty = by + (bh - @btn_font.height) / 2
    @btn_font.draw_text(label, tx, ty, 3, 1.0, 1.0, Theme::COLOR_TEXT)
  end

  def over_skip_button_at?(bx, by, bw, bh)
    mx = @window.mouse_x
    my = @window.mouse_y
    mx.between?(bx, bx + bw) && my.between?(by, by + bh)
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

  # Registra uma ação no log do painel inferior (máx 8 entradas)
  def log_action(msg)
    @action_log << msg
    @action_log.shift if @action_log.size > 8
  end

  def flush_notifications
    newly = @achievement_manager.newly_unlocked.dup
    @achievement_manager.newly_unlocked.clear
    newly.each { |key| @notification.enqueue(key) }
  end
end