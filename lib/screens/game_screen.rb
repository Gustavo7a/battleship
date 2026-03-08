require_relative 'base_screen'
require_relative '../models/board'
require_relative '../models/player'
require_relative '../models/ai/easy_bot'
require_relative '../models/ai/medium_bot'
require_relative '../models/ai/hard_bot'
require_relative '../models/ai/impossible_bot'
require_relative '../models/ships/ship'
require_relative '../models/ships/flattop'
require_relative '../models/ships/warship'
require_relative '../models/ships/battleship'
require_relative '../models/ships/submarine'
require_relative '../engine/turn_manager'
require_relative '../engine/movement_mechanics'
require_relative '../engine/achievement_manager'
require_relative '../ui/achievement_notification'
require_relative '../ui/explosion_animation'

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

  # Fases do turno do jogador
  PHASE_MOVE  = :move    # pode mover UM navio INTACTO (opcional) — depois ainda pode atirar
  PHASE_SHOOT = :shoot   # atira no tabuleiro inimigo

  # Layout calculado dinamicamente em compute_layout (todos como @vars de instância):
  # @cs  — cell size         @lo  — label offset
  # @pgx — player grid X     @pgy — player grid Y
  # @egx — enemy grid X      @egy — enemy grid Y
  # @bpy — bottom panel Y

  def initialize(window, current_user: nil, campaign_stage: nil, difficulty: nil,
                 pre_placed_fleet: nil, pre_placed_board: nil)
    super(window)

    @current_user     = current_user
    @campaign_stage   = campaign_stage
    @difficulty       = difficulty
    @pre_placed_fleet = pre_placed_fleet    # Array<Ship> já posicionados
    @pre_placed_board = pre_placed_board    # Board já montado

    @achievement_manager = @window.achievement_manager
    @achievement_manager.reset_session
    @notification = AchievementNotification.new
    @explosion    = ExplosionAnimation.new
    @sfx_hit      = Gosu::Sample.new(File.join('assets', 'sfx', 'shoot.wav'))
    @sfx_splash   = Gosu::Sample.new(File.join('assets', 'sfx', 'water_splash.wav'))
    @game_start   = Time.now

    @status_message = "Selecione um navio para mover (ou pule) e depois atire!"
    @game_over      = false
    @paused         = false
    @ai_timer       = 0

    # Movimento de navios: disponível APENAS no modo dinâmico (sem campanha)
    @movement_enabled = @campaign_stage.nil?

    # Fase do turno: começa em MOVE só se o movimento estiver habilitado
    @turn_phase    = @movement_enabled ? PHASE_MOVE : PHASE_SHOOT
    @selected_ship = nil

    # Histórico das últimas ações (máx 4 linhas) exibido no painel inferior
    @action_log     = []

    # Controle interno do turno da IA: :decide -> :move_done ou :shoot
    @ai_phase       = :decide

    load_ship_sprites
    compute_layout   # layout inicial; recomputa automaticamente se a janela mudar
    setup_game
  end

  # Loop principal
  def update
    @notification.update
    @explosion.update
    return if @game_over || @paused

    if @turn_manager.current_turn == :ai
      @ai_timer += 1
      if @ai_timer >= 40
        @ai_timer = 0
        execute_ai_turn
      end
    end
  end

  def draw
    compute_layout_if_needed
    draw_header(header_title)

    draw_player_grid
    draw_enemy_grid
    draw_bottom_panel

    @explosion.draw
    @notification.draw(@window.width)

    draw_pause_button
    draw_pause_overlay if @paused
    draw_game_over_overlay if @game_over
  end

  # Input

  def button_down(id)
    compute_layout_if_needed

    if @paused
      handle_pause_input(id)
      return
    end

    if @game_over
      handle_game_over_input(id)
      return
    end

    return unless @turn_manager.current_turn == :player

    if id == Gosu::MS_LEFT
      mx = @window.mouse_x
      my = @window.mouse_y
      pb = pause_btn_rect
      if mx.between?(pb[:x], pb[:x] + pb[:w]) && my.between?(pb[:y], pb[:y] + pb[:h])
        @paused = true
        return
      end
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

  # ESC: pausa (ou despausa) durante a partida
  def handle_escape
    if @paused
      @paused = false
    elsif !@game_over
      @paused = true
    else
      @window.request_screen(:menu)
    end
  end

  # Resultado da partida

  def register_shot(result, ship = nil)
    @achievement_manager.register_shot(result, ship)
    flush_notifications
  end

  def register_end(player_fleet:, won:, score: 0)
    if won
      newly = @achievement_manager.register_victory(player_fleet)
      newly.each { |key| @notification.enqueue(key) }
    end

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
    when :easy       then EasyBot.new
    when :hard       then HardBot.new
    when :medium     then MediumBot.new
    when :impossible then ImpossibleBot.new
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
    skip_bx = @pgx
    skip_by = @bpy + 10 + @info_font.height + 6
    skip_bw = @btn_font.text_width("Pular [ENTER]") + 24
    skip_bh = @btn_font.height + 12
    if over_skip_button_at?(skip_bx, skip_by, skip_bw, skip_bh)
      skip_movement
      return
    end

    # Clique numa célula do grid do jogador → seleciona navio
    gx = @pgx + @lo
    gy = @pgy + @lo
    x = ((mx - gx) / @cs).to_i
    y = ((my - gy) / @cs).to_i

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
    # Origem real do grid = ENEMY_GRID + label offset
    grid_ox = @egx + @lo
    grid_oy = @egy + @lo

    x = ((mx - grid_ox) / @cs).to_i
    y = ((my - grid_oy) / @cs).to_i

    return unless @ai.board.inside_bounds?(x, y)
    return if mx < grid_ox || my < grid_oy   # clique na área de label

    result = @turn_manager.player_shoot(x, y)

    if result == :DAMAGED || result == :DESTROYED
      @explosion.trigger(grid_ox + x * @cs, grid_oy + y * @cs, @cs)
      @sfx_hit.play(0.1) if @window.sfx_enabled
    elsif result == :WATER
      @sfx_splash.play(0.1) if @window.sfx_enabled
    end

    # No modo impossível (fase livre), cada tiro encerra o turno do jogador —
    # sem bônus de turno extra por acerto. A vez volta ao bot para que ele consuma
    # um turno livre e só então devolva ao jogador.
    impossible_free_phase = @ai.respond_to?(:pass_turn?) && @ai.pass_turn?

    case result
    when :REPEATED, :INVALID
      log_action("Já atirou aqui! Escolha outra célula.")
    when :WATER
      log_action("Você atirou em (#{x + 1}, #{y + 1}) — Água! Vez da IA.")
      start_player_turn
    when :DAMAGED
      ship = @turn_manager.last_ship
      register_shot(result, ship)
      if impossible_free_phase
        log_action("Você acertou #{ship&.class&.name}! Vez de Davy Jones.")
        @turn_manager.end_player_turn_without_shot
      else
        log_action("Você acertou #{ship&.class&.name}! Atire de novo.")
      end
    when :DESTROYED
      ship = @turn_manager.last_ship
      register_shot(result, ship)
      if impossible_free_phase
        log_action("Você DESTRUIU #{ship&.class&.name}! Vez de Davy Jones.")
        @turn_manager.end_player_turn_without_shot
      else
        log_action("Você DESTRUIU #{ship&.class&.name}! Atire de novo.")
      end
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

    # Davy Jones: durante os turnos livres apenas passa a vez — sem tiro, sem animação
    if @ai.respond_to?(:pass_turn?) && @ai.pass_turn?
      @ai.consume_free_turn
      remaining = @ai.free_turns_remaining
      msg = remaining > 0 ? "☠ Davy Jones aguarda... #{remaining} tiro(s) livre(s) restante(s)." \
                          : "☠ Davy Jones perdeu a paciência! Ele vai atacar no próximo turno!"
      log_action(msg)
      @turn_manager.end_ai_turn_without_shot
      start_player_turn
      return
    end

    result, ship, x, y = @turn_manager.ai_turn
    coord_str = x && y ? "(#{x + 1}, #{y + 1})" : "?"

    if (result == :DAMAGED || result == :DESTROYED) && x && y
      @explosion.trigger(@pgx + @lo + x * @cs, @pgy + @lo + y * @cs, @cs)
      @sfx_hit.play(0.1) if @window.sfx_enabled
    elsif result == :WATER
      @sfx_splash.play(0.1) if @window.sfx_enabled
    end

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
    return if @game_over
    return unless @turn_manager.game_over?

    @game_over = true
    won   = @turn_manager.winner == :player
    score = calculate_score(won)

    @status_message = won ? "Vitória! Você afundou todos os navios do inimigo!" : "Derrota! Todos os seus navios afundaram."

    # Sinaliza conquista Jack Sparrow antes de registrar a vitória
    @achievement_manager.flag_impossible_victory if won && @difficulty == :impossible

    register_end(player_fleet: @player.fleet, won: won, score: score)
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

  def draw_player_grid
    label_y = @pgy - @lo - @info_font.height - 4
    @info_font.draw_text("SUA FROTA", @pgx, label_y, 2, 1.0, 1.0, Theme::COLOR_ACCENT)
    gx = @pgx + @lo
    gy = @pgy + @lo
    grid_px = 10 * @cs
    @window.draw_rect(gx, gy, grid_px, grid_px, CELL_GRID_COLOR)
    draw_grid_labels(gx, gy)
    draw_player_grid_cells(gx, gy)
  end

  def draw_enemy_grid
    label = @turn_manager&.current_turn == :player ? "FROTA INIMIGA  ← clique para atirar" : "FROTA INIMIGA  (IA pensando...)"
    label_y = @egy - @lo - @info_font.height - 4
    @info_font.draw_text(label, @egx, label_y, 2, 1.0, 1.0, Theme::COLOR_ACCENT)
    gx = @egx + @lo
    gy = @egy + @lo
    grid_px = 10 * @cs
    @window.draw_rect(gx, gy, grid_px, grid_px, CELL_GRID_COLOR)
    draw_grid_labels(gx, gy)
    draw_grid(@ai.board, gx, gy, show_ships: false, interactive: true)
    draw_destroyed_enemy_ships(gx, gy)
  end

  # Desenha a grade do jogador em três camadas:
  #   1. Água (fundo) em todas as células
  #   2. Sprites dos navios não-destruídos
  #   3. Overlays de HIT/MISS/DESTROYED e destaque do navio selecionado
  def draw_player_grid_cells(ox, oy)
    cell_inner = @cs - CELL_GAP

    # Camada 1: água em todo o grid
    10.times do |y|
      10.times do |x|
        cx = ox + x * @cs + 1
        cy = oy + y * @cs + 1
        @window.draw_rect(cx, cy, cell_inner, cell_inner, CELL_COLOR_WATER)
      end
    end

    # Camada 2: sprites dos navios vivos/danificados
    @player.fleet.each do |ship|
      next if ship.status == Ship::DESTROYED
      next if ship.positions.empty? || ship.orientation.nil?

      first_x, first_y = ship.positions.first
      px = ox + first_x * @cs + 1
      py = oy + first_y * @cs + 1
      tint = ship.equal?(@selected_ship) ? CELL_COLOR_SELECTED : Gosu::Color::WHITE
      draw_ship_sprite(ship, px, py, ship.orientation, ship.ship_size,
                       @cs, CELL_GAP, z: 2, color: tint)
    end

    # Camada 3: overlays de HIT / MISS / DESTROYED (no topo das sprites)
    10.times do |y|
      10.times do |x|
        content = @player.board.status_at(x, y)
        cx = ox + x * @cs + 1
        cy = oy + y * @cs + 1

        case content
        when Board::HIT
          draw_hit_cell(cx, cy, cell_inner, 3)
        when Board::MISS
          @window.draw_rect(cx, cy, cell_inner, cell_inner, CELL_COLOR_MISS, 3)
          draw_miss_x(cx, cy, cell_inner, 4)
        else
          if content.is_a?(Ship) && content.status == Ship::DESTROYED
            @window.draw_rect(cx, cy, cell_inner, cell_inner, CELL_COLOR_DESTROYED, 3)
          end
        end
      end
    end
  end

  # Desenha letras A-J acima e números 1-10 à esquerda do grid.
  # ox/oy são a origem do próprio grid, o canto superior esquerdo da célula A1. As labels ficam fora dessa área.
  def draw_grid_labels(ox, oy)
    col_letters = %w[A B C D E F G H I J]

    col_letters.each_with_index do |letter, i|
      lx = ox + i * @cs + (@cs - @grid_font.text_width(letter)) / 2
      ly = oy - @lo + 2
      @grid_font.draw_text(letter, lx, ly, 2, 1.0, 1.0, LABEL_COLOR)
    end

    10.times do |i|
      num = (i + 1).to_s
      lx  = ox - @lo + (@lo - @grid_font.text_width(num)) / 2
      ly  = oy + i * @cs + (@cs - @grid_font.height) / 2
      @grid_font.draw_text(num, lx, ly, 2, 1.0, 1.0, LABEL_COLOR)
    end
  end

  def draw_grid(board, ox, oy, show_ships:, interactive:)
    cell_inner = @cs - CELL_GAP

    10.times do |y|
      10.times do |x|
        cx = ox + x * @cs + 1
        cy = oy + y * @cs + 1

        content  = board.status_at(x, y)
        is_water = water_cell?(content, show_ships)

        # Navio selecionado para mover: destaque ciano (só modo dinâmico)
        is_selected = @movement_enabled && !interactive && @selected_ship &&
                      content.is_a?(Ship) && content.equal?(@selected_ship)

        # Hover no grid inimigo (somente células ainda não atiradas)
        hover = false
        if interactive && !@game_over && @turn_manager.current_turn == :player && @turn_phase == PHASE_SHOOT
          hit_x = ox + x * @cs
          hit_y = oy + y * @cs
          mx = @window.mouse_x
          my = @window.mouse_y
          hover = mx.between?(hit_x, hit_x + @cs - 1) &&
                  my.between?(hit_y, hit_y + @cs - 1)
        end

        if is_selected
          @window.draw_rect(cx, cy, cell_inner, cell_inner, CELL_COLOR_SELECTED)
        else
          color = hover ? CELL_COLOR_HOVER : cell_color(content, show_ships)
          @window.draw_rect(cx, cy, cell_inner, cell_inner, color)
          draw_miss_x(cx, cy, cell_inner, 5) if content == Board::MISS
          draw_hit_cell(cx, cy, cell_inner, 5) if content == Board::HIT
        end
      end
    end
  end

  # Desenha as sprites dos navios inimigos completamente destruídos sobre o grid.
  def draw_destroyed_enemy_ships(ox, oy)
    return unless @ai&.fleet
    # z=8: acima do fundo d'água (z=5), borda (z=6) e crosshair (z=7) de draw_hit_cell
    tint = Gosu::Color.new(0xbb_ff9999)
    @ai.fleet.each do |ship|
      next unless ship.status == Ship::DESTROYED
      next if ship.positions.empty? || ship.orientation.nil?

      first_x, first_y = ship.positions.first
      px = ox + first_x * @cs + 1
      py = oy + first_y * @cs + 1
      draw_ship_sprite(ship, px, py, ship.orientation, ship.ship_size,
                       @cs, CELL_GAP, z: 8, color: tint)
    end
  end

  # Desenha uma célula de acerto: fundo de água + contorno vermelho + crosshair.
  def draw_hit_cell(cx, cy, size, z)
    # Fundo de água (sem preenchimento vermelho)
    @window.draw_rect(cx, cy, size, size, CELL_COLOR_WATER, z)
    # Contorno vermelho
    t = 1
    @window.draw_rect(cx,          cy,          size, t,    CELL_COLOR_HIT, z + 1)
    @window.draw_rect(cx,          cy + size-t, size, t,    CELL_COLOR_HIT, z + 1)
    @window.draw_rect(cx,          cy,          t,    size, CELL_COLOR_HIT, z + 1)
    @window.draw_rect(cx + size-t, cy,          t,    size, CELL_COLOR_HIT, z + 1)
    # Crosshair centralizada
    if @crosshair_img
      scale = size.to_f / [@crosshair_img.width, @crosshair_img.height].max
      ix = cx + (size - @crosshair_img.width  * scale) / 2
      iy = cy + (size - @crosshair_img.height * scale) / 2
      @crosshair_img.draw(ix, iy, z + 2, scale, scale)
    end
  end

  # --- Pausa ---

  def pause_btn_rect
    w = 36; h = 28
    { x: 8, y: 8, w: w, h: h }
  end

  def draw_pause_button
    pb = pause_btn_rect
    hover = @window.mouse_x.between?(pb[:x], pb[:x] + pb[:w]) &&
            @window.mouse_y.between?(pb[:y], pb[:y] + pb[:h])
    bg = hover ? Theme::COLOR_HOVER : Gosu::Color.new(0xaa_0d1f35)
    @window.draw_rect(pb[:x], pb[:y], pb[:w], pb[:h], bg, 5)
    font = Gosu::Font.new(18)
    lbl  = "II"
    font.draw_text(lbl, pb[:x] + (pb[:w] - font.text_width(lbl)) / 2,
                   pb[:y] + (pb[:h] - font.height) / 2, 6, 1.0, 1.0, Theme::COLOR_ACCENT)
  end

  def draw_pause_overlay
    z = 10
    @window.draw_rect(0, 0, @window.width, @window.height, Gosu::Color.new(0xbb_000000), z)

    scale = @window.width / 800.0
    box_w = (380 * scale).clamp(340, 520).to_i
    box_h = (340 * scale).clamp(320, 480).to_i
    bx    = (@window.width  - box_w) / 2
    by    = (@window.height - box_h) / 2
    @window.draw_rect(bx, by, box_w, box_h, Gosu::Color.new(0xee_0d1f35), z + 1)
    @window.draw_rect(bx, by, box_w, 4, Theme::COLOR_ACCENT, z + 2)

    pad = (18 * scale).to_i
    title_font = Gosu::Font.new((28 * scale).clamp(24, 38).to_i)
    tx = bx + (box_w - title_font.text_width("PAUSA")) / 2
    title_font.draw_text("PAUSA", tx, by + pad, z + 3, 1.0, 1.0, Theme::COLOR_ACCENT)

    btn_w = (box_w * 0.78).to_i
    btn_h = (42 * scale).clamp(38, 58).to_i
    btn_x = bx + (box_w - btn_w) / 2
    gap   = (14 * scale).to_i
    base_y = by + title_font.height + pad * 2

    music_lbl = @window.music_enabled ? "\u266a Música: LIGADA"  : "\u266a Música: DESLIGADA"
    sfx_lbl   = @window.sfx_enabled   ? "\u26a1 Efeitos: LIGADOS" : "\u26a1 Efeitos: DESLIGADOS"

    draw_btn_z(music_lbl,  btn_x, base_y,                    btn_w, btn_h, z + 3)
    draw_btn_z(sfx_lbl,    btn_x, base_y + (btn_h + gap),    btn_w, btn_h, z + 3)
    draw_btn_z("Continuar",btn_x, base_y + (btn_h + gap) * 2, btn_w, btn_h, z + 3)
    draw_btn_z("Sair para o Menu", btn_x, base_y + (btn_h + gap) * 3, btn_w, btn_h, z + 3)

    @_pause_rects = {
      music:    { x: btn_x, y: base_y,                          w: btn_w, h: btn_h },
      sfx:      { x: btn_x, y: base_y + (btn_h + gap),           w: btn_w, h: btn_h },
      continue: { x: btn_x, y: base_y + (btn_h + gap) * 2,       w: btn_w, h: btn_h },
      quit:     { x: btn_x, y: base_y + (btn_h + gap) * 3,       w: btn_w, h: btn_h }
    }
  end

  def handle_pause_input(id)
    return unless id == Gosu::MS_LEFT
    mx = @window.mouse_x
    my = @window.mouse_y
    return unless @_pause_rects
    @_pause_rects.each do |key, r|
      next unless mx.between?(r[:x], r[:x] + r[:w]) && my.between?(r[:y], r[:y] + r[:h])
      case key
      when :music    then @window.toggle_music
      when :sfx      then @window.toggle_sfx
      when :continue then @paused = false
      when :quit     then @window.request_screen(:menu)
      end
    end
  end

  # Versão de draw_btn com z-index configurável (usada no overlay)
  def draw_btn_z(text, x, y, w, h, z)
    mx = @window.mouse_x; my = @window.mouse_y
    hover = mx.between?(x, x + w) && my.between?(y, y + h)
    bg    = hover ? Theme::COLOR_HOVER : Theme::COLOR_BTN
    @window.draw_rect(x, y, w, h, bg, z)
    t = 2
    border = hover ? Theme::COLOR_ACCENT : Gosu::Color.new(0xff_334155)
    @window.draw_rect(x, y, w, t, border, z + 1)
    @window.draw_rect(x, y + h - t, w, t, border, z + 1)
    @window.draw_rect(x, y, t, h, border, z + 1)
    @window.draw_rect(x + w - t, y, t, h, border, z + 1)
    font = @btn_font
    font.draw_text(text, x + (w - font.text_width(text)) / 2,
                   y + (h - font.height) / 2, z + 1, 1.0, 1.0, Theme::COLOR_TEXT)
  end

  # Desenha um X na célula de erro (tiro na água).
  def draw_miss_x(cx, cy, size, z)
    pad   = (size * 0.2).to_i
    thick = [2, (size * 0.08).to_i].max
    color = Gosu::Color.new(0xff_cbd5e1)

    x1, y1 = cx + pad, cy + pad
    x2, y2 = cx + size - pad, cy + size - pad

    # diagonal \  (vários retângulos finos sobrepostos simulam uma linha)
    steps = size - 2 * pad
    steps.times do |i|
      @window.draw_rect(x1 + i, y1 + i, thick, thick, color, z)
    end
    # diagonal /
    steps.times do |i|
      @window.draw_rect(x2 - i - thick, y1 + i, thick, thick, color, z)
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
    when Board::HIT   then CELL_COLOR_WATER
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
    panel_y = @bpy
    panel_h = @window.height - panel_y
    panel_w = @window.width

    @window.draw_rect(0, panel_y, panel_w, panel_h, Gosu::Color.new(0xff_0d1f35), 1)
    @window.draw_rect(0, panel_y, panel_w, 2, Gosu::Color.new(0xff_1e4a7a), 2)

    lh      = @info_font.height + 16
    pad_top = 16

    # ── Coluna esquerda ──
    left_x = @pgx
    y      = panel_y + pad_top

    alive = @player.fleet.count { |s| s.status != Ship::DESTROYED }
    @info_font.draw_text("Seus navios vivos: #{alive}/#{@player.fleet.size}",
                         left_x, y, 2, 1.0, 1.0, Theme::COLOR_TEXT)
    y += lh

    if @movement_enabled && !@game_over && @turn_manager&.current_turn == :player && @turn_phase == PHASE_MOVE
      draw_skip_button(left_x, y)
      y += @btn_font.height + 16
      if @selected_ship
        @info_font.draw_text("#{@selected_ship.class.name} selecionado — ↑ ↓ ← → para mover",
                             left_x, y, 2, 1.0, 1.0, CELL_COLOR_SELECTED)
      else
        @info_font.draw_text("Clique num navio da SUA FROTA para selecionar",
                             left_x, y, 2, 1.0, 1.0, LABEL_COLOR)
      end
    end

    # Linha divisora vertical
    mid_x = @pgx + @lo + 10 * @cs + (@egx - @pgx - @lo - 10 * @cs) / 2
    @window.draw_rect(mid_x, panel_y + 4, 1, panel_h - 8, Gosu::Color.new(0xff_1e4a7a), 2)

    # ── Coluna direita ──
    right_x = @egx
    ry      = panel_y + pad_top

    sunk = @ai.fleet.count { |s| s.status == Ship::DESTROYED }
    @info_font.draw_text("Navios inimigos afundados: #{sunk}/#{@ai.fleet.size}",
                         right_x, ry, 2, 1.0, 1.0, Theme::COLOR_TEXT)
    ry += lh

    turn_label = @turn_manager&.current_turn == :player ? "◆ Sua vez" : "◆ IA pensando..."
    turn_color = @turn_manager&.current_turn == :player ? Theme::COLOR_ACCENT : Gosu::Color.new(0xff_94a3b8)
    @info_font.draw_text(turn_label, right_x, ry, 2, 1.0, 1.0, turn_color)
  end

  # Botão "Pular [ENTER]" desenhado no painel inferior
  def draw_skip_button(bx, by)
    label = "Pular [ENTER]"
    bw = @btn_font.text_width(label) + 24
    bh = @btn_font.height + 12
    hover  = over_skip_button_at?(bx, by, bw, bh)
    bg     = hover ? Theme::COLOR_HOVER  : Gosu::Color.new(0xff_14421a)
    border = hover ? Theme::COLOR_ACCENT : Gosu::Color.new(0xff_2d6a2d)
    t = 2

    @window.draw_rect(bx, by, bw, bh, bg, 2)
    @window.draw_rect(bx,          by,          bw, t, border, 3)
    @window.draw_rect(bx,          by + bh - t, bw, t, border, 3)
    @window.draw_rect(bx,          by,          t,  bh, border, 3)
    @window.draw_rect(bx + bw - t, by,          t,  bh, border, 3)

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

    # Caixa central (escala com a resolução)
    scale = @window.width / 800.0
    box_w = (500 * scale).clamp(500, 900).to_i
    box_h = (300 * scale).clamp(300, 540).to_i
    box_x = (@window.width  - box_w) / 2
    box_y = (@window.height - box_h) / 2
    @window.draw_rect(box_x, box_y, box_w, box_h, Gosu::Color.new(0xee_0d1f35), z + 1)
    @window.draw_rect(box_x, box_y, box_w, 4, result_color, z + 2)

    # Título
    pad = (20 * scale).to_i
    tx = box_x + (box_w - @title_font.text_width(result_text)) / 2
    @title_font.draw_text(result_text, tx, box_y + pad, z + 3, 1.0, 1.0, result_color)

    # Mensagem
    msg = @status_message.to_s
    mx2 = box_x + (box_w - @btn_font.text_width(msg)) / 2
    @btn_font.draw_text(msg, mx2, box_y + @title_font.height + pad * 2, z + 3, 1.0, 1.0, Theme::COLOR_TEXT)

    # Mensagem extra de campanha
    camp_y = box_y + @title_font.height + @btn_font.height + pad * 3
    if @campaign_stage && won && @campaign_stage < 3
      extra = "Próxima missão desbloqueada!"
      ex = box_x + (box_w - @info_font.text_width(extra)) / 2
      @info_font.draw_text(extra, ex, camp_y, z + 3, 1.0, 1.0, Theme::COLOR_ACCENT)
    elsif @campaign_stage && won && @campaign_stage >= 3
      extra = "Campanha completa! Você é o almirante!"
      ex = box_x + (box_w - @info_font.text_width(extra)) / 2
      @info_font.draw_text(extra, ex, camp_y, z + 3, 1.0, 1.0, Theme::COLOR_ACCENT)
    end

    # Botões
    btn_w = (200 * scale).clamp(200, 320).to_i
    btn_h = (44  * scale).clamp(44,  70).to_i
    gap   = (30  * scale).clamp(30,  50).to_i
    total = btn_w * 2 + gap
    bx    = (@window.width - total) / 2
    by    = box_y + box_h - btn_h - (20 * scale).to_i

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

    scale = @window.width / 800.0
    btn_w = (200 * scale).clamp(200, 320).to_i
    btn_h = (44  * scale).clamp(44,  70).to_i
    gap   = (30  * scale).clamp(30,  50).to_i
    total = btn_w * 2 + gap
    bx    = (@window.width - total) / 2

    box_h = (300 * scale).clamp(300, 540).to_i
    box_y = (@window.height - box_h) / 2
    by    = box_y + box_h - btn_h - (20 * scale).to_i

    left_hover  = mx.between?(bx,            bx + btn_w)            && my.between?(by, by + btn_h)
    right_hover = mx.between?(bx + btn_w + gap, bx + btn_w * 2 + gap) && my.between?(by, by + btn_h)

    if @campaign_stage
      if left_hover
        if @turn_manager.winner == :player
          @window.on_campaign_mission_won(@campaign_stage)
        elsif @difficulty == :impossible
          # Derrota no modo Davy Jones: tela especial
          @window.request_screen(:davy_jones_defeat)
        else
          @window.request_screen(:campaign)
        end
      end
      @window.request_screen(:menu) if right_hover
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

  # Recomputa o layout somente quando as dimensões da janela mudam.
  # Garante re-cálculo após a transição para fullscreen.
  def compute_layout_if_needed
    return if @last_layout_w == @window.width && @last_layout_h == @window.height
    compute_layout
  end

  # Calcula todas as posições e tamanhos a partir das dimensões atuais da janela.
  # Para 1920×1080: cell_size ≈ 73px   Para 800×600: cell_size ≈ 34px
  def compute_layout
    w = @window.width
    h = @window.height

    # O draw_header desenha o título em y=50 (fonte 50px) e a linha em y=105.
    # O rótulo "SUA FROTA" fica acima do grid: reservamos espaço a partir de y=115
    header_h  = 136   # y onde o grid começa (inclui título + linha + margem + rótulo + labels)
    label_gap = 26    # espaço entre "SUA FROTA" e os labels A-J
    side_pad  = [w / 60, 8].max
    gap       = [w / 36, 20].max
    lbl_off   = [w / 72, 16].max.to_i
    bottom_h  = [(h * 0.17).to_i, 100].max

    cell_h = (h - header_h - lbl_off - 8 - bottom_h) / 10
    cell_w = (w - 2 * side_pad - gap - 2 * lbl_off) / 20
    cs     = [cell_h, cell_w].min.to_i

    grid_px       = 10 * cs
    total_grids_w = 2 * (lbl_off + grid_px) + gap
    left_start    = (w - total_grids_w) / 2

    @cs          = cs
    @lo          = lbl_off
    @pgx         = left_start
    @pgy         = header_h
    @egx         = left_start + lbl_off + grid_px + gap
    @egy         = header_h
    @bpy         = header_h + lbl_off + grid_px + 8
    @label_gap   = label_gap

    scale      = w / 800.0
    @grid_font = Gosu::Font.new((cs / 2.6).clamp(12, 26).to_i)
    @info_font = Gosu::Font.new((18 * scale).clamp(16, 28).to_i)
    @btn_font  = Gosu::Font.new((22 * scale).clamp(20, 34).to_i)

    @last_layout_w = w
    @last_layout_h = h
  end
end