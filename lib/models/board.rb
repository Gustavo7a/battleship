class Board
  WATER = 0
  HIT = 2
  MISS = 3

  def initialize
    @grid = Array.new(10) { Array.new(10, WATER) }
  end

  def status_at(x, y)
    if inside_bounds?(x, y)
      @grid[y][x]
    end
  end

  def inside_bounds?(x, y)
    x.between?(0, 9) && y.between?(0, 9)
  end

  def set_status(x, y, value)
    if inside_bounds?(x, y)
      @grid[y][x] = value
    end
  end

  def place_ship(ship, x, y, orientation)
    return false unless valid_position?(ship, x, y, orientation)

    size = ship.ship_size

    if orientation == :horizontal
      (0...size).each do |i|
        @grid[y][x + i] = ship
        ship.positions << [x + i, y]
      end
    else # vertical
      (0...size).each do |i|
        @grid[y + i][x] = ship
        ship.positions << [x, y + i]
      end
    end
    true
  end

  private

  def valid_position?(ship, x, y, orientation)
    size = ship.ship_size

    if orientation == :horizontal
      return false unless inside_bounds?(x + size - 1, y)
      (0...size).each do |i|
        return false if @grid[y][x + i] != WATER
      end
    else # vertical
      return false unless inside_bounds?(x, y + size - 1)
      (0...size).each do |i|
        return false if @grid[y + i][x] != WATER
      end
    end
    true
  end
end