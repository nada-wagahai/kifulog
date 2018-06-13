#!/usr/bin/env ruby

require './lib/db/file'
require './lib/index/es'
require './lib/option'

def main(args)
  opt = Option.new(args)

  db = FileDB.new(opt.data_dir + "/db")

  index = EsIndex.new kifu_index: opt.kifu_index, step_index: opt.step_index, log: opt.es_log

  ks = db.get_kifu_all
  ks.each do |kifu|
    index.put(kifu)
  end
end

main(ARGV)
