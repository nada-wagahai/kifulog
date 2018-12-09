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
{"pieces":[
  {"type":"FU","pos":{"x":7,"y":6}},
  {"type":"TO","pos":{"x":3,"y":7},"order":"SECOND"},
  {"type":"HISHA","pos":{"x":0,"y":0},"order":"SECOND"},
  {"type":"KAKU","pos":{"x":0,"y":0},"order":"FIRST"}
]}
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
