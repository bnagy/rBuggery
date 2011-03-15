# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2011.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'msgpack/rpc'

class Debugger < BasicObject

    def initialize( addr, port )
        @debug_client=::MessagePack::RPC::Client.new( addr, port )
    end

    def get_output
        @debug_client.call( :get_output )
    end

    def clear_output
        @debug_client.call( :clear_output )
    end

    # In String( debugger_command ), Optional, Boolean( echo_command? )
    # Out: String( command_output )
    # This command will also clear the output buffer BEFORE the command
    # executes, so if you care what was in it, get_output first. This 
    # is done to make sure you get only the output of your command.
    def execute( command_str, echo=false )
        @debug_client.call( :execute, command_str, echo )
    end

    # In: String, Command line to execute
    # Out: true, or raise
    def create_process( *args )
        @debug_client.call( :create_process, *args )
    end

    # In: Hexstring( exception_record_address ) Default: -1 (last exception)
    # Out: Hash( record_key, record_val )
    # This just wraps '.exr'
    # There is a Description key which doesn't come from the engine, the value
    # is the last line of the record which is, amazingly, a short description.
    def exception_record( address=-1 )
        @debug_client.call( :exception_record, address )
    end

    def go( status=1 ) # DEBUG_STATUS_GO
        @debug_client.call( :go, status )
    end

    def break
        @debug_client.call( :break )
    end

    # In: Timeout, -1 for infinite
    # Out: true, or raise. 
    def wait_for_event( *args )
        @debug_client.call( :wait_for_event, *args )
    end

    def lookup_event( *args )
        @debug_client.call( :lookup_event, *args )
    end

    # In: Nothing
    # Out: Hash of String( reg_name )=>Integer( reg_value )
    # Note that there are a LOT of registers. Like 80ish.
    # al, ah, ax are all 'separate' registers. etc.
    def registers
        @debug_client.call( :registers )
    end

    # In: Integer( address ), Integer( num_instructions )
    # Out: Array [ of [ Integer( address ), String( opcodes ), String( assembly ) ]
    def disassemble( *args )
        @debug_client.call( :disassemble, *args )
    end

    def terminate_process
        @debug_client.call( :terminate_process )
    end

    # In: Nothing
    # Out: [Integer( event_type ), String( event_desc ), String( extra_info_struct )]
    def get_last_event_information
        @debug_client.call( :get_last_event_information )
    end

end
