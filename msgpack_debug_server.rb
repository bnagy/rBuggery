# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2011.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'trollop'
require 'msgpack/rpc'
require File.dirname(__FILE__) + '/lowlevel_buggery'

OPTS=Trollop::options do
    opt :port, "Port to listen on, default 8888", :type=>:integer, :default=>8888
    opt :debug, "Debug output", :type=>:boolean
end

@bugger=Buggery.new(OPTS[:debug])
server = MessagePack::RPC::Server.new
server.listen('0.0.0.0', OPTS[:port], @bugger)
server.run

