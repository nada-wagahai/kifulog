# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: proto/index.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "index.Document" do
    oneof :type do
      optional :kifu, :message, 1, "index.Kifu"
      optional :step, :message, 2, "index.Step"
      optional :account, :message, 3, "index.Account"
      optional :comment, :message, 4, "index.Comment"
    end
  end
  add_message "index.Kifu" do
    optional :id, :string, 1
    repeated :first_players, :string, 2
    repeated :second_players, :string, 3
    optional :start_ts, :int64, 4
    optional :end_ts, :int64, 5
    repeated :board_ids, :string, 6
    optional :alias, :bool, 7
    optional :owner_id, :string, 8
  end
  add_message "index.Step" do
    optional :id, :message, 1, "index.Step.StepId"
    optional :board_id, :string, 2
    optional :game_start_ts, :int64, 3
    optional :prev_board_id, :string, 4
  end
  add_message "index.Step.StepId" do
    optional :kifu_id, :string, 1
    optional :seq, :int32, 2
    optional :finished, :bool, 3
  end
  add_message "index.Account" do
    optional :id, :string, 1
    optional :player_id, :string, 2
  end
  add_message "index.Comment" do
    optional :id, :string, 1
    optional :owner_id, :string, 2
    optional :created_ms, :int64, 3
    optional :board_id, :string, 4
    optional :kifu_id, :string, 5
  end
end

module Index
  Document = Google::Protobuf::DescriptorPool.generated_pool.lookup("index.Document").msgclass
  Kifu = Google::Protobuf::DescriptorPool.generated_pool.lookup("index.Kifu").msgclass
  Step = Google::Protobuf::DescriptorPool.generated_pool.lookup("index.Step").msgclass
  Step::StepId = Google::Protobuf::DescriptorPool.generated_pool.lookup("index.Step.StepId").msgclass
  Account = Google::Protobuf::DescriptorPool.generated_pool.lookup("index.Account").msgclass
  Comment = Google::Protobuf::DescriptorPool.generated_pool.lookup("index.Comment").msgclass
end
