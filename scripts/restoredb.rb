#!/usr/bin/env ruby

require './lib/option'
require './lib/parser'
require './lib/db/file'
require './lib/index/file'

def main(args)
  opt = Option.new(args)
  records_dir = "%s/%s" % [opt.data_dir, opt.records_dir]

  db = FileDB.new(opt.data_dir + "/db")
  index = FileIndex.new(opt.data_dir + "/index.yaml")
  Dir["%s/*" % records_dir].each do |file|
    parser = Parser.new

    input = ""
    open(file) {|f|
      input = f.read
    }

    kifu = parser.parse! input
    boards = kifu.boards!

    db.put_kifu(kifu)
    index.put(kifu)
    boards.each_with_index do |board, i|
      db.put_board(board)
      db.put_step_list(board.to_key, kifu.kifu_id, kifu.steps[i-1]) if i != 0
    end

    kifu_id = kifu.kifu_id
    filename = File.basename file
    if kifu_id != filename
      File.rename(file, "%s/%s" % [records_dir, kifu_id])
    end
  end
end

main(ARGV)
