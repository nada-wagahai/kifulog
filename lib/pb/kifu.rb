require 'digest'

class Kifu::Kifu
  def synonym
    return {} if @synonym.nil?
    @synonym
  end

  def synonym=(syn)
    @synonym = syn
  end

  def normalize!
    t = Kifu::Player::Order
    players.sort! {|a, b| t.resolve(a.order) <=> t.resolve(b.order) }
    steps.sort! {|a, b| a.seq <=> b.seq }
    self
  end

  def start_time
    Time.at start_ts
  end

  def end_time
    Time.at end_ts
  end

  def first_players_name
    players_name(players.select {|p| p.order == :FIRST })
  end

  def second_players_name
    players_name(players.select {|p| p.order == :SECOND })
  end

  def kifu_id
    str = players.map {|p| p.name}.join("-")
    "%d:%s" % [start_ts, Digest::MD5.hexdigest(str)]
  end

  private

  def mask(name)
    synonym.find(proc { ["", "*****"] }) {|s| s[0] == name }[1]
  end

  def players_name(ps)
    ps.map {|p| mask(p.name) }.join(", ")
  end
end

class Kifu::Pos
  X = "１２３４５６７８９"
  Y = "一二三四五六七八九"

  def to_code
    return "" if x == 0 || y == 0
    X[x-1] + Y[y-1]
  end

  def to_a
    [x, y]
  end
end

module Kifu::Piece::Type
  PIECES = ["王", "金", "銀", "成銀", "桂", "成桂", "香", "成香", "角", "馬", "飛", "竜", "歩", "と"]

  def self.name(sym)
    n = resolve(sym)
    raise "unknown piece type = %s(%d)" % [sym, n] if n.nil? || n < 0 || n > PIECES.size
    return "" if n == 0
    PIECES[n-1]
  end
end

class Kifu::Step
  def move
    return "投了" if finished

    str = pos.to_code + Kifu::Piece::Type.name(piece)
    return str + "打" if putted
    str << "成" if promoted
    str + "(%d%d)" % prev.to_a
  end

  def elapsed_time
    m, th_s = thinking_sec.divmod(60)
    th_h, th_m = m.divmod(60)
    m, ts_s = timestamp_sec.divmod(60)
    ts_h, ts_m = m.divmod(60)
    "%02d:%02d:%02d / %02d:%02d:%02d" % [th_h, th_m, th_s, ts_h, ts_m, ts_s]
  end
end
