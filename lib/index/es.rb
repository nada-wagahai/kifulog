#!/usr/bin/env ruby

require 'elasticsearch'
require './proto/kifu_pb'
require './proto/index_pb'
require './lib/pb'

class EsIndex
  def initialize(opt)
    @kifu_index = opt[:kifu_index]
    @step_index = opt[:step_index]
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
        match_all: {},
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
        match: {boardId: board_id},
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
end
