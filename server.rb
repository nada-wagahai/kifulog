#!/usr/bin/env ruby

require 'sinatra/base'
require 'sinatra/cookies'
require 'bcrypt'
require 'securerandom'
require 'json'

require 'proto/config_pb'
require 'proto/kifu_pb'
require 'proto/account_pb'
require 'proto/comment_pb'
require 'proto/api_pb'

require 'lib/parser'
require 'lib/pb'
require 'lib/db/file'
require 'lib/index/es'

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

    def player_map(kifus, ids)
      player_ids = kifus.map{|kifu|
        kifu.players.map {|p| p.name }
      }.flatten.uniq
      account_ids = @@index.search_accounts(player_ids)
      accounts = @@db.batch_get_account(account_ids + ids)

      @player_map = {}
      accounts.each do |account|
        @player_map[account.player_id] = account.name
        @player_map[account.id] = account.name
      end
      p @player_map
      @player_map
    end

    def mask(meta, name)
      if !meta.nil? && name == "プレイヤー"
        p meta
        @player_map.fetch(meta.owner_id) {|key| login? ? key : "*****" }
      else
        @player_map.fetch(name) {|key| login? ? key : "*****" }
      end
    end

    def title(kifu)
      date = kifu.start_time.strftime("%Y/%m/%d %R")
      players = "%s - %s" % [
        kifu.first_players.map {|p| mask nil, p.name}.join(", "),
        kifu.second_players.map {|p| mask nil, p.name}.join(", "),
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

    player_map(ks, [])

    erb :index
  end

  get '/api/kifu/:kifu_id' do
    authorize!

    kifu = @@db.get_kifu(params['kifu_id'])
    not_found if kifu.nil?

    m = @@db.batch_get_metadata(params['kifu_id'])[0]

    player_map([kifu], [m.owner_id])
    kifu.players.map! do |player|
      if kifu.game_name != "ぴよ将棋" || player.name == "プレイヤー"
        name = mask(m, player.name)
        player.name = name
      end
      player
    end

    kifu.to_json
  end

  post '/api/board/:board_id/comment' do
    authorize!
    not_found if !login?

    data = JSON.parse request.body.read

    not_found unless data.key?('comment') && data.key?('kifu_id') && data.key?('seq')

    kifu = @@db.get_kifu(data['kifu_id'])
    not_found if kifu.nil? || !kifu.alias.empty?

    timestamp = (Time.now.to_f * 1000).to_i
    comment = Comment::Comment.new(
      id: SecureRandom.uuid,
      owner_id: @session.account_id,
      text: data['comment'],
      created_ms: timestamp,
      updated_ms: timestamp,
      board_id: params['board_id'],
      kifu_id: data['kifu_id'],
      seq: data['seq'].to_i,
    )

    @@db.put_comment(comment)
    @@index.put_comment(comment)

    "true"
  end

  get '/api/board/:board_id' do
    authorize!

    board_id = params['board_id']

    board = @@db.get_board(board_id)

    comment_ids = @@index.search_comment(board_id: board_id)
    comments = @@db.batch_get_comments(comment_ids)

    account_ids = comments.select{|c|!c.nil?}.map {|c| c.owner_id }
    owner_map = @@db.batch_get_account(account_ids).map {|a| [a.id, a.name]}.to_h
    comments.map! {|comment|
      Api::Comment.new(
        id: comment.id,
        name: owner_map[comment.owner_id],
        text: comment.text,
        owned: !@session.nil? && comment.owner_id == @session.account_id,
      )
    }

    step_ids = @@index.search_step(board_id)
    kifu_ids = step_ids.map {|s| s.kifu_id }
    kifus = @@db.batch_get_kifu(kifu_ids)
    metadata = @@db.batch_get_metadata(kifu_ids).map {|m|
      [m.kifu_id, m]
    }.to_h

    player_map(kifus, [])
    kifu_ids.zip(kifus).map! do |kifu_id, kifu|
      kifu.players.map! do |player|
        name = mask(metadata[kifu_id], player.name)
        player.name = name
        player
      end
      kifu
    end

    steps = step_ids.zip(kifus).map {|step_id, kifu|
      Api::Step.new(
        kifu_id: step_id.kifu_id,
        seq: step_id.seq,
        start_ts: kifu.start_ts,
        players: kifu.players.to_a,
      )
    }

    Api::BoardResponse.new(
      board: board,
      comments: comments,
      steps: steps,
    ).to_json
  end

  post "/api/comment/:comment_id/delete" do
    authorize!

    not_found if !login?

    comments = @@db.batch_get_comments([params["comment_id"]])
    comment = comments.shift
    not_found if comment.nil?
    not_found if @session.role != :ADMIN && comment.owner_id != @session.account_id

    @@db.delete_comment(comment.id)
    @@index.delete_comment(comment.id)

    "true"
  end

  get '/kifu/:kifu_id' do
    authorize!
    erb :scene
  end

  get '/kifu/:kifu_id/:seq' do
    authorize!
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

    player_map(ks, [])

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
