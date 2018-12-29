# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: proto/api.proto

require 'google/protobuf'

require 'proto/kifu_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "api.Step" do
    optional :kifu_id, :string, 1
    optional :seq, :int32, 2
    optional :finished, :bool, 3
    optional :start_ts, :int64, 4
    repeated :players, :message, 5, "kifu.Player"
  end
  add_message "api.Comment" do
    optional :id, :string, 1
    optional :name, :string, 2
    optional :text, :string, 3
    optional :owned, :bool, 4
  end
  add_message "api.BoardResponse" do
    optional :board, :message, 1, "kifu.Board"
    repeated :comments, :message, 2, "api.Comment"
    repeated :steps, :message, 3, "api.Step"
  end
  add_message "api.IndexResponse" do
    repeated :entries, :message, 1, "api.IndexResponse.Entry"
    repeated :recent_comments, :message, 2, "api.Comment"
  end
  add_message "api.IndexResponse.Entry" do
    optional :id, :string, 1
    optional :kifu, :message, 2, "kifu.Kifu"
  end
end

module Api
  Step = Google::Protobuf::DescriptorPool.generated_pool.lookup("api.Step").msgclass
  Comment = Google::Protobuf::DescriptorPool.generated_pool.lookup("api.Comment").msgclass
  BoardResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("api.BoardResponse").msgclass
  IndexResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("api.IndexResponse").msgclass
  IndexResponse::Entry = Google::Protobuf::DescriptorPool.generated_pool.lookup("api.IndexResponse.Entry").msgclass
end
