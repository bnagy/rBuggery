# This file contains a thin wrapper around the win32 flavoured COM interfaces
# exposed by the various dbgeng engine objects.  It's more rubyish than using
# RawBuggery methods directly.
#
# Note that I said THIN wrapper. If it doesn't have whatever debugger stuff
# that you need wrapped, then use #execute( 'cmd' ) and parse the string
# result.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2011.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require File.dirname(__FILE__) + '/lib/raw_buggery'
require File.dirname(__FILE__) + '/lib/fake_com'
require File.dirname(__FILE__) + '/lib/event_callbacks'
require File.dirname(__FILE__) + '/lib/breakpoint'
require File.dirname(__FILE__) + '/lib/exception'
require File.dirname(__FILE__) + '/lib/debug_value'
require File.dirname(__FILE__) + '/lib/winerror'
require 'ffi'
include RawBuggery
include FFI

module Kernel32
    extend FFI::Library
    ffi_lib "kernel32"
    ffi_convention :stdcall

    PROCESS_ALL_ACCESS=0x1F0FFF

    attach_function :OpenProcess, [:ulong, :int, :ulong], :ulong
    attach_function :DebugBreakProcess, [:ulong], :ulong
    attach_function :CloseHandle, [:ulong], :bool
end


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
    VERSION="0.3"

    def initialize( debug=false )
        @debug=debug
        @debug_client=DebugClient.new
        @output_callback=FakeCOM.new
        @output_buffer=""
        # This is the Output method, which is the only method the
        # IDebugOutputCallbacks object needs to implement, apart from the
        # IUnknown stuff which is built for us by FakeCOM
        @output_callback.add_function(:ulong, [:pointer, :ulong, :string]) {|p, mask, text| 
            @output_buffer << text
            0
        }
        retval=@debug_client.SetOutputCallbacks( ptr=@output_callback.interface_ptr )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        if @debug
            mask=DebugClient::DEBUG_OUTPUT_NORMAL | 
                DebugClient::DEBUG_OUTPUT_WARNING | 
                DebugClient::DEBUG_OUTPUT_ERROR |
                DebugClient::DEBUG_OUTPUT_VERBOSE
            retval=@debug_client.SetOutputMask mask
        else
            # Only 'normal' output - no prompts, register dump after every command,
            # warnings etc.
            retval=@debug_client.SetOutputMask DebugClient::DEBUG_OUTPUT_NORMAL
        end
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        @callback_handler=EventCallbacks.new( @debug_client )
    end

    # DOES NOT WORK DISTRIBUTED because when you want to add a callback,
    # Proc will not Marshal.
    def event_callbacks
        @callback_handler
    end

    def get_output
        @debug_client.FlushCallbacks
        @output_buffer.clone
    end

    def clear_output
        @debug_client.FlushCallbacks
        @output_buffer.clear
    end

    # For raw access to the underlying RawBuggery object so you can call
    # lowlevel APIs directly.  DOES NOT WORK DISTRIBUTED since most of the Raw
    # methods rely on modifying the target of a pointer.
    def raw
        @debug_client
    end

    # In String( debugger_command ), Optional, Boolean( echo_command? )
    # Out: String( command_output )
    # This command will also clear the output buffer BEFORE the command
    # executes, so if you care what was in it, get_output first. This 
    # is done to make sure you get only the output of your command.
    def execute( command_str, echo=false )
        clear_output
        retval=@debug_client.DebugControl.Execute(
            DebugControl::DEBUG_OUTCTL_THIS_CLIENT,
            command_str,
            echo ? DebugControl::DEBUG_EXECUTE_ECHO : DebugControl::DEBUG_EXECUTE_NOT_LOGGED
        )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        res=get_output
        clear_output
        res
    end

    # In: Nothing
    # Out: Integer( target_pid )
    def current_process
        retval=@debug_client.DebugSystemObjects.GetCurrentProcessSystemId( pid=p_int )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        pid.read_int
    end

    # In: String, Command line to execute
    # Out: true, or raise
    def create_process( command_str, debug_children=false, create_broken=false )
        @debug_client.TerminateProcesses # one at a time...
        debug_info "Creating process with commandline #{command_str}"
        # Set the filter for the initial breakpoint event to break in
        @specific_filter_params||=MemoryPointer.from_string([
             DebugControl::DEBUG_FILTER_BREAK, # ExecutionOption
             0, # ContinueOption
             0, # TextSize (unused)
             0, # CommandSize (unused)
             0 # ArgumentSize (unused)
        ].pack('LLLLL'))
        @debug_client.DebugControl.SetSpecificFilterParameters(
            DebugControl::DEBUG_FILTER_INITIAL_BREAKPOINT, # Start
            1, # Count
            @specific_filter_params # params to set
        )
        # Create the process, catch the initial break, get the pid of the
        # new process.
        if debug_children
            create_flags=DebugClient::DEBUG_PROCESS
        else
            create_flags=DebugClient::DEBUG_PROCESS_ONLY_THIS_PROCESS
        end
        retval=@debug_client.CreateProcess(
            0,
            command_str,
            create_flags
        )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        wait_for_event( -1 ) # Which will be the initial breakpoint
        @pid=current_process
        debug_info "Created, pid is #{@pid}"
        go unless create_broken
        true
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

    # In: Nothing
    # Out: true or raise
    # From the docs: "The SetExecutionStatus method requests that the debug
    # engine enter an executable state. Actual execution will not occur until
    # the next time WaitForEvent is called."
    def go( status=DebugControl::DEBUG_STATUS_GO )
        retval=@debug_client.DebugControl.SetExecutionStatus status 
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        true
    end

    # In: Nothing
    # Out: true or raise
    # Note - this just generates a breakpoint exception event You can't start
    # executing commands until you handle that event somehow (wait_for_event,
    # or event callbacks)
    def break
        hProcess=Kernel32.OpenProcess Kernel32::PROCESS_ALL_ACCESS, 0, @pid
        raise_win32_error( __method__ ) if hProcess.zero? # NULL handle
        retval=Kernel32.DebugBreakProcess hProcess 
        raise_win32_error( __method__ ) if retval.zero? # 0 is bad, in this case
        true
    ensure
        Kernel32.CloseHandle( hProcess ) unless hProcess.zero?
    end

    # In: Timeout, -1 for infinite
    # Out: true (there's an event), false (timeout expired), or raise. 
    def wait_for_event( timeout=-1 )
        retval=@debug_client.DebugControl.WaitForEvent(0, timeout)
        return true if retval.zero?
        return false if retval=ERRORS['S_FALSE']
        raise_errorcode( retval, __method__ )
    end

    def lookup_event( event )
        EVENTS[event]
    end

    # In: Nothing
    # Out: Hash of String( reg_name )=>Integer||Array( reg_value )
    # Note that there are a LOT of 'registers'. Like 80ish.  al, ah, ax are all
    # 'separate' registers. etc. Contents of the floating point and vector
    # registers will be returned as Arrays. Floating points are returned as
    # uint8 arrays, vectors are returned as arrays of uint32 (go down to the raw
    # API if you really need to change that).
    def registers
        @indices||=(0...register_count).to_a.pack('L*')
        # Keep hold of this memory buffer - makes this method MUCH faster, but
        # it's an ugly pattern so it's not used everywhere.
        @register_buffer||=MemoryPointer.new DEBUG_VALUE, register_count 
        retval=@debug_client.DebugRegisters.GetValues( register_count, @indices, 42, @register_buffer )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        values=register_count.times.map {|idx|
            DEBUG_VALUE.new( @register_buffer + idx * DEBUG_VALUE.size ).get_value
        }
        Hash[register_descriptions.zip( values)]
    end

    # In: Integer( pid ), Integer( option_mask )
    # Out: Nothing
    # option_mask uses the DEBUG_ATTACH_XXX constants.
    # After attaching, you still need to wait for an event! You probably want
    # to #break first but it depends on the option_mask you're using.
    def attach( pid, option_mask=DebugClient::DEBUG_ATTACH_DEFAULT)
        retval=@debug_client.AttachProcess( 0, Integer( pid ), Integer( option_mask ) )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        @pid=pid
        true
    end

    # In: Integer( address ), Integer( num_instructions )
    # Out: Array [ of [ Integer( address ), String( opcodes ), String( assembly ) ]
    def disassemble( addr, num_insns )
        buf=p_char(256)
        out_sz=p_ulong
        end_offset=p_ulong64
        retval=@debug_client.DebugControl.Disassemble(addr,0,buf,buf.size,out_sz,end_offset)
        raise_errorcode( retval, __method__ ) unless retval.zero?
        old_end_offset=end_offset.read_uint64
        results=[]
        results << ( buf.read_string[0,out_sz.read_ulong].squeeze(' ').chomp.split(' ',3) )
        (num_insns - 1).times do
            end_offset=p_ulong64
            buf=p_char(256)
            out_sz=p_ulong
            @debug_client.DebugControl.Disassemble(
                old_end_offset,
                0,
                buf,
                buf.size,
                out_sz,
                end_offset
            )
            raise_errorcode( retval, __method__ ) unless retval.zero?
            old_end_offset=end_offset.read_uint64
            results << ( buf.read_string[0,out_sz.read_ulong].squeeze(' ').chomp.split(' ',3) )
        end
        results
    end

    # In: Nothing
    # Out: true or raise 
    # From the docs: " The TerminateProcesses method attempts to terminate all
    # processes in all targets. Only live user-mode processes are terminated by
    # this method. For other targets, the target is detached from the debugger
    # without terminating. "
    def terminate_process
        retval=@debug_client.TerminateProcesses
        raise_errorcode( retval, __method__ ) unless retval.zero?
        true
    end

    # In: Nothing
    # Out: [ Integer( event_type ), String( event_desc ), FFI::MemoryPointer->extra_info_struct ]
    # ( the MemoryPointer points to a chunk of bytes of the correct size for
    # the extra_info_struct )
    def get_last_event_information
        type=p_ulong
        pid=p_ulong
        tid=p_ulong
        extra_inf=p_char(256)
        extra_inf_sz=p_ulong
        desc=p_char(256)
        desc_sz=p_ulong
        retval=@debug_client.DebugControl.GetLastEventInformation(
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
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        # extra_inf is some kind of event dependent struct, but I can't find
        # any docs on what struct is used for which events. Give the user a
        # pointer, let them sort it out.
        extra_inf_ptr=p_char extra_inf_sz.read_ulong
        extra_inf_ptr.write_bytes extra_inf.read_bytes(extra_inf_sz.read_ulong)
        [type.read_ulong, desc.read_string, extra_inf_ptr]
    end

    def get_exit_code
        retval=@debug_client.GetExitCode( exit_code=p_ulong )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        exit_code.read_ulong
    end

    # In: Nothing
    # Out: true or false
    def target_running?
        # 1==GO, 2==GO_HANDLED, 3==GO_NOT_HANDLED
        # Don't know if the steps and such should be called running...
        retval=@debug_client.DebugControl.GetExecutionStatus( status=p_ulong )
        raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
        (1..3).include? status.read_ulong
    end

    def destroy
        terminate_process
        DRb.thread.exit rescue exit
    end

    private

    def raise_errorcode( retval, meth )
        if ERRORS[retval]
            raise "#{meth} returned #{ERRORS[retval]}"
        else
            # Error codes are in WinError.h, look em up yourself.
            raise "#{meth} returned unknown error code: #{"0x%.8x" % retval}"
        end
    end

    def raise_win32_error( meth )
        raise "#{COMPONENT}-#{VERSION}:#{meth}: Win32 Error: #{WinError.get_last_error}"
    end

    def debug_info( str )
        warn "#{COMPONENT}-#{VERSION}: #{str}" if @debug
    end

    def p_char( n )
        MemoryPointer.new :char, n
    end

    def p_ulong
        MemoryPointer.new :ulong 
    end

    def p_int
        MemoryPointer.new :int 
    end

    def p_ulong64
        MemoryPointer.new :uint64
    end

    def register_count
        unless @reg_count
            retval=@debug_client.DebugRegisters.GetNumberRegisters( reg_count=p_ulong )
            raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
            @reg_count=reg_count.read_ulong
        end
        @reg_count
    end

    def register_descriptions
        unless @reg_descs
            @reg_descs=[]
            (0..register_count-1).each {|i|
                regname=p_char(16)
                reg_desc=p_char(28) # some special struct; don't care.
                name_sz=p_ulong
                retval=@debug_client.DebugRegisters.GetDescription(i,regname,regname.size,name_sz,reg_desc)
                raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
                @reg_descs << regname.read_string
            }
        end
        @reg_descs
    end

end
