class Kifu::Kifu
  def normalize!
    t = Kifu::Player::Order
    players.sort! {|a, b| t.resolve(a.order) <=> t.resolve(b.order) }
    steps.sort! {|a, b| a.seq <=> b.seq }
    self
  end

  def kifu_id
    "%d:%s" % [start_ts, players.map {|p| p.name}.join("-")]
  end
end
