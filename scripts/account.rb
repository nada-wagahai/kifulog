#!/usr/bin/env ruby

require 'bcrypt'

require './lib/db/file'
require './lib/index/es'
require './proto/account_pb'
require './proto/config_pb'

def main(args)
  if args.size != 5
    puts "Usage: %s ID PASSWORD ROLE PLAYER_ID NAME" % $0
    exit 1
  end

  id = args.shift
  password = args.shift
  role = args.shift
  player_id = args.shift
  name = args.shift

  config = Config::Config.decode_json IO.read "config.json"

  hashed_password = BCrypt::Password.create(password)
  acc = Account::Account.new(
    id: id,
    hashed_password: hashed_password.to_s,
    role: role,
    player_id: player_id,
    name: name,
  )

  db = FileDB.new(config.data_dir + "/db")
  index = EsIndex.new(
    kifu_index: config.kifu_index,
    step_index: config.step_index,
    account_index: config.account_index,
    log: config.es_log,
  )

  db.put_account(acc)
  index.put_account(acc)
  puts "SUCCESSS"
end

main(ARGV)
