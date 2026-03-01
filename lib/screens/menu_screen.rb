require_relative 'base_screen'

class MenuScreen < BaseScreen
  BTN_WIDTH = 280
  BTN_HEIGHT = 55
  BTN_SPACING = 75
  START_Y = 220

  def initialize(window)
    super(window)

    begin
      path = File.join("assets", "images", "logo.png")
      @logo = Gosu::Image.new(path)
    rescue
      @logo = nil
    end
  end

  def draw
    if @logo
      scale = 0.5
      img_w = @logo.width * scale
      x = (@window.width - img_w) / 2
      @logo.draw(x, -150, 1, scale, scale)
    else
      draw_header("BATTLESHIP")
    end

    draw_menu_btn("CAMPAIGN MODE", 0)
    draw_menu_btn("DYNAMIC MODE", 1)
    draw_menu_btn("LEADERBOARD", 2)
    draw_menu_btn("MEDALS", 3)
    draw_menu_btn("OPTIONS", 4)
    draw_menu_btn("EXIT", 5)

    draw_centered_text("v1.0 - PLP", 580, Gosu::Color.new(0xff_475569), @info_font)
  end

  def button_down(id)
    if id == Gosu::MS_LEFT
      handle_clicks
    end
  end

  private

  def draw_menu_btn(text, index)
    x = (@window.width - BTN_WIDTH) / 2
    y = START_Y + (index * BTN_SPACING)
    draw_btn(text, x, y, BTN_WIDTH, BTN_HEIGHT)
  end

  def handle_clicks
    x = (@window.width - BTN_WIDTH) / 2
    mx = @window.mouse_x
    my = @window.mouse_y

    if mx.between?(x, x + BTN_WIDTH)
      index = ((my - START_Y) / BTN_SPACING).to_i
      relative_y = (my - START_Y) % BTN_SPACING

      if relative_y <= BTN_HEIGHT && index >= 0
        case index
        when 0 then @window.request_screen(:campaign)
        when 1 then @window.request_screen(:dynamic)
        when 2 then @window.request_screen(:ranking)
        when 3 then @window.request_screen(:achievements)
        when 4 then @window.request_screen(:options)
        when 5 then @window.close
        end
      end
    end
  end
end