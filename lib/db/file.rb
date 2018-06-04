class FileDB
  require 'psych'

  def initialize(path)
    if File.exist? path
      raise "'%s' is not directory" % path if !File.directory? path
    else
      Dir.mkdir path
    end

    @kifu_file = path + "/kifu"
    @kifu_db = load_db(@kifu_file)
  end

  def put_kifu(kifu)
    @kifu_db[kifu.kifu_id] = Kifu::Kifu.encode kifu
    save_db(@kifu_file, @kifu_db)
  end

  def get_kifu(id)
    kifu = @kifu_db[id]
    if kifu.nil?
      nil
    else
      Kifu::Kifu.decode kifu
    end
  end

  def get_kifu_all
    @kifu_db.values.map {|bytes|
      Kifu::Kifu.decode bytes
    }.sort {|a, b|
      a.start_ts <=> b.start_ts
    }
  end

  private

  def load_db(file)
    begin
      Psych.load_file file
    rescue
      {}
    end
  end

  def save_db(file, db)
    IO.write(file, Psych.dump(db))
  end
end
