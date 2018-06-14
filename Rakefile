# coding: utf-8

require 'open3'

PROTO_DIR = "./proto"
PROTO_OUT_DIR = "."

task :proto do
  Dir["#{PROTO_DIR}/*.proto"].each do |file|
    cmd = ["protoc", "--ruby_out=#{PROTO_OUT_DIR}", file]
    puts "proto: " + cmd.join(" ")
    out,status = Open3.capture2(*cmd)
    puts "proto: " + out
    exit status.to_i if !status.success?
  end
end
