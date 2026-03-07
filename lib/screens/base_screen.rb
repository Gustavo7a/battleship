require_relative '../ui/theme'

class BaseScreen
  attr_reader :window

  def initialize(window)
    @window = window

    @title_font = @window.font_title
    @btn_font   = @window.font_btn
    @info_font  = @window.font_info

    @bg_image = @window.bg_image
  end

  def update; end
  def draw; end
  def button_down(id); end


  def draw_background
    if @bg_image
      sx = @window.dw.to_f / @bg_image.width
      sy = @window.dh.to_f / @bg_image.height
      @bg_image.draw(0, 0, -2, sx, sy)
    end
    # overlay semi-transparente para manter legibilidade
    @window.draw_rect(0, 0, @window.dw, @window.dh, Gosu::Color.new(0xbb_040d1a), -1)
  end

  def draw_header(title)
    draw_centered_text(title, 50, Theme::COLOR_ACCENT, @title_font)
  end

  def draw_btn(text, x, y, w, h)
    mouse_x = @window.mx
    mouse_y = @window.my

    is_hover = mouse_x.between?(x, x + w) && mouse_y.between?(y, y + h)

    bg_color = is_hover ? Theme::COLOR_HOVER : Theme::COLOR_BTN
    border_color = is_hover ? Theme::COLOR_ACCENT : Theme::COLOR_BG

    @window.draw_rect(x, y, w, h, bg_color)

    t = 2
    @window.draw_rect(x, y, w, t, border_color)
    @window.draw_rect(x, y + h - t, w, t, border_color)
    @window.draw_rect(x, y, t, h, border_color)
    @window.draw_rect(x + w - t, y, t, h, border_color)

    text_x = x + (w - @btn_font.text_width(text)) / 2
    text_y = y + (h - @btn_font.height) / 2
    @btn_font.draw_text(text, text_x, text_y, 2, 1.0, 1.0, Theme::COLOR_TEXT)

    return is_hover
  end

  def draw_centered_text(text, y, color, font)
    x = (@window.dw - font.text_width(text)) / 2
    font.draw_text(text, x, y, 2, 1.0, 1.0, color)
  end

  def draw_footer_hint
    draw_centered_text("(Pressione ESC para voltar ao Menu)", 560, Gosu::Color.new(0xff_64748b), @info_font)
  end

  BACK_BTN_X = 14
  BACK_BTN_Y = 12
  BACK_BTN_W = 120
  BACK_BTN_H = 36

  def draw_back_btn
    draw_btn("← VOLTAR", BACK_BTN_X, BACK_BTN_Y, BACK_BTN_W, BACK_BTN_H)
  end

  def back_btn_hit?(mx, my)
    mx.between?(BACK_BTN_X, BACK_BTN_X + BACK_BTN_W) &&
      my.between?(BACK_BTN_Y, BACK_BTN_Y + BACK_BTN_H)
  end

  # Carrega as sprites dos navios de assets/ships/ para @ship_sprites.
  # Deve ser chamado no initialize das telas que exibem navios.
  def load_ship_sprites
    @ship_sprites = {}
    %w[flattop warship battleship submarine].each do |name|
      begin
        @ship_sprites[name.to_sym] = Gosu::Image.new(
          File.join('assets', 'ships', "#{name}.png")
        )
      rescue
        # sprite não encontrado; fallback para cor sólida
      end
    end
    begin
      @crosshair_img = Gosu::Image.new(File.join('assets', 'images', 'crosshair.png'))
    rescue
      @crosshair_img = nil
    end
  end

  # Desenha a sprite de um navio na posição e orientação indicadas.
  #
  # As sprites estão todas na vertical. Quando a orientação é :horizontal
  # a imagem é rotacionada 90° no sentido horário automaticamente.
  #
  # @param ship        [Ship]    instância do navio
  # @param px          [Integer] x em pixels (canto superior esquerdo)
  # @param py          [Integer] y em pixels (canto superior esquerdo)
  # @param orientation [Symbol]  :vertical ou :horizontal
  # @param size        [Integer] tamanho do navio em células
  # @param cell_size   [Integer] dimensão de cada célula em pixels
  # @param cell_gap    [Integer] espaço entre células em pixels
  # @param z           [Integer] z-index de desenho
  # @param color       [Gosu::Color] tint aplicado à sprite
  def draw_ship_sprite(ship, px, py, orientation, size, cell_size, cell_gap, z: 2, color: Gosu::Color::WHITE)
    img = @ship_sprites&.dig(ship.class.name.downcase.to_sym)
    return unless img

    cell_inner = cell_size - cell_gap

    if orientation == :vertical
      sx = cell_inner.to_f / img.width
      sy = (size * cell_size - cell_gap).to_f / img.height
      img.draw(px, py, z, sx, sy, color)
    else
      # Rotação 90° CW: escala mapeando img.height → largura, img.width → altura
      w  = size * cell_size - cell_gap
      h  = cell_inner
      sx = h.to_f / img.width
      sy = w.to_f / img.height
      img.draw_rot(px + w / 2.0, py + h / 2.0, z, 90, 0.5, 0.5, sx, sy, color)
    end
  end
end
