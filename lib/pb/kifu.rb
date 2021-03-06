require 'digest'
require './proto/kifu_pb'
require './proto/index_pb'

class Kifu::Kifu
  def normalize!
    t = Kifu::Player::Order
    players.sort! {|a, b| t.resolve(a.order) <=> t.resolve(b.order) }
    steps.sort! {|a, b| a.seq <=> b.seq }
    self
  end

  def boards!
    bs = []
    b = Kifu::Board.init
    self.board_ids << b.to_key
    bs << b
    self.steps.each do |step|
      b = b.do_step(step)
      bs << b
      self.board_ids << b.to_key
    end
    bs
  end

  def start_time
    Time.at start_ts
  end

  def end_time
    Time.at end_ts
  end

  def first_players
    players.select {|p| p.order == :FIRST }
  end

  def second_players
    players.select {|p| p.order == :SECOND }
  end

  def kifu_id_old
    str = players.map {|p| p.name}.join("-")
    "%019d:%s" % [start_ts, Digest::MD5.hexdigest(str)]
  end

  def id
    vs = players.map {|p| p.name}.join("-")
    str = "%d:%s" % [start_ts, vs]
    Digest::MD5.hexdigest(str)
  end
end

class Kifu::Pos
  X = "１２３４５６７８９"
  Y = "一二三四五六七八九"

  def self.from_code_x(c)
    X.index(c) + 1
  end

  def self.from_code_y(c)
    Y.index(c) + 1
  end

  def to_code
    return "" if x == 0 || y == 0
    X[x-1] + Y[y-1]
  end

  def to_a
    [x, y]
  end

  def to_key
    "%d.%d" % self.to_a
  end
end

class Kifu::Piece
  def <=>(o)
    r = cmp(o)
    raise "Same piece: self=%s, o=%s" % [self, o] if r == 0 && !self.captured?
    r
  end

  def capture!
    demote!
    self.pos = Kifu::Pos.new(x: 0, y: 0)
    self.order = Kifu::Player::Order.flip(self.order)
    self
  end

  def captured?
    pos.nil? || self.pos.x == 0
  end

  def promote!
    case self.type
    when :GIN
      self.type = :NARI_GIN
    when :KEI
      self.type = :NARI_KEI
    when :KYOU
      self.type = :NARI_KYOU
    when :KAKU
      self.type = :UMA
    when :HISHA
      self.type = :RYU
    when :FU
      self.type = :TO
    else
      raise "can't promote"
    end
    self
  end

  def name
    Kifu::Piece::Type.name(self.type)
  end

  def name_fig
    Kifu::Piece::Type.name_fig(self.type)
  end

  def to_s
    "%s%s%s" % [Kifu::Player::Order.label(self.order), self.pos.to_code, self.name]
  end

  private

  def cmp(o)
    py = self.pos.y <=> o.pos.y
    return py if py != 0

    px = self.pos.x <=> o.pos.x
    return px if px != 0

    t = Kifu::Player::Order
    ord = t.resolve(self.order) <=> t.resolve(o.order)
    return ord if ord != 0

    t = Kifu::Piece::Type
    return t.resolve(self.type) <=> t.resolve(o.type)
  end

  def demote!
    case self.type
    when :NARI_GIN
      self.type = :GIN
    when :NARI_KEI
      self.type = :KEI
    when :NARI_KYOU
      self.type = :KYOU
    when :UMA
      self.type = :KAKU
    when :RYU
      self.type = :HISHA
    when :TO
      self.type = :FU
    else
      # do nothing
    end
    self
  end
end

module Kifu::Piece::Type
  PIECES = ["王", "飛", "竜", "角", "馬", "金", "銀", "成銀", "桂", "成桂", "香", "成香", "歩", "と", "玉", "龍"]
  PIECES_FIG = ["玉", "飛", "竜", "角", "馬", "金", "銀", "全", "桂", "圭", "香", "杏", "歩", "と"]

  def self.from_name(str)
    code = PIECES.index(str)
    case code
    when 14
      1
    when 15
      3
    else
      code + 1
    end
  end

  def self.name(sym)
    n = resolve(sym)
    raise "unknown piece type = %s(%d)" % [sym, n] if n.nil? || n < 0 || n > PIECES.size
    return "" if n == 0
    PIECES[n-1]
  end

  def self.name_fig(sym)
    n = resolve(sym)
    raise "unknown piece type = %s(%d)" % [sym, n] if n.nil? || n < 0 || n > PIECES.size
    return "" if n == 0
    PIECES_FIG[n-1]
  end
end

class Kifu::Player
  def masked_name
    mask(self.name)
  end

  private

  def mask(n)
    [].find(proc { ["", "*****"] }) {|s| s[0] == n }[1]
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

  def self.flip(sym)
    case sym
    when :FIRST
      :SECOND
    when :SECOND
      :FIRST
    else
      raise "unknown order = %s" % sym
    end
  end
end

class Kifu::Step
  def player_label
    Kifu::Player::Order.label(self.player)
  end

  def move
    str = player_label

    return str + "投了" if finished

    str << pos.to_code + Kifu::Piece::Type.name(piece).tr("王", "玉")
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
    self.pieces.sort!
    self
  end

  def copy
    bytes = Kifu::Board.encode self
    Kifu::Board.decode bytes
  end

  def do_step(step)
    b = self.copy
    return b if step.finished

    h = b.to_h

    dp = h[step.pos.to_key]
    dp.capture! if !dp.nil?

    pkey = step.putted ? step.player.to_s + ":" + step.piece.to_s : step.prev.to_key
    p = h[pkey]
    raise "pkey not found: %s(%s)" % [pkey, step.to_s] if p.nil?
    p.pos = step.pos
    p.promote! if step.promoted

    b.normalize!
  end

  def to_h
    ret = {}
    self.pieces.each do |p|
      key = p.captured? ? p.order.to_s + ":" + p.type.to_s : p.pos.to_key
      ret[key] = p
    end
    ret
  end

  def to_key
    bytes = Kifu::Board.encode self
    Digest::MD5.hexdigest bytes
  end

  def to_v
    captured_first = []
    captured_second = []
    pss = []
    9.times {
      ps = []
      9.times {
        ps << Kifu::Piece.new(type: Kifu::Piece::Type::NULL)
      }
      pss << ps
    }

    self.pieces.each {|p|
      if p.captured?
        case p.order
        when :FIRST
          captured_first << p
        when :SECOND
          captured_second << p
        else
          raise "unknown order = %s" % p.order
        end
      else
        pss[p.pos.y-1][9-p.pos.x] = p
      end
    }

    [captured_first.sort, captured_second.sort, pss]
  end
end
