require 'optparse'

class Option
  attr_accessor :port, :data_dir, :records_dir

  def initialize(args)
    opt = OptionParser.new

    registerServer(opt)
    registerFile(opt)

    opt.parse!(args)
  end

  def registerServer(opt)
    @port = 31011
    opt.on('--port=PORT', 'default: %d' % port) {|v|
      @port = v.to_i
    }
  end

  def registerFile(opt)
    @data_dir = "./data"
    opt.on('--data-dir=DIR', 'default: %s' % data_dir) {|v|
      @data_dir = v
    }

    @records_dir = "records"
    opt.on('--records-dir=DIR', 'default: {data-dir}/%s' % records_dir) {|v|
      @records_dir = v
    }
  end
end
