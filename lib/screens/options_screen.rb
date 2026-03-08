require_relative 'base_screen'

class OptionsScreen < BaseScreen
  BTN_W = 420
  BTN_H = 50
  GAP = 18
  BASE_Y = 210
  TOTAL_OPTS = 2

  COLOR_ON = Gosu::Color.new(0xff_22c55e)
  COLOR_OFF = Gosu::Color.new(0xff_ef4444)

  def initialize(window)
    super(window)
    @selected_index = 0
  end

  def update
    cx = @window.dw / 2
    mx, my = @window.mx, @window.my

    if hit?(cx, BASE_Y, mx, my)
      @selected_index = 0
    elsif hit?(cx, BASE_Y + BTN_H + GAP, mx, my)
      @selected_index = 1
    end
  end

  def draw
    draw_header("OPÇÕES")
    draw_back_btn

    cx = @window.dw / 2

    draw_toggle_btn("Música", cx, BASE_Y, @window.music_enabled, 0)
    draw_toggle_btn("Efeitos sonoros", cx, BASE_Y + BTN_H + GAP, @window.sfx_enabled, 1)
  end

  def button_down(id)
    case id
    when Gosu::MS_LEFT
      handle_clicks
    when Gosu::KB_UP
      @selected_index = (@selected_index - 1) % TOTAL_OPTS
    when Gosu::KB_DOWN
      @selected_index = (@selected_index + 1) % TOTAL_OPTS
    when Gosu::KB_RETURN, Gosu::KB_ENTER
      execute_action(@selected_index)
    when Gosu::KB_ESCAPE
      @window.request_screen(:menu)
    end
  end

  private

  def handle_clicks
    mx, my = @window.mx, @window.my
    cx = @window.dw / 2

    if back_btn_hit?(mx, my)
      @window.request_screen(:menu)
    elsif hit?(cx, BASE_Y, mx, my)
      execute_action(0)
    elsif hit?(cx, BASE_Y + BTN_H + GAP, mx, my)
      execute_action(1)
    end
  end

  def execute_action(index)
    if index == 0
      @window.toggle_music
    elsif index == 1
      @window.toggle_sfx
    end
  end

  def draw_toggle_btn(label, cx, y, enabled, index)
    x = cx - BTN_W / 2

    draw_btn(label, x, y, BTN_W, BTN_H)

    if index == @selected_index
      t = 3
      color_focus = Gosu::Color.new(0xff_d97706)

      @window.draw_rect(x - t, y - t, BTN_W + t * 2, t, color_focus)
      @window.draw_rect(x - t, y + BTN_H, BTN_W + t * 2, t, color_focus)
      @window.draw_rect(x - t, y - t, t, BTN_H + t * 2, color_focus)
      @window.draw_rect(x + BTN_W, y - t, t, BTN_H + t * 2, color_focus)
    end

    status_text = enabled ? "LIGADO" : "DESLIGADO"
    color = enabled ? COLOR_ON : COLOR_OFF
    font = @info_font
    tx = x + BTN_W - font.text_width(status_text) - 14
    ty = y + (BTN_H - font.height) / 2
    font.draw_text(status_text, tx, ty, 3, 1.0, 1.0, color)
  end

  def hit?(cx, y, mx, my)
    x = cx - BTN_W / 2
    mx.between?(x, x + BTN_W) && my.between?(y, y + BTN_H)
  end
end