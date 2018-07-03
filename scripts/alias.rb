#!/usr/bin/env ruby

require './lib/parser'
require './lib/db/file'
require './proto/config_pb'

def main(args)
  config = Config::Config.decode_json IO.read "config.json"
  records_dir = "%s/records" % config.data_dir

  db = FileDB.new(config.data_dir + "/db")
  Dir["%s/*" % records_dir].each do |file|
    parser = Parser::Shogi24.new

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
