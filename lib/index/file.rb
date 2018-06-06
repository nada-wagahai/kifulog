require 'psych'

class FileIndex
  def initialize(path)
    @path = path
    begin
      @id_db = Psych.load_file path
    rescue
      @id_db = {}
    end
  end

  def scan()
    @id_db.values
  end

  def put(kifu)
    id = kifu.kifu_id
    @id_db[id] = {id: id, title: kifu.start_time}
    save!
  end

  def get(kifu_id)
    @id_db[kifu_id]
  end

  private

  def save!
    IO.write @path, Psych.dump(@id_db)
  end
end
