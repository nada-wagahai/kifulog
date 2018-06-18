#!/usr/bin/env ruby

require 'elasticsearch'
require './proto/kifu_pb'
require './proto/index_pb'
require './lib/pb'

class EsIndex
  def initialize(opt)
    @kifu_index = opt[:kifu_index]
    @step_index = opt[:step_index]
    @account_index = opt[:account_index]
    @comment_index = opt[:comment_index]
    @client = Elasticsearch::Client.new log: opt[:log]
  end

  def put(kifu)
    kifu_doc = kifu.to_index
    @client.index index: @kifu_index, type: "kifu", id: kifu_doc.id, body: kifu_doc.to_json

    kifu.steps.each do |step|
      step_doc = Index::Step.new(
        id: Index::Step::StepId.new(
          kifu_id: kifu_doc.id,
          seq: step.seq,
          finished: step.finished,
        ),
        board_id: kifu.board_ids[step.seq],
        game_start_ts: kifu.start_ts,
      )
      @client.index index: @step_index, type: "step", id: step_doc.id.encode_base64, body: step_doc.to_json
    end
  end

  def search_kifu()
    query = {
      query: {
        bool: {
          must_not: {
            exists: { field: "alias" },
          },
        },
      },
      size: 100,
      sort: [
        { startTs: "asc" },
      ],
    }
    res = @client.search index: @kifu_index, body: query
    res['hits']['hits'].map {|doc| doc['_id']}
  end

  def search_step(board_id)
    query = {
      query: {
        match: { boardId: board_id },
      },
      size: 100,
      sort: [
        { gameStartTs: "asc" },
      ],
    }
    res = @client.search index: @step_index, body: query
    res['hits']['hits'].map {|doc|
      Index::Step::StepId.decode_base64 doc['_id']
    }
  end

  def put_account(account)
    account_doc = Index::Account.new(
      id: account.id,
      player_id: account.player_id,
    )
    @client.index index: @account_index, type: "account", id: account.id, body: account_doc.to_json
  end

  def search_accounts(player_ids)
    query = {
      query: {
        match: { playerId: player_ids.join(" ") },
      },
      size: 100,
    }
    res = @client.search index: @account_index, body: query
    res['hits']['hits'].map {|doc| doc['_id'] }
  end

  def put_comment(comment)
    doc = Index::Comment.new(
      id: comment.id,
      owner_id: comment.owner_id,
      created_ms: comment.created_ms,
      board_id: comment.board_id,
      kifu_id: comment.kifu_id,
    )
    @client.index index: @comment_index, type: "comment", id: doc.id, body: doc.to_json
  end

  def search_comment(params)
    return [] unless @client.indices.exists index: @comment_index

    query = {
      query: {
        match: { boardId: params[:board_id] },
      },
      size: 100,
      sort: [
        { createdMs: "asc" },
      ],
    }
    res = @client.search index: @comment_index, body: query
    res['hits']['hits'].map {|doc| doc['_id'] }
  end
end
