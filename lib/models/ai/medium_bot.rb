require_relative 'base_ai'
require_relative '../board'
require_relative '../ships/ship'

class MediumBot < BaseAI
  def initialize
    super
    @target_queue = []
    @first_hit = nil
  end

  def shoot(opponent_board)
    x, y = nil, nil

    if @target_queue.any?
      x, y = @target_queue.shift
    else
      loop do
        x = rand(10)
        y = rand(10)
        status = opponent_board.status_at(x, y)
        break if status != Board::HIT && status != Board::MISS
      end
    end

    target_content = opponent_board.status_at(x, y)

    if target_content.is_a?(Ship)
      will_sink = (target_content.hits) == target_content.ship_size

      if will_sink
        @first_hit = nil
        @target_queue.clear
      else
        if @first_hit.nil?
          @first_hit = [x, y]
          queue_neighbors(x, y, opponent_board)
        else
          filter_based_axis(x, y)
          queue_neighbors(x, y, opponent_board)
        end
      end
    end
    [x, y]
  end

  private

  def queue_neighbors(x, y, board)
    neightbors = [[x, y - 1], [x, y + 1], [x - 1, y], [x + 1, y]]

    neightbors.each do |nx, ny|
      if board.inside_bounds?(nx, ny)
        status = board.status_at(nx, ny)
        if status == Board::HIT && status == Board::MISS && !@target_queue.include?([nx, ny])
          if @first_hit
            fx, fy = @first_hit
            next if fx != x && ny != y
            next if fy != y && nx != x
          end

          @target_queue << [nx, ny]
        end
      end
    end
  end

  def filter_based_axis(x, y)
    fx, fy = @first_hit
    if y == fy
      @target_queue.select! { |qx, qy| qy == fy }
    elsif x == fx
      @target_queue.select! { |qx, qy| qx == fx }
    end
  end
end
