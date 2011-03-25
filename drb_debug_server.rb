# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2011.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'trollop'
require 'drb'
require File.dirname(__FILE__) + '/lowlevel_buggery'

OPTS=Trollop::options do
    opt :port, "Port to listen on, default 8889", :type=>:integer, :default=>8889
    opt :debug, "Debug output", :type=>:boolean
end

DRb.start_service( "druby://:#{OPTS[:port]}", Buggery.new(OPTS[:debug]) )
puts "Server running at #{DRb.uri}"
DRb.thread.join
