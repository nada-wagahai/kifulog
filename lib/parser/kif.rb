# Kifファイルを読む

require './lib/pb'

class Parser::Kif
  SEP = "："

  def initialize
    @pos = 0
    @lines = []
  end

  def parse!(input)
    @lines = input.split($/)

    readline # header comment
    game_name = readheader
    start_date = readdate
    end_date = readdate
    handicap = readheader
    first_player = readplayer
    second_player = readplayer

    readline # steps header
    steps = []
    flag = true
    while flag
      step = readstep
      steps << step
      flag = !step.finished
    end

    Kifu::Kifu.new(
      start_ts: start_date.to_i,
      end_ts: end_date.to_i,
      handicap: handicap,
      game_name: game_name,
      players: [first_player, second_player],
      steps: steps,
      format: Kifu::Kifu::Format::KIF,
    ).normalize!
  end

  private

  def unreadline
    @pos -= 1
  end

  def readline
    return nil if @lines.size == @pos

    line = @lines[@pos]
    @pos += 1
    line.chomp
  end

  def readheader
    label, line = readline.split(SEP)
    line
  end

  DATE_FORMAT = /(\d+)年(\d+)月(\d+)日\((\S)\) (\d+):(\d+):(\d+)/
  def readdate
    if readheader =~ DATE_FORMAT
      Time.local $1, $2, $3, $5, $6, $7
    end
  end

  def readplayer
    label, name = readline.split(SEP)
    m = /(.+)\((.+)\)/.match(name)
    case label
    when "先手"
      Kifu::Player.new(order: 0, name: m[1], note: m[2])
    when "後手"
      Kifu::Player.new(order: 1, name: m[1], note: m[2])
    end
  end

  PAT = Regexp.compile("([%s])([%s])(%s)(成)?(打)?" % [Kifu::Pos::X, Kifu::Pos::Y, Kifu::Piece::Type::PIECES.join("|")])
  NOTE_FORMAT = /\*#(.+)/
  def readstep
    line = readline

    _d, seq, s, _d2, t = line.split(/\s+/)
    step_str, prev_str = s.split(/[\(\)]/)

    prev = prev_str.nil? ? nil : Kifu::Pos.new(x: prev_str[0].to_i, y: prev_str[1].to_i)

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

    thinking_str, timestamp_str = t.chop.split("/")
    m, s = thinking_str.split(":").map{|v| v.to_i}
    thinking = m * 60 + s
    h, m, s = timestamp_str.split(":").map{|v| v.to_i}
    timestamp = h * 60 * 60 + m * 60 + s

    line = readline
    notes = []
    while line =~ NOTE_FORMAT
      notes << $1.strip
      line = readline
    end
    unreadline

    Kifu::Step.new(
      seq: seq.to_i,
      pos: pos,
      prev: prev,
      piece: piece,
      promoted: promoted,
      putted: putted,
      player: seq.to_i.odd? ? Kifu::Player::Order::FIRST : Kifu::Player::Order::SECOND,
      timestamp_sec: thinking,
      thinking_sec: timestamp,
      finished: finished,
      notes: notes,
    )
  end
end
