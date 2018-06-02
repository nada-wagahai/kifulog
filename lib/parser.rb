require "./proto/kifu_pb"

class Parser
  attr_reader :raw_text
  attr_reader :start_date, :end_date
  attr_reader :player_first, :player_second

  SEP = "："
  START_LABEL = "開始日時"
  END_LABEL = "終了日時"
  FIRST_PLAYER_LABEL = "先手"
  SECOND_PLAYER_LABEL = "後手"

  X = "１２３４５６７８９"
  Y = "一二三四五六七八九"
  PIECES = ["王", "金", "銀", "成銀", "桂", "成桂", "香", "成香", "角", "馬", "飛", "竜", "歩", "と"]

  PAT = Regexp.compile("([%s])([%s])(%s)(成)?(打)?" % [X, Y, PIECES.join("|")])

  def initialize(synonym)
    @synonym = synonym
    @steps = []
    @procs = [
      :date, # 開始日時
      :date, # 終了日時
      :echo, # 手割合
      :echo, # 棋戦
      :player, # 先手
      :player, # 後手
      :echo, # ヘッダ
    ].map {|s|
      self.method(s)
    }
  end

  def date(line)
    label, d = line.split(SEP)
    case label
    when START_LABEL
      @start_date = d
    when END_LABEL
      @end_date = d
    end
    line
  end

  def mask(name)
    @synonym.find(proc { ["", "*****"] }) {|s| s[0] == name }[1]
  end

  def player(line)
    label, pl = line.split(SEP)
    case label
    when FIRST_PLAYER_LABEL
      @player_first = pl
    when SECOND_PLAYER_LABEL
      @player_second = pl
    end
    label + SEP + mask(pl)
  end

  def echo(line)
    line
  end

  def step(line)
    fields = line.strip.split(" ")
    seq = fields.shift.to_i
    step_str, prev_str = fields.shift.split(/[\(\)]/)
    fields.shift
    thinking_str, timestamp_str = fields.shift.chop.split("/")

    m, s = thinking_str.split(":").map{|v| v.to_i}
    thinking = m * 60 + s
    h, m, s = timestamp_str.split(":").map{|v| v.to_i}
    timestamp = h * 60 * 60 + m * 60 + s

    pos, piece, promoted, putted = if step_str == "投了"
      [Kifu::Pos.new(x: 0, y: 0), 0, false, false]
    else
      m = PAT.match(step_str)
      [
        Kifu::Pos.new(x: X.index(m[1]) + 1, y: Y.index(m[2]) + 1),
        PIECES.index(m[3]) + 1,
        !m[4].nil?,
        !m[5].nil?,
      ]
    end

    px, py = prev_str.nil? ? [0, 0] : prev_str.chars.map {|c| c.to_i}
    @steps << Kifu::Step.new(
      seq: seq,
      pos: pos,
      prev: Kifu::Pos.new(x: px, y: py),
      player: seq.odd? ? Kifu::Player::Order::FIRST : Kifu::Player::Order::SECOND,
      piece: piece,
      promoted: promoted,
      putted: putted,
      timestamp_sec: timestamp,
      thinking_sec: thinking,
    )

    line
  end

  def parse!(file)
    lines = []
    procs = @procs.clone
    IO.readlines(file).each do |line|
      m = procs.shift
      lines << if m.nil?
        line.chomp
      else
        m.call line.chomp
      end
    end
    @raw_text = lines.join($/)
  end
end
