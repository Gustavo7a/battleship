require_relative 'base_screen'

class OptionsScreen < BaseScreen
  BTN_W = 320
  BTN_H = 50
  GAP   = 18

  COLOR_ON  = Gosu::Color.new(0xff_22c55e)
  COLOR_OFF = Gosu::Color.new(0xff_ef4444)

  def draw
    draw_header("OPÇÕES")
    draw_back_btn

    cx = @window.dw / 2
    base_y = 210

    draw_toggle_btn("♪  Música",   cx, base_y,           @window.music_enabled)
    draw_toggle_btn("⚡  Efeitos Sonoros", cx, base_y + BTN_H + GAP, @window.sfx_enabled)
  end

  def button_down(id)
    return unless id == Gosu::MS_LEFT
    mx = @window.mx
    my = @window.my
    cx = @window.dw / 2
    base_y = 210

    if back_btn_hit?(mx, my)
      @window.request_screen(:menu)
      return
    elsif hit?(cx, base_y, mx, my)
      @window.toggle_music
    elsif hit?(cx, base_y + BTN_H + GAP, mx, my)
      @window.toggle_sfx
    end
  end

  private

  def draw_toggle_btn(label, cx, y, enabled)
    x = cx - BTN_W / 2

    # fundo e borda via draw_btn (para o hover)
    draw_btn(label, x, y, BTN_W, BTN_H)

    # indicador colorido à direita
    status_text = enabled ? "LIGADO" : "DESLIGADO"
    color       = enabled ? COLOR_ON : COLOR_OFF
    font        = @info_font
    tx = x + BTN_W - font.text_width(status_text) - 14
    ty = y + (BTN_H - font.height) / 2
    font.draw_text(status_text, tx, ty, 3, 1.0, 1.0, color)
  end

  def hit?(cx, y, mx, my)
    x = cx - BTN_W / 2
    mx.between?(x, x + BTN_W) && my.between?(y, y + BTN_H)
  end
end