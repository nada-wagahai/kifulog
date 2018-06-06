require 'time'
require "./proto/kifu_pb"
require "./lib/pb"

class Parser
  attr_reader :start_date, :end_date
  attr_reader :handicap, :game_name
  attr_reader :players
  attr_reader :steps

  SEP = "："
  START_LABEL = "開始日時"
  END_LABEL = "終了日時"
  HANDICAP_LABEL = "手合割"
  GAME_LABEL = "棋戦"
  FIRST_PLAYER_LABEL = "先手"
  SECOND_PLAYER_LABEL = "後手"

  PAT = Regexp.compile("([%s])([%s])(%s)(成)?(打)?" % [Kifu::Pos::X, Kifu::Pos::Y, Kifu::Piece::Type::PIECES.join("|")])

  def initialize
    @players = []
    @steps = []
    @procs = [
      :date, # 開始日時
      :date, # 終了日時
      :handicap_p, # 手割合
      :game_p, # 棋戦
      :player, # 先手
      :player, # 後手
      :nop, # ヘッダ
    ].map {|s|
      method(s)
    }
  end

  def date(line)
    label, d = line.split(SEP)
    case label
    when START_LABEL
      @start_date = Time.parse d
    when END_LABEL
      @end_date = Time.parse d
    end
  end

  def player(line)
    label, pl = line.split(SEP)
    case label
    when FIRST_PLAYER_LABEL
      @players << Kifu::Player.new(order: 0, name: pl)
    when SECOND_PLAYER_LABEL
      @players << Kifu::Player.new(order: 1, name: pl)
    end
  end

  def handicap_p(line)
    label, @handicap = line.split(SEP)
  end

  def game_p(line)
    label, @game_name = line.split(SEP)
  end

  def nop(line)
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

    pos, piece, promoted, putted, finished = if step_str == "投了"
      [Kifu::Pos.new(x: 0, y: 0), 0, false, false, true]
    else
      m = PAT.match(step_str)
      [
        Kifu::Pos.new(x: Kifu::Pos.from_code_x(m[1]), y: Kifu::Pos.from_code_y(m[2])),
        Kifu::Piece::Type.from_name(m[3]),
        !m[4].nil?,
        !m[5].nil?,
        false,
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
      finished: finished,
      timestamp_sec: timestamp,
      thinking_sec: thinking,
    )
  end

  def parse!(input)
    procs = @procs.clone
    input.split($/).each do |line|
      break if line.empty?
      m = procs.shift
      if m.nil?
        step line.chomp
      else
        m.call line.chomp
      end
    end

    Kifu::Kifu.new(
      start_ts: @start_date.to_i,
      end_ts: @end_date.to_i,
      handicap: @handicap,
      game_name: @game_name,
      players: @players,
      steps: @steps,
    ).normalize!
  end
end
