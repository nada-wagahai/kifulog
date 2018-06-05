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

class Kifu::Piece
  def <=>(o)
    c = [self, o]
    r = cmp(o)
    raise "Same piece" if r == 0
    puts "%s => %s" % [c, r == -1]
    r
  end

  def captured?
    pos.nil? || self.pos.x == 0
  end

  def name
    Kifu::Piece::Type.name(self.type)
  end

  private

  def cmp(o)
    if self.captured? && o.captured?
      t = Kifu::Player::Order
      a = t.resolve(o.order) <=> t.resolve(self.order)
      if a == 0
        t = Kifu::Piece::Type
        return t.resolve(self.type) <=> t.resolve(o.type)
      end
      return a
    elsif self.captured?
      return self.order == :SECOND ? -1 : 1
    elsif o.captured?
      return o.order == :SECOND ? 1 : -1
    end

    py = self.pos.y <=> o.pos.y
    return py if py != 0

    self.pos.x <=> o.pos.x
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

module Kifu::Player::Order
  def self.label(sym)
    case sym
    when :FIRST
      "☗"
    when :SECOND
      "☖"
    else
      raise "unknown order = %s" % sym
    end
  end
end

class Kifu::Step
  def move
    str = Kifu::Player::Order.label(self.player)

    return str + "投了" if finished

    str << pos.to_code + Kifu::Piece::Type.name(piece)
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

class Kifu::Board
  def self.init
    ps = []

    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 1, y: 1), type: :KYOU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 2, y: 1), type: :KEI, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 3, y: 1), type: :GIN, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 4, y: 1), type: :KIN, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 5, y: 1), type: :GYOKU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 6, y: 1), type: :KIN, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 7, y: 1), type: :GIN, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 8, y: 1), type: :KEI, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 9, y: 1), type: :KYOU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 2, y: 2), type: :KAKU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 8, y: 2), type: :HISHA, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 1, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 2, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 3, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 4, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 5, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 6, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 7, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 8, y: 3), type: :FU, order: :SECOND)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 9, y: 3), type: :FU, order: :SECOND)

    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 1, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 2, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 3, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 4, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 5, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 6, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 7, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 8, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 9, y: 7), type: :FU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 2, y: 8), type: :HISHA, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 8, y: 8), type: :KAKU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 1, y: 9), type: :KYOU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 2, y: 9), type: :KEI, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 3, y: 9), type: :GIN, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 4, y: 9), type: :KIN, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 5, y: 9), type: :GYOKU, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 6, y: 9), type: :KIN, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 7, y: 9), type: :GIN, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 8, y: 9), type: :KEI, order: :FIRST)
    ps << Kifu::Piece.new(pos: Kifu::Pos.new(x: 9, y: 9), type: :KYOU, order: :FIRST)

    b = Kifu::Board.new(pieces: ps)
    b.normalize!
    b
  end

  def normalize!
    pieces.sort!
  end
end
