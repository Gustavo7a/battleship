require_relative 'base_screen'

# Tela de Login e Cadastro.
# O jogador pode criar uma conta nova ou entrar com uma existente.
# Após autenticação bem-sucedida chama window.on_login(user).
class LoginScreen < BaseScreen
  # Estados internos da tela
  MODE_LOGIN    = :login
  MODE_REGISTER = :register

  COLOR_INPUT_BG      = Gosu::Color.new(0xff_1e293b)
  COLOR_INPUT_BORDER  = Gosu::Color.new(0xff_334155)
  COLOR_INPUT_ACTIVE  = Gosu::Color.new(0xff_d97706)
  COLOR_ERROR         = Gosu::Color.new(0xff_ef4444)
  COLOR_SUCCESS       = Gosu::Color.new(0xff_22c55e)
  COLOR_LABEL         = Gosu::Color.new(0xff_94a3b8)

  INPUT_W = 340
  INPUT_H = 44

  def initialize(window)
    super(window)
    @mode           = MODE_LOGIN
    @username       = ''
    @password       = ''
    @active_field   = :username
    @message        = ''
    @message_color  = COLOR_ERROR
    @label_font     = Gosu::Font.new(16)
    @title_font     = Gosu::Font.new(50, bold: true)
    @welcome_font   = Gosu::Font.new(18, bold: true)
  end

  #  Draw

  def draw
    draw_background
    title = @mode == MODE_LOGIN ? 'LOGIN' : 'CRIAR CONTA'
    draw_header(title)

    center_x = @window.dw / 2

    welcome = "Bem-vindo, marinheiro! Pronto para uma nova aventura?"
    @welcome_font.draw_text(
      welcome,
      center_x - @welcome_font.text_width(welcome) / 2,
      120, 2, 1.0, 1.0, COLOR_LABEL
    )

    # Campo usuário
    draw_label("USUÁRIO", center_x - INPUT_W / 2, 160)
    draw_input_box(@username, center_x - INPUT_W / 2, 180, @active_field == :username)

    # Campo senha
    draw_label("SENHA", center_x - INPUT_W / 2, 244)
    draw_input_box('*' * @password.length, center_x - INPUT_W / 2, 264, @active_field == :password)

    # Botão principal
    btn_label = @mode == MODE_LOGIN ? 'ENTRAR' : 'CADASTRAR'
    draw_btn(btn_label, center_x - 140, 335, 280, 50)

    # Link de alternância
    toggle_text = @mode == MODE_LOGIN ? 'Não tem conta? Cadastre-se' : 'Já tem conta? Entrar'
    @label_font.draw_text(
      toggle_text,
      center_x - @label_font.text_width(toggle_text) / 2,
      400, 2, 1.0, 1.0, COLOR_LABEL
    )

    # Mensagem de feedback
    unless @message.empty?
      @label_font.draw_text(
        @message,
        center_x - @label_font.text_width(@message) / 2,
        440, 2, 1.0, 1.0, @message_color
      )
    end
  end

  # Input

  def button_down(id)
    case id
    when Gosu::MS_LEFT
      handle_click
    when Gosu::KB_TAB
      @active_field = (@active_field == :username) ? :password : :username
    when Gosu::KB_RETURN, Gosu::KB_ENTER
      submit
    when Gosu::KB_BACKSPACE
      if @active_field == :username
        @username = @username[0..-2]
      else
        @password = @password[0..-2]
      end
    end
  end

  def update
    # Captura digitação via Gosu::TextInput
    # usamos button_down com char.
  end

  # Chamado pelo GameWindow para repassar caracteres digitados
  def receive_char(char)
    return unless char =~ /\A[[:print:]]\z/
    if @active_field == :username
      @username << char if @username.length < 24
    else
      @password << char if @password.length < 32
    end
  end

  private

  # Helpers de desenho

  def draw_label(text, x, y)
    @label_font.draw_text(text, x, y, 2, 1.0, 1.0, COLOR_LABEL)
  end

  def draw_input_box(content, x, y, active)
    border_color = active ? COLOR_INPUT_ACTIVE : COLOR_INPUT_BORDER
    @window.draw_rect(x, y, INPUT_W, INPUT_H, COLOR_INPUT_BG)
    # bordas
    t = 2
    @window.draw_rect(x,             y,             INPUT_W, t,      border_color)
    @window.draw_rect(x,             y + INPUT_H-t, INPUT_W, t,      border_color)
    @window.draw_rect(x,             y,             t,       INPUT_H, border_color)
    @window.draw_rect(x + INPUT_W-t, y,             t,       INPUT_H, border_color)

    cursor = active ? '|' : ''
    display = content + cursor
    ty = y + (INPUT_H - @btn_font.height) / 2
    @btn_font.draw_text(display, x + 12, ty, 2, 1.0, 1.0, Theme::COLOR_TEXT)
  end

  # Lógica de clique

  def handle_click
    cx = @window.dw / 2
    mx, my = @window.mx, @window.my

    # Campos de input
    ux = cx - INPUT_W / 2
    @active_field = :username if mx.between?(ux, ux + INPUT_W) && my.between?(180, 180 + INPUT_H)
    @active_field = :password if mx.between?(ux, ux + INPUT_W) && my.between?(264, 264 + INPUT_H)

    # Botão principal
    if mx.between?(cx - 140, cx + 140) && my.between?(335, 385)
      submit
    end

    # Link de alternância
    if my.between?(395, 415)
      toggle_mode
    end
  end

  def toggle_mode
    @mode    = (@mode == MODE_LOGIN) ? MODE_REGISTER : MODE_LOGIN
    @message = ''
    @password = ''
  end

  def submit
    username = @username.strip
    password = @password

    if username.empty? || password.empty?
      set_error('Preencha todos os campos.')
      return
    end

    if @mode == MODE_LOGIN
      user = @window.db.authenticate(username, password)
      if user
        set_success("Bem-vindo, #{user['username']}!")
        @window.on_login(user)
      else
        set_error('Usuário ou senha incorretos.')
      end
    else
      if password.length < 4
        set_error('Senha deve ter ao menos 4 caracteres.')
        return
      end
      user = @window.db.create_user(username, password)
      if user
        set_success("Conta criada! Entrando...")
        @window.on_login(user)
      else
        set_error('Nome de usuário já em uso.')
      end
    end
  end

  def set_error(msg)
    @message       = msg
    @message_color = COLOR_ERROR
  end

  def set_success(msg)
    @message       = msg
    @message_color = COLOR_SUCCESS
  end
end


