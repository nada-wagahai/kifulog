#!/usr/bin/env ruby

require 'sinatra/base'
require 'sinatra/cookies'
require 'bcrypt'
require 'securerandom'

require './proto/config_pb'
require './proto/kifu_pb'
require './proto/account_pb'
require './proto/comment_pb'

require './lib/parser'
require './lib/pb'
require './lib/db/file'
require './lib/index/es'

def prepare(config)
  Dir.mkdir config.data_dir if !Dir.exist? config.data_dir

  records_dir = config.data_dir + "/records"
  Dir.mkdir records_dir if !Dir.exist? records_dir
end

class Server < Sinatra::Base
  helpers Sinatra::Cookies

  def self.start(config)
    @@script_name = config.script_name
    @@db = FileDB.new(config.data_dir + "/db")
    @@records_dir = config.data_dir + "/records"
    @@index = EsIndex.new(
      index: config.index,
      log: config.es_log,
    )

    options = {
      :views => 'templates',
      :bind => '127.0.0.1',
      :port => config.port,
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
      }.flatten.uniq
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
    @index = ids.zip(ks).map { |id, kifu|
      {id: id, kifu: kifu}
    }

    if login?
      cids = @@index.search_comment(order: "desc", size: 10, except_owner: @session.account_id )
      @recent_comments = @@db.batch_get_comments(cids)
    else
      @recent_comments = []
    end

    player_map(ks)

    erb :index
  end

  get '/kifu/:id/' do
    authorize!

    kifu = @@db.get_kifu(params['id'])
    not_found if kifu.nil?

    if !kifu.alias.empty?
      redirect to('/kifu/%s/' % kifu.alias)
    end

    player_map([kifu])

    comment_ids = @@index.search_comment(kifu_id: params['id'])
    comments = @@db.batch_get_comments(comment_ids)

    @seq_comment = Hash.new []
    comments.each {|c|
      @seq_comment[c.seq] += [c]
    }

    erb :kifu, :locals => {
      kifu: kifu,
      params: params,
      session: @session,
    }
  end

  get '/api/kifu/:kifu_id' do
    kifu = @@db.get_kifu(params['kifu_id'])
    not_found if kifu.nil?

    # player mask

    kifu.to_json
  end

  get '/api/kifu/:kifu_id/:seq' do
    p cookies[:session_id] # XXX

    kifu = @@db.get_kifu(params['kifu_id'])
    not_found if kifu.nil?

    seq = params['seq'].to_i
    step = seq != 0 ? kifu.steps[seq-1] : nil
    board_id = kifu.board_ids[seq]

    board = @@db.get_board(board_id)
    not_found if board.nil?

    board.step = step

    board.to_json
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

=begin
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

    account_ids = comments.select{|c|!c.nil?}.map {|c| c.owner_id }
    @owner_map = @@db.batch_get_account(account_ids).map {|a| [a.id, a.name]}.to_h
=end

    @kifu=params['kifu_id']
    @seq=params['seq']
   # :locals => {
      #captured_first: captured_first,
      #captured_second: captured_second,
      #pieces: pieces,
      #kifu: kifu,
      #step: step,
      #steps: steps,
      #comments: comments,
   # }
    erb :scene
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
    token = SecureRandom.base64 30
    cookies[:token] = token.chomp
    erb :login, :locals => {
      token: token,
    }
  end

  post "/comment/:comment_id/delete" do
    authorize!

    not_found if !login?

    comments = @@db.batch_get_comments([params["comment_id"]])
    comment = comments.shift
    not_found if comment.nil?
    not_found if @session.role != :ADMIN && comment.owner_id != @session.account_id

    @@db.delete_comment(comment.id)
    @@index.delete_comment(comment.id)

    redirect back
  end

  post '/login' do
    if cookies[:token] != params["token"].chomp
      puts "token unmatch"
      halt 401, "Unauthorized"
    end

    account = @@db.get_account(params["id"])
    if account.nil?
      puts "account not found: %s" % params["id"]
      halt 401, "Unauthorized" 
    end

    password = BCrypt::Password.new(account.hashed_password)
    if password != params["password"].chomp
      puts "password unmatch: account=%s" % account.id
      halt 401, "Unauthorized"
    end

    session_id = SecureRandom.base64 30
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

  get '/home' do
    authorize!
    not_found if @session.nil?

    ids = @@index.search_kifu(owner: @session.account_id)
    ks = @@db.batch_get_kifu(ids)
    @index = ids.zip(ks).map { |id, kifu|
      {id: id, kifu: kifu}
    }

    player_map(ks)

    ids = @@index.search_comment(owner: @session.account_id)
    @comments = @@db.batch_get_comments(ids)

    erb :home
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

    parser = nil
    case params['format']
    when "24"
      parser = Parser::Shogi24.new
    when "KIF"
      parser = Parser::Kif.new
    else
      halt 400, "Unknown format" 
    end

    kifu = nil
    begin
      kifu = parser.parse! input
    rescue e
      halt 400, "Parse error"
    end
    boards = kifu.boards!

    kifu_id = kifu.id

    file = @@records_dir + '/' + kifu_id
    IO.write(file, input)

    metadata = Kifu::Metadata.new(
      kifu_id: kifu_id,
      owner_id: @session.account_id,
      uploaded_ts: Time.now.to_i,
    )

    @@db.put_kifu(kifu)
    @@db.put_metadata(metadata)
    @@index.put(kifu, metadata)
    @@db.put_boards(boards)

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
  config = Config::Config.decode_json IO.read "config.json"
  prepare(config)
  Server.start(config)
end

main(ARGV)
