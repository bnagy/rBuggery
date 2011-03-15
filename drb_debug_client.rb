# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'drb'

class DebugClient

    attr_reader :target_pid, :debugger_pid

    def initialize( addr, port )
        @debug_server=DRbObject.new nil, "druby://#{addr}:#{port}"
    end

    def start_debugger( *args )
        # Return the URI
        @debugger_pid, @target_pid, uri=@debug_server.start_debugger( *args )
        uri
    end

    def close_debugger
        @debug_server.close_debugger
    end

    def destroy_server
        @debug_server.destroy
    end

end
