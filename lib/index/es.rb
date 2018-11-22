#!/usr/bin/env ruby

require 'elasticsearch'
require './proto/kifu_pb'
require './proto/index_pb'
require './lib/pb'

class EsIndex
  def initialize(opt)
    @client = Elasticsearch::Client.new log: opt[:log]
    @index = opt[:index]
  end

  def put(kifu, metadata = Kifu::Metadata.new)
    kifu_doc = Index::Document.new(
      kifu: Index::Kifu.new(
        id: kifu.id,
        first_players: kifu.first_players.map {|p| p.name},
        second_players: kifu.second_players.map {|p| p.name},
        start_ts: kifu.start_ts,
        end_ts: kifu.end_ts,
        board_ids: kifu.board_ids.to_a,
        alias: !kifu.alias.empty?,
        owner_id: metadata.owner_id,
      )
    )
    kifu_id = "KIFU:%s" % kifu_doc.kifu.id
    @client.index index: @index, type: "doc", id: kifu_id, body: kifu_doc.to_h

    kifu.steps.each do |step|
      step_id = Index::Step::StepId.new(
        kifu_id: kifu_doc.kifu.id,
        seq: step.seq,
        finished: step.finished,
      )
      id = "STEP:%s:%d:%s" % [step_id.kifu_id, step_id.seq, step_id.finished]
      step_doc = Index::Document.new(
        step: Index::Step.new(
          id: step_id,
          board_id: kifu.board_ids[step.seq],
          prev_board_id: kifu.board_ids[step.seq - 1],
          game_start_ts: kifu.start_ts,
        )
      )
      @client.index index: @index, type: "doc", id: id, body: step_doc.to_h
    end
  end

  def search_kifu(params = {})
    restrictions = [
      { exists: { field: "kifu" } },
      { match: { "kifu.alias": false } },
    ]
    restrictions << { match: { "kifu.owner_id": params[:owner] } } if !params[:owner].nil?

    query = {
      query: {
        bool: {
          must: restrictions,
        },
      },
      size: 100,
      sort: [
        { "kifu.start_ts": "asc" },
      ],
      _source: false,
    }
    res = @client.search index: @index, body: query
    ret = []
    res['hits']['hits'].each {|doc|
      label, kifu_id = doc['_id'].split(":")
      next if label != "KIFU"
      ret << kifu_id
    }
    ret
  end

  def search_step(board_id)
    query = {
      query: {
        match: { "step.board_id": board_id },
      },
      size: 100,
      sort: [
        { "step.game_start_ts": "asc" },
      ],
      _source: false,
    }

    res = @client.search index: @index, body: query

    ret = []
    res['hits']['hits'].map {|doc|
      label, kifu_id, seq, finished = doc['_id'].split(":")
      next if label != "STEP"
      ret << Index::Step::StepId.new(
        kifu_id: kifu_id,
        seq: seq.to_i,
        finished: finished == "true",
      )
    }
    ret
  end

  def put_account(account)
    id = "ACCOUNT:%s" % account.id
    account_doc = Index::Document.new(
      account: Index::Account.new(
        id: id,
        player_id: account.player_id,
      )
    )
    @client.index index: @index, type: "doc", id: id, body: account_doc.to_h
  end

  def search_accounts(player_ids)
    query = {
      query: {
        match: { "account.player_id": player_ids.join(" ") },
      },
      size: 100,
      _source: false,
    }
    res = @client.search index: @index, body: query
    ret = []
    res['hits']['hits'].map {|doc|
      label, id = doc['_id'].split(":")
      next if label != "ACCOUNT"
      ret << id
    }
    ret
  end

  def put_comment(comment, refresh = true)
    doc = Index::Document.new(
      comment: Index::Comment.new(
        id: comment.id,
        owner_id: comment.owner_id,
        created_ms: comment.created_ms,
        board_id: comment.board_id,
        kifu_id: comment.kifu_id,
      )
    )
    id = "COMMENT:%s" % comment.id
    @client.index index: @index, type: "doc", id: id, body: doc.to_h, refresh: refresh
  end

  def search_comment(params)
    mustQueries = []
    mustQueries << { match: { "comment.board_id": params[:board_id] } } unless params[:board_id].nil?
    mustQueries << { match: { "comment.kifu_id": params[:kifu_id] } } unless params[:kifu_id].nil?
    mustQueries << { match: { "comment.owner_id": params[:owner] } } unless params[:owner].nil?

    query = {
      bool: {
        must: mustQueries.empty? ? { exists: { field: "comment" } } : mustQueries,
      }
    }
    query[:bool][:must_not] = { match: { "comment.owner_id": params[:except_owner] } } unless params[:except_owner].nil?

    size = params.fetch(:size, 100)

    order = params.fetch(:order, "asc")

    body = {
      query: query,
      size: size,
      sort: [
        { "comment.created_ms": order },
      ],
      _source: false,
    }
    res = @client.search index: @index, body: body
    ret = []
    res['hits']['hits'].each {|doc|
      label, id = doc['_id'].split(":")
      next if label != "COMMENT"
      ret << id
    }
    ret
  end

  def delete_comment(comment_id)
    id = "COMMENT:%s" % comment_id
    @client.delete index: @index, type: "doc", id: id
  end
end
