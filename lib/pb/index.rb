require 'base64'
require './proto/index_pb'

class Index::Step::StepId
  def encode_base64
    bytes = self.class.encode self
    Base64.encode64 bytes
  end

  def self.decode_base64(str)
    bytes = Base64.decode64 str
    decode bytes
  end
end
