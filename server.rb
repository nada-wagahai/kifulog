#!/usr/bin/env ruby

require 'sinatra/base'
require 'sinatra/cookies'
require 'base64'
require 'bcrypt'
require 'securerandom'

require './proto/kifu_pb'
require './proto/account_pb'
require './proto/comment_pb'

require './lib/parser'
require './lib/pb'
require './lib/db/file'
require './lib/option'
require './lib/index/es'

def prepare(opt)
  Dir.mkdir opt.data_dir if !Dir.exist? opt.data_dir

  records_dir = opt.data_dir + "/" + opt.records_dir
  Dir.mkdir records_dir if !Dir.exist? records_dir
end

class Server < Sinatra::Base
  require 'psych'
  require 'csv'

  helpers Sinatra::Cookies

  def self.start(opt)
    @@random = Random.new
    @@script_name = opt.script_name
    @@db = FileDB.new(opt.data_dir + "/db")
    @@records_dir = opt.data_dir + "/" + opt.records_dir
    @@index = EsIndex.new(
      kifu_index: opt.kifu_index,
      step_index: opt.step_index,
      account_index: opt.account_index,
      comment_index: opt.comment_index,
      log: opt.es_log,
    )

    options = {
      :views => 'templates',
      :bind => '127.0.0.1',
      :port => opt.port,
    }
    run! options
  end

  before do
    request.script_name = @@script_name
  end

  helpers do
    def authorize!
      session_id = cookies[:session_id]
      @session = @@db.get_session(session_id)
    end

    def login?
      !@session.nil?
    end

    def player_map(kifus)
      player_ids = kifus.map{|kifu|
        kifu.players.map {|p| p.name }
      }.flatten
      account_ids = @@index.search_accounts(player_ids)
      accounts = @@db.batch_get_account(account_ids)

      @player_map = {}
      accounts.each do |account|
        @player_map[account.player_id] = account.name
      end
    end

    def mask(name)
      @player_map.fetch(name) {|key| login? ? key : "*****" }
    end

    def title(kifu)
      date = kifu.start_time.strftime("%Y/%m/%d %R")
      players = "%s - %s" % [
        kifu.first_players.map {|p| mask p.name}.join(", "),
        kifu.second_players.map {|p| mask p.name}.join(", "),
      ]
      "%s %s" % [date, players]
    end
  end

  get '/' do
    authorize!

    ids = @@index.search_kifu()
    ks = @@db.batch_get_kifu(ids)
    player_map(ks)
    index = ids.zip(ks).map { |id, kifu|
      {id: id, kifu: kifu}
    }
    erb :index, :locals => {
      index: index,
      session: @session,
    }
  end

  get '/kifu/:id/' do
    authorize!

    kifu = @@db.get_kifu(params['id'])
    not_found if kifu.nil?

    if !kifu.alias.empty?
      redirect to('/kifu/%s/' % kifu.alias)
    end

    player_map([kifu])

    erb :kifu, :locals => {
      kifu: kifu,
      params: params,
      session: @session,
    }
  end

  get '/kifu/:kifu_id/:seq' do
    authorize!

    kifu = @@db.get_kifu(params['kifu_id'])
    not_found if kifu.nil?

    if !kifu.alias.empty?
      redirect to('/kifu/%s/%s' % [kifu.alias, params['seq']])
    end

    seq = params['seq'].to_i
    step = seq != 0 ? kifu.steps[seq-1] : nil
    board_id = kifu.board_ids[seq]

    board = @@db.get_board(board_id)
    not_found if board.nil?

    steps = @@index.search_step(board_id)
    step_ids = steps.select {|step_id|
      step_id.kifu_id != params['kifu_id']
    }
    kifu_list = @@db.batch_get_kifu(step_ids.map {|s| s.kifu_id })

    player_map([kifu] + kifu_list)

    steps = step_ids.zip(kifu_list)
    captured_first, captured_second, pieces = board.to_v

    comment_ids = @@index.search_comment(board_id: board_id)
    comments = @@db.batch_get_comments(comment_ids)

    erb :scene, :locals => {
      captured_first: captured_first,
      captured_second: captured_second,
      pieces: pieces,
      kifu: kifu,
      step: step,
      steps: steps,
      comments: comments,
    }
  end

  post '/kifu/:kifu_id/:seq/comment' do
    authorize!
    not_found if !login?

    redirect back if params['comment'].nil?

    kifu = @@db.get_kifu(params['kifu_id'])
    not_found if kifu.nil?

    if !kifu.alias.empty?
      redirect to('/kifu/%s/%s' % [kifu.alias, params['seq']])
    end

    seq = params['seq'].to_i
    board_id = kifu.board_ids[seq]

    timestamp = (Time.now.to_f * 1000).to_i
    comment = Comment::Comment.new(
      id: SecureRandom.uuid,
      owner_id: @session.account_id,
      text: params['comment'],
      created_ms: timestamp,
      updated_ms: timestamp,
      board_id: board_id,
      kifu_id: params['kifu_id'],
      seq: seq,
    )

    @@db.put_comment(comment)
    @@index.put_comment(comment)

    redirect to("/kifu/%s/%s" % [params['kifu_id'], params['seq']])
  end

  get '/login' do
    token = Base64.encode64 @@random.bytes(39)
    cookies[:token] = token.chomp
    erb :login, :locals => {
      token: token,
    }
  end

  post '/login' do
    halt 401, "Unauthorized" if cookies[:token] != params["token"].chomp

    account = @@db.get_account(params["id"])
    halt 401, "Unauthorized" if account.nil?

    password = BCrypt::Password.new(account.hashed_password)
    halt 401, "Unauthorized" unless password == params["password"].chomp

    session_id = Base64.encode64(@@random.bytes(39)).chomp
    session = Account::Session.new(
      id: session_id,
      account_id: account.id,
      created_at: Time.now.to_i,
      role: account.role,
    )
    @@db.put_session(session)
    cookies[:session_id] = session_id

    redirect to("/")
  end

  get '/logout' do
    authorize!

    if !@session.nil?
      cookies[:session_id] = nil
    end

    redirect to("/")
  end

  before "/admin*" do
    authorize!

    not_found if @session.nil? || @session.role != :ADMIN
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
