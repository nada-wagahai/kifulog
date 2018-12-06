#!/usr/bin/env ruby

require 'sinatra/base'

require './proto/config_pb'

class Server < Sinatra::Base
  def self.start(config)
    options = {
      views: 'templates',
      bind: '127.0.0.1',
      port: 8080,
    }
    run! options
  end

  get "/aaa.kifu" do
    <<EOS
[
  {"type":"FU","x":7,"y":6,"player":"FIRST"},
  {"type":"TO","x":3,"y":7,"player":"SECOND"},
  {"type":"HISHA","x":0,"y":0,"player":"SECOND"},
  {"type":"KAKU","x":0,"y":0,"player":"FIRST"}
]
EOS
  end

  get %r{(.*)} do |path|
    @path = path
    erb :elm
  end
end

def main(args)
  Server.start({})
end

main(ARGV)
