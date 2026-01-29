require_relative '../board'
require_relative 'base_ai'

class EasyBot < BaseAI

  def shoot(opponent_board)
    loop do
      x = rand(10)
      y = rand(10)

      if opponent_board.status_at(x, y) != :HIT and opponent_board.status_at(x, y) != :MISS
        return [x,y]
      end
    end
  end
end