#!/usr/bin/env ruby

require './lib/db/file'
require './lib/index/es'
require './proto/config_pb'

def main(args)
  config = Config::Config.decode_json IO.read "config.json"

  db = FileDB.new(config.data_dir + "/db")

  index = EsIndex.new(
    kifu_index: config.kifu_index,
    step_index: config.step_index,
    account_index: config.account_index,
    log: config.es_log,
  )

  db.get_kifu_all().each do |kifu|
    index.put(kifu)
  end

  db.get_accounts_all().each do |account|
    index.put_account(account)
  end
end

main(ARGV)
