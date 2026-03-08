require_relative 'base_screen'

# Tela de Leaderboard — exibe o ranking real de jogadores via SQLite.
class RankingScreen < BaseScreen
  COLOR_GOLD   = Gosu::Color.new(0xff_d97706)
  COLOR_SILVER = Gosu::Color.new(0xff_94a3b8)
  COLOR_BRONZE = Gosu::Color.new(0xff_b45309)

  MEDALS = ['🥇', '🥈', '🥉']

  def initialize(window)
    super(window)
    @scores    = window.db.leaderboard(limit: 8)
    @row_font  = Gosu::Font.new(20)
    @head_font = Gosu::Font.new(16)
  end

  def draw
    draw_header("HALL DA FAMA")
    draw_back_btn
    draw_column_headers
    draw_rows
  end

  def button_down(id)
    return unless id == Gosu::MS_LEFT
    @window.request_screen(:menu) if back_btn_hit?(@window.mx, @window.my)
  end

  private

  def draw_column_headers
    y = 135
    color = COLOR_SILVER
    cols = column_positions

    @head_font.draw_text("JOGADOR",       cols[:name],  y, 2, 1.0, 1.0, color)
    @head_font.draw_text("PONTOS",        cols[:score], y, 2, 1.0, 1.0, color)
    @head_font.draw_text("V",             cols[:wins],  y, 2, 1.0, 1.0, color)
    @head_font.draw_text("D",             cols[:loss],  y, 2, 1.0, 1.0, color)

    # linha separadora
    @window.draw_rect(50, 158, 700, 1, COLOR_SILVER)
  end

  def draw_rows
    @scores.each_with_index do |entry, i|
      y = 170 + i * 45

      row_color =
        case i
        when 0 then COLOR_GOLD
        when 1 then COLOR_SILVER
        when 2 then COLOR_BRONZE
        else Theme::COLOR_TEXT
        end

      # fundo alternado suave
      if i.odd?
        @window.draw_rect(50, y - 4, 700, 38, Gosu::Color.new(0x18_ffffff))
      end

      cols = column_positions
      rank_str = (i < 3) ? "#{i + 1}." : "#{i + 1}."

      @row_font.draw_text(rank_str,                    cols[:rank],  y, 2, 1.0, 1.0, row_color)
      @row_font.draw_text(entry['username'].upcase,    cols[:name],  y, 2, 1.0, 1.0, row_color)
      @row_font.draw_text(entry['total_score'].to_s,   cols[:score], y, 2, 1.0, 1.0, row_color)
      @row_font.draw_text(entry['wins'].to_s,          cols[:wins],  y, 2, 1.0, 1.0, COLOR_SUCCESS)
      @row_font.draw_text(entry['losses'].to_s,        cols[:loss],  y, 2, 1.0, 1.0, COLOR_ERROR)
    end

    if @scores.empty?
      draw_centered_text("Nenhuma partida registrada ainda.", 280, COLOR_SILVER, @btn_font)
    end
  end

  def column_positions
    { rank: 55, name: 100, score: 480, wins: 580, loss: 650 }
  end

  COLOR_SUCCESS = Gosu::Color.new(0xff_22c55e)
  COLOR_ERROR   = Gosu::Color.new(0xff_ef4444)
end

