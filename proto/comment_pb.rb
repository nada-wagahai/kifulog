# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: proto/comment.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "comment.Comment" do
    optional :id, :string, 1
    optional :owner_id, :string, 2
    optional :text, :string, 3
    optional :created_ms, :int64, 4
    optional :updated_ms, :int64, 5
    optional :board_id, :string, 6
    optional :kifu_id, :string, 7
    optional :seq, :int32, 8
  end
end

module Comment
  Comment = Google::Protobuf::DescriptorPool.generated_pool.lookup("comment.Comment").msgclass
end
