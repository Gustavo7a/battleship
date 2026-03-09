require_relative 'base_screen'
require_relative '../models/board'
require_relative '../models/ships/ship'
require_relative '../models/ships/flattop'
require_relative '../models/ships/warship'
require_relative '../models/ships/battleship'
require_relative '../models/ships/submarine'

# Tela de posicionamento da frota antes de cada partida.
class PlacementScreen < BaseScreen
  CELL_SIZE   = 40
  CELL_GAP    = 2
  LABEL_OFF   = 20

  GRID_X = (800 - 420) / 2
  GRID_Y = 72

  BTN_Y   = 502
  BTN_W   = 240
  BTN_H   = 52
  BTN_GAP = 30

  LABEL_COLOR = Gosu::Color.new(0xff_94a3b8)

  COLOR_GRID_BG   = Gosu::Color.new(0xff_0a1628)
  COLOR_SHIP      = Gosu::Color.new(0xff_2b6cb0)
  COLOR_WATER     = Gosu::Color.new(0xff_1e3a5f)

  COLOR_SHIP_INVA = Gosu::Color.argb(170, 229, 62, 62)
  COLOR_SHIP_OK   = Gosu::Color.argb(136, 34, 197, 94)

  COLOR_BTN_SHUFFLE     = Gosu::Color.new(0xff_d97706)
  COLOR_BTN_SHUFFLE_HOV = Gosu::Color.new(0xff_f59e0b)
  COLOR_BTN_PLAY        = Gosu::Color.new(0xff_16a34a)
  COLOR_BTN_PLAY_HOV    = Gosu::Color.new(0xff_22c55e)

  def initialize(window, campaign_stage: nil, difficulty: nil, current_user: nil)
    super(window)

    @campaign_stage = campaign_stage
    @difficulty     = difficulty
    @current_user   = current_user

    @grid_font   = Gosu::Font.new(13)
    @label_font  = Gosu::Font.new(13)
    @title_font2 = Gosu::Font.new(28, bold: true)
    @sub_font    = Gosu::Font.new(15)
    @btn_font2   = Gosu::Font.new(22, bold: true)

    load_ship_sprites

    @dragging_ship  = nil
    @drag_ori       = nil # Guarda a orientação "voadora" enquanto arrastamos
    @drag_offset_x  = 0
    @drag_offset_y  = 0
    @drag_col       = nil
    @drag_row       = nil

    build_fleet_and_place
  end

  def update
    if @dragging_ship
      col, row = pixel_to_cell(@window.mx, @window.my)
      @drag_col = col - @drag_offset_x
      @drag_row = row - @drag_offset_y
    end
  end

  def draw
    draw_background

    draw_centered_text("Posicione seus navios", 10, Theme::COLOR_ACCENT, @title_font2)
    draw_centered_text("Clique rápido para girar  ·  Arraste para mover", 46, LABEL_COLOR, @sub_font)
    draw_centered_text("Atalhos: [R] Girar - [S] Embaralhar - [Enter] Jogar", 570, Gosu::Color.new(0xff_64748b), @grid_font)

    draw_grid_background
    draw_grid_labels
    draw_ships
    draw_drag_preview if @dragging_ship
    draw_buttons
  end

  def button_down(id)
    case id
    when Gosu::MS_LEFT
      handle_left_press
    when Gosu::KB_R
      if @dragging_ship
        # Gira o navio na mão e troca os eixos para girar em torno do mouse!
        @drag_ori = @drag_ori == :horizontal ? :vertical : :horizontal
        @drag_offset_x, @drag_offset_y = @drag_offset_y, @drag_offset_x
      else
        # Permite girar apenas passando o mouse por cima e apertando R
        ship_entry = ship_at_pixel(@window.mx, @window.my)
        rotate_ship(ship_entry[0]) if ship_entry
      end
    when Gosu::KB_S
      random_place_all
    when Gosu::KB_ENTER, Gosu::KB_RETURN, Gosu::KB_SPACE
      launch_game
    when Gosu::KB_ESCAPE
      @window.request_screen(:menu)
    end
  end

  def button_up(id)
    if id == Gosu::MS_LEFT && @dragging_ship
      drop_ship
    end
  end

  private

  def handle_left_press
    mx, my = @window.mx, @window.my

    if over_button?(mx, my, :shuffle)
      random_place_all
      return
    end

    if over_button?(mx, my, :play)
      launch_game
      return
    end

    ship_entry = ship_at_pixel(mx, my)
    if ship_entry
      ship, col, row = ship_entry
      cell_col, cell_row = pixel_to_cell(mx, my)

      @drag_offset_x  = cell_col - col
      @drag_offset_y  = cell_row - row
      @dragging_ship  = ship
      @drag_ori       = @placements[ship.object_id][:orientation]
      @drag_col       = col
      @drag_row       = row
      @drag_start_x   = mx
      @drag_start_y   = my
    end
  end

  def drop_ship
    ship = @dragging_ship
    @dragging_ship = nil

    mx, my = @window.mx, @window.my

    # Tolerância maior (10px) para não confundir clique rápido com drag
    moved = (mx - @drag_start_x).abs > 10 || (my - @drag_start_y).abs > 10
    changed_ori = @drag_ori != @placements[ship.object_id][:orientation]

    if moved || changed_ori
      if can_place?(@temp_board, ship, @drag_col, @drag_row, @drag_ori, exclude: ship)
        remove_from_temp(ship)
        place_on_temp(ship, @drag_col, @drag_row, @drag_ori)
        @placements[ship.object_id] = { ship: ship, col: @drag_col, row: @drag_row, orientation: @drag_ori }
      end
      # Se falhar no can_place?, o navio simplesmente volta pra onde estava (comportamento seguro)
    else
      # Se o mouse não moveu, foi apenas um clique para girar!
      rotate_ship(ship)
    end
  end

  def build_fleet_and_place
    @fleet = [
      Flattop.new, Flattop.new,
      Warship.new, Warship.new,
      Battleship.new,
      Submarine.new
    ]
    @placements = {}
    random_place_all
  end

  def random_place_all
    reset_board
    @placements = {}

    @fleet.each do |ship|
      ship.instance_variable_set(:@hits, 0)
      ship.instance_variable_set(:@status, Ship::INTACT)
      ship.instance_variable_set(:@positions, [])
    end

    @fleet.each do |ship|
      placed = false
      200.times do
        col = rand(10)
        row = rand(10)
        orientation = [:horizontal, :vertical].sample

        if can_place?(@temp_board, ship, col, row, orientation, exclude: ship)
          place_on_temp(ship, col, row, orientation)
          @placements[ship.object_id] = { ship: ship, col: col, row: row, orientation: orientation }
          placed = true
          break
        end
      end

      unless placed
        10.times do |r|
          10.times do |c|
            [:horizontal, :vertical].each do |ori|
              if can_place?(@temp_board, ship, c, r, ori, exclude: ship)
                place_on_temp(ship, c, r, ori)
                @placements[ship.object_id] = { ship: ship, col: c, row: r, orientation: ori }
                placed = true
              end
              break if placed
            end
            break if placed
          end
          break if placed
        end
      end
    end
  end

  def reset_board
    @temp_board = Array.new(10) { Array.new(10, nil) }
  end

  def place_on_temp(ship, col, row, orientation)
    size = ship.ship_size
    if orientation == :horizontal
      size.times { |i| @temp_board[row][col + i] = ship.object_id }
    else
      size.times { |i| @temp_board[row + i][col] = ship.object_id }
    end
  end

  def remove_from_temp(ship)
    10.times do |r|
      10.times do |c|
        @temp_board[r][c] = nil if @temp_board[r][c] == ship.object_id
      end
    end
  end

  def can_place?(board, ship, col, row, orientation, exclude: nil)
    return false if col < 0 || row < 0

    size = ship.ship_size
    cells = if orientation == :horizontal
              (0...size).map { |i| [col + i, row] }
            else
              (0...size).map { |i| [col, row + i] }
            end

    cells.each do |c, r|
      return false unless c.between?(0, 9) && r.between?(0, 9)
      occupant = board[r][c]
      return false if occupant && occupant != (exclude&.object_id)
    end
    true
  end

  def rotate_ship(ship)
    entry = @placements[ship.object_id]
    old_ori = entry[:orientation]
    new_ori = old_ori == :horizontal ? :vertical : :horizontal
    col = entry[:col]
    row = entry[:row]
    size = ship.ship_size

    # Empurra o navio para dentro do grid caso o giro faça ele sair pela borda!
    if new_ori == :horizontal
      col = [col, 10 - size].min
    else
      row = [row, 10 - size].min
    end

    if can_place?(@temp_board, ship, col, row, new_ori, exclude: ship)
      remove_from_temp(ship)
      place_on_temp(ship, col, row, new_ori)
      @placements[ship.object_id] = { ship: ship, col: col, row: row, orientation: new_ori }
    end
  end

  def pixel_to_cell(px, py)
    gx = GRID_X + LABEL_OFF
    gy = GRID_Y + LABEL_OFF
    col = ((px - gx).to_f / CELL_SIZE).floor
    row = ((py - gy).to_f / CELL_SIZE).floor
    [col, row]
  end

  def cell_to_pixel(col, row)
    gx = GRID_X + LABEL_OFF
    gy = GRID_Y + LABEL_OFF
    [gx + col * CELL_SIZE + 1, gy + row * CELL_SIZE + 1]
  end

  def ship_at_pixel(px, py)
    col, row = pixel_to_cell(px, py)
    return nil unless col.between?(0, 9) && row.between?(0, 9)

    @placements.each_value do |entry|
      s   = entry[:ship]
      c   = entry[:col]
      r   = entry[:row]
      ori = entry[:orientation]
      size = s.ship_size

      cells = if ori == :horizontal
                (0...size).map { |i| [c + i, r] }
              else
                (0...size).map { |i| [c, r + i] }
              end

      return [s, c, r] if cells.include?([col, row])
    end
    nil
  end

  def draw_grid_background
    gx = GRID_X + LABEL_OFF
    gy = GRID_Y + LABEL_OFF
    grid_px = 10 * CELL_SIZE

    @window.draw_rect(gx, gy, grid_px, grid_px, COLOR_GRID_BG)

    cell_inner = CELL_SIZE - CELL_GAP
    10.times do |row|
      10.times do |col|
        cx = gx + col * CELL_SIZE + 1
        cy = gy + row * CELL_SIZE + 1
        @window.draw_rect(cx, cy, cell_inner, cell_inner, COLOR_WATER)
      end
    end
  end

  def draw_grid_labels
    gx = GRID_X + LABEL_OFF
    gy = GRID_Y + LABEL_OFF

    %w[A B C D E F G H I J].each_with_index do |letter, i|
      lx = gx + i * CELL_SIZE + (CELL_SIZE - @label_font.text_width(letter)) / 2
      ly = gy - LABEL_OFF + 4
      @label_font.draw_text(letter, lx, ly, 2, 1.0, 1.0, LABEL_COLOR)
    end

    10.times do |i|
      num = (i + 1).to_s
      lx  = GRID_X + (LABEL_OFF - @label_font.text_width(num)) / 2
      ly  = gy + i * CELL_SIZE + (CELL_SIZE - @label_font.height) / 2
      @label_font.draw_text(num, lx, ly, 2, 1.0, 1.0, LABEL_COLOR)
    end
  end

  def draw_ships
    cell_inner = CELL_SIZE - CELL_GAP

    @placements.each_value do |entry|
      ship = entry[:ship]
      next if ship == @dragging_ship

      col  = entry[:col]
      row  = entry[:row]
      ori  = entry[:orientation]
      size = ship.ship_size

      px, py = cell_to_pixel(col, row)
      w = ori == :horizontal ? size * CELL_SIZE - CELL_GAP : cell_inner
      h = ori == :horizontal ? cell_inner : size * CELL_SIZE - CELL_GAP

      ship_key = ship.class.name.split('::').last.downcase.to_sym
      unless @ship_sprites[ship_key]
        @window.draw_rect(px, py, w, h, COLOR_SHIP, 1)
      end

      draw_ship_sprite(ship, px, py, ori, size, CELL_SIZE, CELL_GAP, z: 2)
    end
  end

  def draw_drag_preview
    return unless @dragging_ship && @drag_col && @drag_row

    ship = @dragging_ship
    ori  = @drag_ori
    size = ship.ship_size
    cell_inner = CELL_SIZE - CELL_GAP

    valid = can_place?(@temp_board, ship, @drag_col, @drag_row, ori, exclude: ship)
    color_bg     = valid ? COLOR_SHIP_OK : COLOR_SHIP_INVA
    sprite_tint  = valid ? Gosu::Color.argb(204, 255, 255, 255) : Gosu::Color.argb(153, 255, 255, 255)

    px, py = cell_to_pixel(@drag_col, @drag_row)
    w = ori == :horizontal ? size * CELL_SIZE - CELL_GAP : cell_inner
    h = ori == :horizontal ? cell_inner : size * CELL_SIZE - CELL_GAP

    @window.draw_rect(px, py, w, h, color_bg, 2)
    draw_ship_sprite(ship, px, py, ori, size, CELL_SIZE, CELL_GAP, z: 3, color: sprite_tint)
  end

  def draw_buttons
    total = BTN_W * 2 + BTN_GAP
    bx    = (@window.dw - total) / 2

    draw_colored_btn("EMBARALHAR", bx,            BTN_Y, BTN_W, BTN_H, :shuffle)
    draw_colored_btn("JOGAR",      bx + BTN_W + BTN_GAP, BTN_Y, BTN_W, BTN_H, :play)
  end

  def draw_colored_btn(text, x, y, w, h, type)
    mx, my = @window.mx, @window.my
    hover = mx.between?(x, x + w) && my.between?(y, y + h)

    bg = case type
         when :shuffle then hover ? COLOR_BTN_SHUFFLE_HOV : COLOR_BTN_SHUFFLE
         when :play    then hover ? COLOR_BTN_PLAY_HOV    : COLOR_BTN_PLAY
         end

    @window.draw_rect(x + 3, y + 4, w, h, Gosu::Color.argb(136, 0, 0, 0))
    @window.draw_rect(x, y, w, h, bg)
    @window.draw_rect(x, y, w, 3, Gosu::Color.argb(102, 255, 255, 255))

    tx = x + (w - @btn_font2.text_width(text)) / 2
    ty = y + (h - @btn_font2.height) / 2
    @btn_font2.draw_text(text, tx, ty, 3, 1.0, 1.0, Gosu::Color::WHITE)
  end

  def over_button?(mx, my, which)
    total = BTN_W * 2 + BTN_GAP
    bx    = (@window.dw - total) / 2

    case which
    when :shuffle
      mx.between?(bx, bx + BTN_W) && my.between?(BTN_Y, BTN_Y + BTN_H)
    when :play
      mx.between?(bx + BTN_W + BTN_GAP, bx + BTN_W * 2 + BTN_GAP) && my.between?(BTN_Y, BTN_Y + BTN_H)
    end
  end

  def launch_game
    @window.start_game_with_placement(
      placements:     @placements,
      fleet:          @fleet,
      campaign_stage: @campaign_stage,
      difficulty:     @difficulty,
      current_user:   @current_user
    )
  end
end