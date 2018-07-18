require './proto/kifu_pb'
require './proto/account_pb'
require './proto/comment_pb'
require './lib/pb'

class FileDB
  require 'psych'

  def initialize(path)
    if File.exist? path
      raise "'%s' is not directory" % path if !File.directory? path
    else
      Dir.mkdir path
    end

    @kifu_file = path + "/kifu"
    @kifu_db = load_db(@kifu_file)

    @board_file = path + "/board"
    @board_db = load_db(@board_file)

    @account_file = path + "/account"
    @account_db = load_db(@account_file)

    @session_file = path + "/session"
    @session_db = load_db(@session_file)

    @comment_file = path + "/comment"
    @comment_db = load_db(@comment_file)

    @metadata_file = path + "/kifu_meta"
    @metadata_db = load_db(@metadata_file)
  end

  def put_kifu(kifu)
    @kifu_db[kifu.id] = Kifu::Kifu.encode kifu
    save_db(@kifu_file, @kifu_db)
  end

  def put_kifu_alias(target_id, alias_id)
    kifu = Kifu::Kifu.new(alias: alias_id)
    @kifu_db[target_id] = Kifu::Kifu.encode kifu
    save_db(@kifu_file, @kifu_db)
  end

  def get_kifu(id)
    kifu = @kifu_db[id]
    if kifu.nil?
      nil
    else
      Kifu::Kifu.decode kifu
    end
  end

  def batch_get_kifu(ids)
    ret = []
    ids.each do |id|
      ret << get_kifu(id)
    end
    ret
  end

  def get_kifu_all
    @kifu_db.values.map {|bytes|
      Kifu::Kifu.decode bytes
    }
  end

  def put_board(board)
    @board_db[board.to_key] = Kifu::Board.encode board
    save_db(@board_file, @board_db)
  end

  def put_boards(boards)
    boards.each do |board|
      @board_db[board.to_key] = Kifu::Board.encode board
    end
    save_db(@board_file, @board_db)
  end

  def get_board(board_id)
    bytes = @board_db[board_id]
    bytes.nil? ? nil : Kifu::Board.decode(bytes)
  end

  def put_account(account)
    @account_db[account.id] = Account::Account.encode account
    save_db(@account_file, @account_db)
  end

  def get_account(account_id)
    bytes = @account_db[account_id]
    bytes.nil? ? nil : Account::Account.decode(bytes)
  end

  def batch_get_account(account_ids)
    ret = []
    account_ids.each do |account_id|
      ret << get_account(account_id)
    end
    ret.select {|a| !a.nil? }
  end

  def get_accounts_all()
    @account_db.values.map {|bytes|
      Account::Account.decode bytes
    }
  end

  def put_session(session)
    @session_db[session.id] = Account::Session.encode session
    save_db(@session_file, @session_db)
  end

  def get_session(session_id)
    bytes = @session_db[session_id]
    bytes.nil? ? nil : Account::Session.decode(bytes)
  end

  def put_comment(comment)
    @comment_db[comment.id] = Comment::Comment.encode comment
    save_db(@comment_file, @comment_db)
  end

  def batch_get_comments(comment_ids)
    return [] if comment_ids.empty?

    @comment_db.values_at(*comment_ids).map { |bytes|
      bytes.nil? ? nil : Comment::Comment.decode(bytes)
    }
  end

  def batch_get_all_comments()
    @comment_db.values.map { |bytes|
      bytes.nil? ? nil : Comment::Comment.decode(bytes)
    }
  end

  def delete_comment(comment_id)
    @comment_db.delete(comment_id)
    save_db(@comment_file, @comment_db)
  end

  def put_metadata(metadata)
    @metadata_db[metadata.kifu_id] = Kifu::Metadata.encode metadata
    save_db(@metadata_file, @metadata_db)
  end

  def batch_get_metadata(ids)
    return [] if ids.empty?

    @metadata_db.values_at(*ids).map {|bytes|
      bytes.nil? ? nil : Kifu::Metadata.decode(bytes)
    }
  end

  private

  def load_db(file)
    begin
      Psych.load_file file
    rescue
      {}
    end
  end

  def save_db(file, db)
    IO.write(file, Psych.dump(db))
  end
end
