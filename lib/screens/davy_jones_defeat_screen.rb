require_relative 'base_screen'

# Tela exibida quando o Davy Jones derrota o jogador na missão impossível.
class DavyJonesDefeatScreen < BaseScreen
  MESSAGE = "Os mares reclamaram mais uma alma... Davy Jones ri do seu fracasso, " \
            "Capitão. Sua tripulação descansa agora no fundo do oceano.".freeze

  COLOR_BLOOD  = Gosu::Color.new(0xff_7f1d1d)
  COLOR_RED    = Gosu::Color.new(0xff_ef4444)
  COLOR_DIM    = Gosu::Color.new(0xff_fca5a5)

  BTN_W = 240
  BTN_H = 46

  def initialize(window)
    super(window)
    @msg_font   = Gosu::Font.new(22)
    @skull_font = Gosu::Font.new(64)
    @sub_font   = Gosu::Font.new(18)
  end

  def draw
    draw_background
    # overlay carmesim sobre o fundo
    @window.draw_rect(0, 0, @window.dw, @window.dh, Gosu::Color.new(0x55_3d0000), 0)

    cx = @window.dw / 2

    # Caveira decorativa
    @skull_font.draw_text("☠", cx - @skull_font.text_width("☠") / 2, 20, 2,
                          1.0, 1.0, COLOR_RED)

    # Título
    draw_centered_text("DAVY JONES VENCEU", 98, COLOR_RED, @title_font)

    # Linha decorativa
    @window.draw_rect(cx - 220, 148, 440, 2, COLOR_BLOOD, 2)

    # Mensagem
    draw_wrapped(MESSAGE, cx, 168, 580, @msg_font, COLOR_DIM)

    # Linha decorativa inferior
    @window.draw_rect(cx - 220, 330, 440, 2, COLOR_BLOOD, 2)

    draw_centered_text("\"Você deveria ter atirado mais rápido...\"", 348,
                       Gosu::Color.new(0xff_94a3b8), @sub_font)

    # Botões
    btn_gap = 20
    total_w = BTN_W * 2 + btn_gap
    left_x  = cx - total_w / 2

    draw_btn("↩  TENTAR NOVAMENTE", left_x,              410, BTN_W, BTN_H)
    draw_btn("← MENU PRINCIPAL",   left_x + BTN_W + btn_gap, 410, BTN_W, BTN_H)
  end

  def button_down(id)
    return unless id == Gosu::MS_LEFT

    cx      = @window.dw / 2
    btn_gap = 20
    total_w = BTN_W * 2 + btn_gap
    left_x  = cx - total_w / 2
    mx      = @window.mx
    my      = @window.my

    if mx.between?(left_x, left_x + BTN_W) && my.between?(410, 410 + BTN_H)
      @window.request_screen(:campaign)
    elsif mx.between?(left_x + BTN_W + btn_gap, left_x + total_w) && my.between?(410, 410 + BTN_H)
      @window.request_screen(:menu)
    end
  end

  private

  def draw_wrapped(text, cx, start_y, max_w, font, color)
    words  = text.split(' ')
    line   = ''
    line_y = start_y

    words.each do |word|
      test = line.empty? ? word : "#{line} #{word}"
      if font.text_width(test) > max_w && !line.empty?
        font.draw_text(line, cx - font.text_width(line) / 2, line_y, 2, 1.0, 1.0, color)
        line   = word
        line_y += font.height + 8
      else
        line = test
      end
    end

    font.draw_text(line, cx - font.text_width(line) / 2, line_y, 2, 1.0, 1.0, color) unless line.empty?
  end
end
