#!/usr/bin/env ruby

require 'sinatra/base'

require './lib/parser'
require './lib/db/file'
require './lib/option'
require './lib/index/file'

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
    @@records_dir = opt.data_dir + "/" + opt.records_dir
    @@index = FileIndex.new(opt.data_dir + "/index.yaml")

    synonym = begin
      CSV.read "./synonym"
    rescue
      []
    end
    Kifu::Player.synonym = synonym

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
    erb :index, :locals => {:index => @@index.scan()}
  end

  get '/kifu/:id/' do
    kifu = @@db.get_kifu(params['id'])
    not_found if kifu.nil?

    erb :kifu, :locals => {kifu: kifu, params: params}
  end

  get '/kifu/:kifu_id/:seq' do
    kifu = @@db.get_kifu(params['kifu_id'])
    not_found if kifu.nil?

    seq = params['seq'].to_i
    step = seq != 0 ? kifu.steps[seq-1] : nil
    board_id = kifu.board_ids[seq]

    board = @@db.get_board(board_id)
    not_found if board.nil?

    step_list = @@db.get_step_list(board_id)
    step_ids = step_list.step_ids.select {|step_id|
      step_id.kifu_id != params['kifu_id']
    }
    kifu_list = @@db.batch_get_kifu(step_ids.map {|s| s.kifu_id })

    captured_first, captured_second, pieces = board.to_v
    erb :scene, :locals => {
      captured_first: captured_first,
      captured_second: captured_second,
      pieces: pieces,
      kifu: kifu,
      step: step,
      steps: step_ids.zip(kifu_list),
    }
  end

  before '/admin*' do
    authorize
  end

  get '/admin' do
    erb :admin
  end

  post '/admin/upload' do
    input = params['kifu']

    parser = Parser.new
    kifu = parser.parse! input
    boards = kifu.boards!

    file = @@records_dir + '/' + kifu.kifu_id
    IO.write(file, input)

    @@db.put_kifu(kifu)
    @@index.put(kifu)
    boards.each_with_index do |board, i|
      @@db.put_board(board)
      @@db.put_step_list(board.to_key, kifu.kifu_id, kifu.steps[i-1]) if i != 0
    end

    redirect back
  end

  get '/admin/download/:id' do
    file = @@records_dir + '/' + params[:id]
    not_found if !File.exist? file

    send_file file, :filename => "kifu-%s.txt" % params[:id]
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
