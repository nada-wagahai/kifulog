#!/usr/bin/env ruby

require './lib/option'
require './lib/parser'
require './lib/db/file'

def main(args)
  opt = Option.new(args)
  records_dir = "%s/%s" % [opt.data_dir, opt.records_dir]

  db = FileDB.new(opt.data_dir + "/db")
  Dir["%s/*" % records_dir].each do |file|
    parser = Parser.new

    input = ""
    open(file) {|f|
      input = f.read
    }

    kifu = parser.parse! input

    id = kifu.id
    filename = File.basename file
    if id != filename
      File.rename(file, "%s/%s" % [records_dir, id])
      puts "%s,%s" % [filename, id]
    end
  end
end

main(ARGV)
