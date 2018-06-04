#!/usr/bin/env ruby

require 'sinatra/base'

require './lib/parser'
require './lib/db/file'

class Option
  require 'optparse'

  attr_accessor :port, :data_dir, :records_dir

  def initialize(args)
    opt = OptionParser.new

    registerServer(opt)
    registerFile(opt)

    opt.parse!(args)
  end

  def registerServer(opt)
    @port = 31011
    opt.on('--port=PORT', 'default: %d' % port) {|v|
      @port = v.to_i
    }
  end

  def registerFile(opt)
    @data_dir = "./data"
    opt.on('--data-dir=DIR', 'default: %s' % data_dir) {|v|
      @data_dir = v
    }

    @records_dir = "records"
    opt.on('--records-dir=DIR', 'default: {data-dir}/%s' % records_dir) {|v|
      @records_dir = v
    }
  end
end

def prepare(opt)
  Dir.mkdir opt.data_dir if !Dir.exist? opt.data_dir

  records_dir = opt.data_dir + "/" + opt.records_dir
  Dir.mkdir records_dir if !Dir.exist? records_dir
end

class Server < Sinatra::Base
  require 'psych'
  require 'csv'

  def self.start(opt)
    @@db = FileDB.new(opt.data_dir + "/db")
    @@index_file = opt.data_dir + "/index.yaml"
    @@records_dir = opt.data_dir + "/" + opt.records_dir
    @@index = begin
      Psych.load_file @@index_file
    rescue
      {}
    end
    @@synonym = begin
      CSV.read "./synonym"
    rescue
      []
    end
    @@credentials = begin
      CSV.read "./credentials"
    rescue
      []
    end

    options = {
      :views => 'templates',
      :bind => '127.0.0.1',
      :port => opt.port,
    }
    run! options
  end

  helpers do
    def authorize
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @@credentials.include?(@auth.credentials)
    end
  end

  get '/' do
    erb :index, :locals => {:index => @@index.values}
  end

  get '/kifu/:id' do
    kifu = @@db.get_kifu(params['id'])
    not_found if kifu.nil?

    kifu.synonym = @@synonym
    erb :kifu, :locals => {kifu: kifu}
  end

  before '/admin*' do
    authorize
  end

  get '/admin' do
    erb :admin
  end

  post '/admin/reindex' do
    @@index = {}
    @@db.get_kifu_all.each do |kifu|
      id = kifu.kifu_id
      @@index[id] = {id: id, :title => kifu.start_time}
    end
    IO.write @@index_file, Psych.dump(@@index)
    redirect back
  end

  post '/admin/upload' do
    input = params['kifu']

    parser = Parser.new
    kifu = parser.parse! input

    file = @@records_dir + '/' + kifu.kifu_id
    IO.write(file, input)

    @@db.put_kifu(kifu)

    redirect back
  end

  get '/admin/download/:id' do
    c = @@index[params['id']]
    not_found if c.nil?

    file = @@records_dir + '/' + c[:id]
    not_found if !File.exist? file

    send_file file, :filename => "kifu-%s.txt" % c[:id]
  end

  not_found do
    "NotFound"
  end
end

def main(args)
  opt = Option.new(args)
  prepare(opt)
  Server.start(opt)
end

main(ARGV)
