#!/usr/bin/env ruby

require 'sinatra/base'

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

class Parser
  @@sep = "："
  def self.sep
    @@sep
  end

  attr_reader :start_date, :end_date

  START_LABEL = "開始日時"
  END_LABEL = "開始日時"

  def initialize(synonym)
    @synonym = synonym
    @procs = [
      :date,
      :date,
      nil,
      nil,
      :player,
      :player,
    ].map {|s|
      if s.nil?
        nil
      else
        method(s)
      end
    }
  end

  def date(line)
    label, d = line.split(@@sep)
    case label
    when START_LABEL
      @start_date = d
    when END_LABEL
      @end_date = d
    end
    line
  end 

  def mask(name)
    @synonym.find(proc { ["", "*****"] }) {|s| s[0] == name }[1]
  end
  
  def player(line)
    m, pl = line.split(@@sep)
    m + @@sep + mask(pl)
  end

  def parse!(file)
    lines = []
    procs = @procs.clone
    IO.readlines(file).each do |line|
      m = procs.shift
      lines << if m.nil?
        line.chomp
      else
        m.call line.chomp
      end
    end
    lines.join($/)
  end
end

class Server < Sinatra::Base
  require 'psych'
  require 'csv'

  def self.start(opt)
    @@index_file = opt.data_dir + "/index.yaml"
    @@records_dir = opt.data_dir + "/" + opt.records_dir
    @@index = begin
      Psych.load_file @@index_file
    rescue
      []
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

  get '/records/:id' do
    c = @@index[params['id']]
    not_found if c.nil?

    file = @@records_dir + '/' + c[:id]
    not_found if !File.exist? file

    parser = Parser.new(@@synonym)
    text = parser.parse! file
    erb :record, :locals => {
      id: c[:id],
      title: c[:title],
      text: text,
    }
  end

  before '/admin*' do
    authorize
  end

  get '/admin' do
    erb :admin
  end

  post '/admin/reindex' do
    @@index = {}
    Dir.entries(@@records_dir).grep_v(".").grep_v("..").each do |file|
      open(@@records_dir + "/" + file) {|f|
        date = f.readline.chomp.split(Parser.sep)[1]
        @@index[file] = {:id => file, :title => date}
      }
    end
    IO.write @@index_file, Psych.dump(@@index)
    redirect back
  end

  post '/admin/upload' do
    kifu = params['kifu']
    file = @@records_dir + "/" + Time.now.to_i.to_s
    IO.write(file, kifu)
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
