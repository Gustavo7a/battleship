require_relative 'base_screen'

# Tela do mapa de campanha.
#
# Apresenta as três missões em sequência:
#   Missão 1 → EasyBot
#   Missão 2 → MediumBot   (desbloqueada após vencer a Missão 1)
#   Missão 3 → HardBot      (desbloqueada após vencer a Missão 2)
#
# O progresso é mantido em @campaign_stage (1..3) que o GameWindow repassa.
# Quando o jogador vence uma missão, o GameWindow incrementa campaign_stage
# e volta para cá.
#
# @author Jurandir Neto
class CampaignScreen < BaseScreen
  # Dificuldades mapeadas por estágio
  STAGE_LABELS = {
    1 => "MISSÃO 1 – Dia de Treinamento  [Fácil]",
    2 => "MISSÃO 2 – O Atlântico         [Médio]",
    3 => "MISSÃO 3 – Chefe Final         [Difícil]"
  }.freeze

  STAGE_DIFFICULTIES = {
    1 => :easy,
    2 => :medium,
    3 => :hard
  }.freeze

  # @param window     [GameWindow]
  # @param stage      [Integer]  estágio atual desbloqueado (1‑3)
  def initialize(window, stage: 1)
    super(window)
    @stage        = stage.clamp(1, 3)
    @hover_stage  = nil
    @mission_font = Gosu::Font.new(16)
  end

  # Renderização

  def draw
    draw_header("MAPA DE CAMPANHA")
    draw_back_btn
    draw_centered_text("Selecione sua missão:", 140, Theme::COLOR_TEXT, @btn_font)

    btn_w  = 420
    btn_h  = 50
    start_x = (@window.dw - btn_w) / 2

    STAGE_LABELS.each_with_index do |(stage_num, label), idx|
      y       = 200 + idx * 80
      unlocked = stage_num <= @stage
      draw_mission_btn(label, start_x, y, btn_w, btn_h, unlocked)
    end

    draw_stage_info
  end

  # Input

  def button_down(id)
    return unless id == Gosu::MS_LEFT

    mx = @window.mx
    my = @window.my

    if back_btn_hit?(mx, my)
      @window.request_screen(:menu)
      return
    end

    btn_w  = 500
    btn_h  = 50
    start_x = (@window.dw - btn_w) / 2

    STAGE_LABELS.each_with_index do |(stage_num, _label), idx|
      y        = 200 + idx * 80
      unlocked = stage_num <= @stage

      if unlocked && mx.between?(start_x, start_x + btn_w) && my.between?(y, y + btn_h)
        launch_mission(stage_num)
        return
      end
    end
  end

  private

  # Desenha um botão de missão, bloqueado ou não.
  def draw_mission_btn(label, x, y, w, h, unlocked)
    mx = @window.mx
    my = @window.my
    is_hover = unlocked && mx.between?(x, x + w) && my.between?(y, y + h)

    bg_color     = unlocked ? (is_hover ? Theme::COLOR_HOVER : Theme::COLOR_BTN) : Gosu::Color.new(0xff_2d3748)
    border_color = is_hover ? Theme::COLOR_ACCENT : Theme::COLOR_BG
    text_color   = unlocked ? Theme::COLOR_TEXT : Gosu::Color.new(0xff_64748b)

    @window.draw_rect(x, y, w, h, bg_color)
    t = 2
    @window.draw_rect(x,         y,         w, t, border_color)
    @window.draw_rect(x,         y + h - t, w, t, border_color)
    @window.draw_rect(x,         y,         t, h, border_color)
    @window.draw_rect(x + w - t, y,         t, h, border_color)

    display = unlocked ? label : "#{label}  [BLOQUEADA]"
    tx = x + (w - @mission_font.text_width(display)) / 2
    ty = y + (h - @mission_font.height) / 2
    @mission_font.draw_text(display, tx, ty, 2, 1.0, 1.0, text_color)
  end

  # Exibe o estágio atual em texto informativo
  def draw_stage_info
    completed = @stage - 1
    total     = 3
    info = "Progresso: #{completed}/#{total} missões concluídas"
    draw_centered_text(info, 460, Theme::COLOR_ACCENT, @info_font)

    if @stage > 3
      draw_centered_text("Campanha completa! Parabéns!", 490, Theme::COLOR_ACCENT, @btn_font)
    end
  end

  # Navega para o GameScreen com a dificuldade correta
  def launch_mission(stage_num)
    difficulty = STAGE_DIFFICULTIES[stage_num]
    @window.start_campaign_mission(stage_num, difficulty)
  end
end