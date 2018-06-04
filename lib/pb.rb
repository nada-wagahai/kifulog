Dir[__FILE__.sub(Regexp.compile(File.extname(__FILE__) + "$"), "/*.rb")].each do |file|
  require file
end
