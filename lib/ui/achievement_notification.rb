require_relative '../ui/theme'

# Overlay de notificação que aparece na tela quando uma conquista é desbloqueada.
# Exibe um banner animado (fade in / fade out) com o nome da medalha.
class AchievementNotification
  DISPLAY_DURATION = 180  # frames (~3s a 60fps)
  FADE_FRAMES      = 30
  BG_COLOR_BASE    = 0xff_d97706

  def initialize
    @queue   = []
    @current = nil
    @timer   = 0
    @font_title = Gosu::Font.new(18)
    @font_name  = Gosu::Font.new(22)
  end

  # Adiciona uma conquista à fila de notificações.
  # @param key [Symbol] chave da conquista em AchievementManager::ACHIEVEMENTS
  def enqueue(key)
    data = AchievementManager::ACHIEVEMENTS[key]
    return unless data
    @queue << data
  end

  # Atualiza o estado da animação. Chamar a cada frame.
  def update
    if @current.nil? && !@queue.empty?
      @current = @queue.shift
      @timer   = 0
    end

    return unless @current

    @timer += 1
    @current = nil if @timer >= DISPLAY_DURATION
  end

  # Desenha o banner de notificação (caso exista um ativo).
  # @param window_width [Integer]
  def draw(window_width)
    return unless @current

    alpha = compute_alpha
    return if alpha <= 0

    w      = 360
    h      = 70
    x      = (window_width - w) / 2
    y      = 15

    bg = Gosu::Color.new((alpha << 24) | 0x1e293b)
    border = Gosu::Color.new((alpha << 24) | 0xd97706)

    Gosu.draw_rect(x, y, w, h, bg, 10)
    # borda superior dourada
    Gosu.draw_rect(x, y, w, 3, border, 10)

    # Título
    title_color = Gosu::Color.new((alpha << 24) | 0xd97706)
    text_color  = Gosu::Color.new((alpha << 24) | 0xf1f5f9)

    title = 'CONQUISTA DESBLOQUEADA!'
    @font_title.draw_text(
      title,
      x + (w - @font_title.text_width(title)) / 2,
      y + 8, 11, 1.0, 1.0, title_color
    )

    name = "#{@current[:icon]}  #{@current[:name]}"
    @font_name.draw_text(
      name,
      x + (w - @font_name.text_width(name)) / 2,
      y + 32, 11, 1.0, 1.0, text_color
    )
  end

  private

  # Calcula o valor de alpha (0..255) com fade in/out.
  def compute_alpha
    if @timer < FADE_FRAMES
      ((@timer.to_f / FADE_FRAMES) * 255).to_i
    elsif @timer > DISPLAY_DURATION - FADE_FRAMES
      remaining = DISPLAY_DURATION - @timer
      ((remaining.to_f / FADE_FRAMES) * 255).to_i
    else
      255
    end
  end
end


