#!/usr/bin/env ruby

require './lib/option'
require './lib/db/file'
require './proto/kifu_pb'

def main(args)
  opt = Option.new(args)

  if args.size != 2
    puts "Usage: %s target_id alias_id" % $0
    exit 1
  end
  target_id = args.shift
  alias_id = args.shift

  db = FileDB.new(opt.data_dir + "/db")

  db.put_kifu_alias(target_id, alias_id)
end

main(ARGV)
