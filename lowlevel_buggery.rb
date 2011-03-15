# This file contains a thin wrapper around the win32 flavoured
# COM interfaces exposed by the various dbgeng engine objects.
# It's more rubyish than using RawBuggery methods directly.
#
# Note that I said THIN wrapper. If it doesn't have whatever
# debugger stuff that you need wrapped, then use #execute( 'cmd' )
# and parse the string result.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2011.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require File.dirname(__FILE__) + '/raw_buggery'
include RawBuggery

OpenProcess=Win32::API.new('OpenProcess','LIL')
DebugBreakProcess=Win32::API.new('DebugBreakProcess','L')
CloseHandle=Win32::API.new('CloseHandle', 'L', 'B')

PROCESS_ALL_ACCESS=0x1F0FFF

class Buggery
    # Two way lookup, errors defined in WinError.h
    ERRORS={
        'S_OK'=>0x0,
        'S_FALSE'=>0x01,
        'E_PENDING'=>0x8000000a,
        'E_FAIL'=>0x80000008,
        'E_UNEXPECTED'=>0x8000FFFF
    }
    ERRORS.update ERRORS.invert
    EVENTS={
        'DEBUG_EVENT_BREAKPOINT'=>0x00000001,
        'DEBUG_EVENT_EXCEPTION'=>0x00000002,
        'DEBUG_EVENT_CREATE_THREAD'=>0x00000004,
        'DEBUG_EVENT_EXIT_THREAD'=>0x00000008,
        'DEBUG_EVENT_CREATE_PROCESS'=>0x00000010,
        'DEBUG_EVENT_EXIT_PROCESS'=>0x00000020,
        'DEBUG_EVENT_LOAD_MODULE'=>0x00000040,
        'DEBUG_EVENT_UNLOAD_MODULE'=>0x00000080,
        'DEBUG_EVENT_SYSTEM_ERROR'=>0x00000100,
        'DEBUG_EVENT_SESSION_STATUS'=>0x00000200,
        'DEBUG_EVENT_CHANGE_DEBUGGEE_STATE'=>0x00000400,
        'DEBUG_EVENT_CHANGE_ENGINE_STATE'=>0x00000800,
        'DEBUG_EVENT_CHANGE_SYMBOL_STATE'=>0x00001000
    }
    EVENTS.update EVENTS.invert
    COMPONENT="Buggery"
    VERSION="0.1"


    def buf( n )
        0.chr * n
    end

    def ulong
        buf 4
    end

    def raise_winerror( retval, meth )
        if ERRORS[retval]
            raise "#{meth} returned #{ERRORS[retval]}"
        else
            # Error codes are in WinError.h, look em up yourself.
            raise "#{meth} returned unknown error code: #{"0x%.8x" % retval}"
        end
    end

    def debug_info( str )
        warn "#{COMPONENT}-#{VERSION}: #{str}" if @debug
    end


    def initialize( debug=false )
        @debug=debug
        @dc=DebugClient.new
        @output_callback=FakeCOM.new
        @output_buffer=""
        # This is the only method the IDebugOutputCallbacks object 
        # needs to implement, apart from the IUnknown stuff which
        # is built for us by FakeCOM
        @output_callback.add_function('PLP','L') {|p, mask, text| @output_buffer << text;0}
        @dc.SetOutputCallbacks( @output_callback.interface_ptr )
    end

    def get_output
        @dc.FlushCallbacks
        @output_buffer.clone
    end

    def clear_output
        @dc.FlushCallbacks
        @output_buffer.clear
    end

    # For raw access to the underlying RawBuggery object
    # so you can call lowlevel APIs directly.
    def raw
        @dc
    end

    # In String( debugger_command ), Optional, Boolean( echo_command? )
    # Out: String( command_output )
    # This command will also clear the output buffer BEFORE the command
    # executes, so if you care what was in it, get_output first. This 
    # is done to make sure you get only the output of your command.
    def execute( command_str, echo=false )
        clear_output
        @dc.DebugControl.Execute(
            DebugControl::DEBUG_OUTCTL_THIS_CLIENT,
            command_str,
            echo ? DebugControl::DEBUG_EXECUTE_ECHO : DebugControl::DEBUG_EXECUTE_NOT_LOGGED
        )
        res=get_output
        clear_output
        res
    end

    # In: String, Command line to execute
    # Out: true, or raise
    def create_process( command_str )
        debug_info "Creating process with commandline #{command_str}"
        # Set the filter for the initial breakpoint event to break in
        specific_filter_params=[
            DebugControl::DEBUG_FILTER_BREAK, # ExecutionOption
            0, # ContinueOption
            0, # TextSize
            0, # CommandSize
            0 # ArgumentSize
        ].pack('LLLLL')
        @dc.DebugControl.SetSpecificFilterParameters(
            DebugControl::DEBUG_FILTER_INITIAL_BREAKPOINT, # Start
            1, # Count
            specific_filter_params # params to set
        )

        # Create the process, catch the initial break, get the pid of the
        # new process.
        retval=@dc.CreateProcess(0,0,command_str,DebugClient::DEBUG_PROCESS_ONLY_THIS_PROCESS)
        debug_info "created, retval #{retval}"
        wait_for_event( -1 ) # Which will be the initial breakpoint
        pid=ulong
        @dc.DebugSystemObjects.GetCurrentProcessSystemId( pid )
        @pid=pid.unpack('L').first
        debug_info "Created, pid is #{@pid}"
        go

        return true if retval.zero? # S_OK
        raise_winerror( retval, __method__ )
    end

    # In: Hexstring( exception_record_address ) Default: -1 (last exception)
    # Out: Hash( record_key, record_val )
    # This just wraps '.exr'
    # There is a Description key which doesn't come from the engine, the value
    # is the last line of the record which is, amazingly, a short description.
    def exception_record( address=-1 )
        raw=execute ".exr #{address}"
        raw=raw.split("\n").map {|e| e.lstrip.split(': ')}
        raw.each {|ary| ary.unshift( "Description" ) if ary.size!=2}
        Hash[raw]
    end

    def go( status=DebugControl::DEBUG_STATUS_GO )
        # "The SetExecutionStatus method requests that the debug
        # engine enter an executable state. Actual execution will
        # not occur until the next time WaitForEvent is called."
        @dc.DebugControl.SetExecutionStatus( status )
    end

    def break
        # Note - this will generate a breakpoint exception event
        # You can't start executing commands until you handle
        # that event somehow (wait_for_event, or event callbacks)
        hProcess=OpenProcess.call(PROCESS_ALL_ACCESS, 0, @pid)
        retval=DebugBreakProcess.call( hProcess )
        raise RuntimeError, "#{__method__}: Failed to break in." if retval.zero?
    ensure
        CloseHandle.call( hProcess ) rescue false
    end

    # In: Timeout, -1 for infinite
    # Out: true, or raise. 
    def wait_for_event( timeout )
        retval=@dc.DebugControl.WaitForEvent(0, timeout)
        return true if retval.zero?
        return false if retval=ERRORS['S_FALSE']
        raise_winerror( retval, __method__ )
    end

    def lookup_event( event )
        EVENTS[event]
    end

    # In: Nothing
    # Out: Hash of String( reg_name )=>Integer( reg_value )
    # Note that there are a LOT of registers. Like 80ish.
    # al, ah, ax are all 'separate' registers. etc.
    def registers
        indices=(0...register_count).to_a.pack('L*')
        out_ary=buf(32 * register_count)
        retval=@dc.DebugRegisters.GetValues(register_count,indices,42,out_ary)
        if retval.zero?
            values=out_ary.unpack('Qx24'*register_count)
            Hash[*(register_descriptions.zip( values).flatten)]
        else
            raise_winerror( retval, __method__ )
        end
    end

    # In: Integer( address ), Integer( num_instructions )
    # Out: Array [ of [ Integer( address ), String( opcodes ), String( assembly ) ]
    def disassemble( addr, num_insns )
        addr64=[addr].pack('Q')
        addr_hi=addr64[0..3].unpack('L').first # These two combine to make
        addr_lo=addr64[4..7].unpack('L').first # a 64 bit address. Win32API doesn't have 'Q' prototypes.
        results=[]
        end_offset=buf(8)
        buf=buf(256)
        out_sz=ulong
        retval=@dc.DebugControl.Disassemble(addr_hi,addr_lo,0,buf,buf.size,out_sz,end_offset)
        raise_winerror( retval, __method__ ) unless retval.zero?
        old_end_offset=end_offset
        results << ( buf[0,out_sz.unpack('L').first-1].squeeze(' ').chomp.split(' ',3) )
        (num_insns - 1).times do
            end_offset=buf(8)
            buf=buf(256)
            out_sz=ulong
            @dc.DebugControl.Disassemble(
                old_end_offset[0..3].unpack('L')[0],
                old_end_offset[4..7].unpack('L')[0],
                0,
                buf,
                buf.size,
                out_sz,
                end_offset
            )
            raise_winerror( retval, __method__ ) unless retval.zero?
            old_end_offset=end_offset
            results << ( buf[0,out_sz.unpack('L').first-1].squeeze(' ').chomp.split(' ',3) )
        end
        results
    end

    def terminate_process
        @dc.TerminateProcesses
    end

    # In: Nothing
    # Out: [Integer( event_type ), String( event_desc ), String( extra_info_struct )]
    def get_last_event_information
        type=ulong
        pid=ulong
        tid=ulong
        extra_inf=buf(256)
        extra_inf_sz=ulong
        desc=buf(256)
        desc_sz=ulong
        retval=@dc.DebugControl.GetLastEventInformation(
            type,
            pid,
            tid,
            extra_inf,
            extra_inf.size, # size of our buffer
            extra_inf_sz, # filled in with size used
            desc,
            desc.size, # size of our buffer
            desc_sz # filled in with size used
        )
        if retval.zero?
            type=type.unpack('L').first
            desc=desc[0,desc_sz.unpack('L').first-1] # Remove null terminator
            extra_inf=extra_inf[0,extra_inf_sz.unpack('L').first]
            [type, desc, extra_inf]
        else
            raise_winerror( retval, __method__ )
        end
    end

    private

    def register_count
        unless @reg_count
            reg_count=ulong
            @dc.DebugRegisters.GetNumberRegisters( reg_count )
            @reg_count=reg_count.unpack('L').first
        end
        @reg_count
    end

    def register_descriptions
        unless @reg_descs
            @reg_descs=[]
            (0..register_count-1).each {|i|
                regname=buf(16)
                reg_desc=buf(28) # special struct
                name_sz=ulong
                @dc.DebugRegisters.GetDescription(i,regname,regname.size,name_sz,reg_desc)
                @reg_descs << regname[0,name_sz.unpack('L').first-1]
            }
        end
        @reg_descs
    end
end
