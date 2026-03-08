require_relative 'base_screen'

# Tela exibida quando o jogador derrota o Davy Jones (missão impossível).
#
# Exibe a mensagem de parabéns, a medalha desbloqueada e um botão para
# voltar ao menu principal.
class CongratulationsScreen < BaseScreen
  MESSAGE    = "Parabéns, você derrotou o Rei dos Mares, o temido Davy Jones".freeze
  MEDAL_INFO = "Medalha desbloqueada:  Alma Negra  ☠".freeze

  COLOR_GOLD   = Gosu::Color.new(0xff_d97706)
  COLOR_TROPHY = Gosu::Color.new(0xff_fbbf24)

  BTN_W = 240
  BTN_H = 46
  BTN_Y = 440

  def initialize(window)
    super(window)
    @msg_font = Gosu::Font.new(24)
    @sub_font = Gosu::Font.new(20)
  end

  def draw
    draw_background

    cx = @window.dw / 2

    # Cabeçalho
    draw_header("☠  DAVY JONES DERROTADO  ☠")

    # Decoração
    deco = "~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~"
    draw_centered_text(deco, 108, COLOR_GOLD, @info_font)

    # Mensagem principal (com quebra automática de linha)
    draw_wrapped(MESSAGE, cx, 165, 580, @msg_font, Theme::COLOR_TEXT)

    # Separador dourado
    @window.draw_rect(cx - 210, 335, 420, 2, COLOR_GOLD, 2)

    # Medalha
    draw_centered_text(MEDAL_INFO, 352, COLOR_TROPHY, @sub_font)

    # Separador dourado inferior
    @window.draw_rect(cx - 210, 387, 420, 2, COLOR_GOLD, 2)

    # Rodapé motivacional
    draw_centered_text("Você é o verdadeiro Rei dos Mares!", 402, Theme::COLOR_TEXT, @info_font)

    # Botão de retorno
    draw_btn("← MENU PRINCIPAL", cx - BTN_W / 2, BTN_Y, BTN_W, BTN_H)
  end

  def button_down(id)
    return unless id == Gosu::MS_LEFT

    cx = @window.dw / 2
    bx = cx - BTN_W / 2

    @window.request_screen(:menu) if @window.mx.between?(bx, bx + BTN_W) &&
                                      @window.my.between?(BTN_Y, BTN_Y + BTN_H)
  end

  private

  # Desenha `text` centrado horizontalmente, com quebra de linha automática.
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
