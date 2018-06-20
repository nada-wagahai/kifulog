#!/usr/bin/env ruby

require './lib/db/file'
require './proto/config_pb'
require './proto/kifu_pb'

def main(args)
  config = Config::Config.decode_json IO.read "config.json"

  if args.size != 2
    puts "Usage: %s target_id alias_id" % $0
    exit 1
  end
  target_id = args.shift
  alias_id = args.shift

  db = FileDB.new(config.data_dir + "/db")

  db.put_kifu_alias(target_id, alias_id)
end

main(ARGV)
