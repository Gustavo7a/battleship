# frozen_string_literal: true

class Warship
  attr_accessor :ship_size, :positions, :hits, :status

  INTACT    = 0
  DAMAGED   = 1
  DESTROYED = 2

  def initialize(ship_size)
    @ship_size = ship_size
    @positions = []
    @hits = 0
    @status = INTACT
  end

  def receive_hit
    @hits += 1
    if @hits < @ship_size
      @status = DAMAGED
    elsif @hits.size == @ship_size
      @status = DESTROYED
    end
  end

end
