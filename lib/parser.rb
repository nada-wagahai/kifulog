class Parser
  @@sep = "："

  attr_reader :raw_text
  attr_reader :start_date, :end_date
  attr_reader :player_first, :player_second

  START_LABEL = "開始日時"
  END_LABEL = "終了日時"
  FIRST_PLAYER_LABEL = "先手"
  SECOND_PLAYER_LABEL = "後手"

  def initialize(synonym)
    @synonym = synonym
    @procs = [
      :date, # 開始日時
      :date, # 終了日時
      :echo, # 手割合
      :echo, # 棋戦
      :player, # 先手
      :player, # 後手
      :echo, # ヘッダ
    ].map {|s|
      method(s)
    }
  end

  def date(line)
    label, d = line.split(@@sep)
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
    label, pl = line.split(@@sep)
    case label
    when FIRST_PLAYER_LABEL
      @player_first = pl
    when SECOND_PLAYER_LABEL
      @player_second = pl
    end
    label + @@sep + mask(pl)
  end

  def echo(line)
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
