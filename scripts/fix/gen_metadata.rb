#!/usr/bin/env ruby

require './lib/parser'
require './lib/db/file'
require './lib/index/es'
require './proto/config_pb'

def main(args)
  config = Config::Config.decode_json IO.read "config.json"
  records_dir = "%s/records" % config.data_dir

  owner = "nada_wagahai"
  db = FileDB.new(config.data_dir + "/db")
  index = EsIndex.new(
    index: config.index,
    log: config.es_log,
  )
  Dir["%s/*" % records_dir].each do |file|
    kifu_id = File.basename file
    t = File.mtime file

    metadata = Kifu::Metadata.new(
      kifu_id: kifu_id,
      owner_id: owner,
      uploaded_ts: t.to_i,
    )
    p metadata
    kifu = db.get_kifu(kifu_id)
    db.put_metadata(metadata)
    index.put(kifu, metadata)
  end
end

main(ARGV)
