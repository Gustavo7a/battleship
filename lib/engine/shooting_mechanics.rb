require_relative '../models/board'
require_relative '../models/ships/ship'
class ShootingMechanics
  RESULTS = [:WATER, :DAMAGED, :DESTROYED, :REPEATED, :INVALID].freeze
  def initialize(board)
    @board = board
  end

  def shoot(x, y)
    return :INVALID unless @board.inside_bounds?(x, y)
    content = @board.status_at(x, y)
    return :REPEATED if content == Board::HIT or content == Board::MISS


    if content.is_a?(Ship)
      ship = content
      ship.receive_hit
      @board.set_status(x, y, Board::HIT)
      return ship.status ? :DESTROYED : :DAMAGED
    else
      @board.set_status(x, y, Board::MISS)
      return :WATER
    end
  end
end