# Gerencia animações de explosão a partir de um sprite sheet.
#
# O sheet assets/animations/explosion.png é 640×512 com 20 frames de
# 128×128 px organizados em 5 colunas × 4 linhas.
# Cada animação é reproduzida uma única vez e então descartada.
class ExplosionAnimation
  FRAME_W        = 128
  FRAME_H        = 128
  COLS           = 5
  ROWS           = 4
  FRAME_COUNT    = COLS * ROWS   # 20 frames no total
  TICKS_PER_FRAME = 2            # velocidade: 1 frame de animação a cada 2 ticks

  def initialize
    @frames = Gosu::Image.load_tiles(
      File.join('assets', 'animations', 'explosion.png'),
      FRAME_W, FRAME_H
    )
    @active = []   # Array de { x:, y:, size:, tick: }
  end

  # Dispara uma nova explosão.
  # @param px   [Integer] coordenada X (canto superior esquerdo da célula)
  # @param py   [Integer] coordenada Y (canto superior esquerdo da célula)
  # @param size [Integer] tamanho da célula em pixels (usado para escalar o frame)
  def trigger(px, py, size)
    @active << { x: px, y: py, size: size, tick: 0 }
  end

  # Avança um tick em todas as explosões ativas e descarta as concluídas.
  def update
    @active.each { |e| e[:tick] += 1 }
    @active.reject! { |e| e[:tick] >= FRAME_COUNT * TICKS_PER_FRAME }
  end

  # Desenha todas as explosões ativas.
  # @param z [Integer] z-index (deve ficar acima dos grids)
  def draw(z = 6)
    @active.each do |e|
      frame_idx = e[:tick] / TICKS_PER_FRAME
      next if frame_idx >= FRAME_COUNT

      frame = @frames[frame_idx]
      scale = e[:size].to_f / FRAME_W
      frame.draw(e[:x], e[:y], z, scale, scale)
    end
  end
end
