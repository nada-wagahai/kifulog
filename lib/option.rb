require 'optparse'

class Option
  attr_accessor :port, :data_dir, :records_dir
  attr_accessor :kifu_index, :step_index, :es_log

  def initialize(args)
    opt = OptionParser.new

    registerServer(opt)
    registerFile(opt)
    registerIndex(opt)

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

  def registerIndex(opt)
    @kifu_index = "kifu_dev"
    opt.on('--kifu-index=INDEX', 'default: %s' % kifu_index) {|v|
      @kifu_index = v
    }

    @step_index = "step_dev"
    opt.on('--step-index=INDEX', 'default: %s' % step_index) {|v|
      @step_index = v
    }

    @es_log = false
    opt.on('--es-log', 'default: false') {
      @es_log = true
    }
  end
end
