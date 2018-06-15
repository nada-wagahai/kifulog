#!/usr/bin/env ruby

require './lib/db/file'
require './lib/index/es'
require './lib/option'

def main(args)
  opt = Option.new(args)

  db = FileDB.new(opt.data_dir + "/db")

  index = EsIndex.new(
    kifu_index: opt.kifu_index,
    step_index: opt.step_index,
    account_index: opt.account_index,
    log: opt.es_log,
  )

  db.get_kifu_all().each do |kifu|
    index.put(kifu)
  end

  db.get_accounts_all().each do |account|
    index.put_account(account)
  end
end

main(ARGV)
