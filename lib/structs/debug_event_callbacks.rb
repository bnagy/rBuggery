# A class to be a fake IDebugEventCallbacks COM object, based on the
# FakeCOM class. Exposes #add for Rubyness.
# eg:
# @cbh=CallbackHandler.new
# @cbh.add(:breakpoint) {|args|
#
#   bp = DebugBreakpoint.new args[:breakpoint]
#   params = DebugBreakpointParameters.new
#   bp.GetParameters params
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2014.
# License: BSD Style, see LICENSE file for details

require 'ffi'
require 'buggery/fake_com'
require 'win32/wintypes'

module Buggery

  module Structs

    class DebugEventCallbacks < FakeCOM

      include Win32::WinTypes

      MASKS={
        :breakpoint            => 0x00000001,
        :change_debuggee_state => 0x00000400,
        :change_engine_state   => 0x00000800,
        :exception             => 0x00000002,
        :load_module           => 0x00000040,
        :unload_module         => 0x00000080,
        :create_process        => 0x00000010,
        :exit_process          => 0x00000020,
        :session_status        => 0x00000200,
        :change_symbol_state   => 0x00001000,
        :system_error          => 0x00000100,
        :create_thread         => 0x00000004,
        :exit_thread           => 0x00000008
      }

      DEBUG_STATUS_NO_CHANGE         = 0
      DEBUG_STATUS_GO                = 1
      DEBUG_STATUS_GO_HANDLED        = 2
      DEBUG_STATUS_GO_NOT_HANDLED    = 3
      DEBUG_STATUS_STEP_OVER         = 4
      DEBUG_STATUS_STEP_INTO         = 5
      DEBUG_STATUS_BREAK             = 6
      DEBUG_STATUS_NO_DEBUGGEE       = 7
      DEBUG_STATUS_STEP_BRANCH       = 8
      DEBUG_STATUS_IGNORE_EVENT      = 9
      DEBUG_STATUS_RESTART_REQUESTED = 10

      def initialize( debugger )

        super() # Build IUnknown methods
        @debugger=debugger

        # Interest mask flags are from the DEBUG_EVENT_XXX constants in
        # dbgeng.h, copied above.
        @interest_mask=0x00000000

        # This callback table will be populated with user callbacks as they are
        # added with the #add method below, but install a placeholder in case
        # stuff gets called when it shouldn't.
        @placeholder=Proc.new {|*args|
          raise "EventCallbacks: Callback called by system without user function defined"
          DEBUG_STATUS_BREAK
        }

        @callback_table=Hash.new {|h,k| h[k]=@placeholder}

        # Implement GetInterestMask...
        #    // The engine calls GetInterestMask once when
        #    // the event callbacks are set for a client.
        #    STDMETHOD(GetInterestMask)(
        #        THIS_
        #        __out PULONG Mask
        #        ) PURE;
        @vtable << FFI::Function.new( HRESULT, [THIS_, PULONG] ) {|this,mask|
          mask.write_ulong @interest_mask
          0 # S_OK
        }

        # Callback prototypes:
        #
        # Breakpoint(THIS_ In_(Bp))
        # Exception(THIS_ In_(Exception) In_(FirstChance))
        # CreateThread(THIS_ In_(Handle) In_(DataOffset) In_(StartOffset))
        # ExitThread(THIS_ In_(ExitCode))
        # CreateProcess(THIS_ In_(ImageFileHandle) In_(Handle) In_(BaseOffset) In_(ModuleSize) In_opt_(ModuleName) In_opt_(ImageName) In_(CheckSum) In_(TimeDateStamp) In_(InitialThreadHandle) In_(ThreadDataOffset) In_(StartOffset))
        # ExitProcess(THIS_ In_(ExitCode))
        # LoadModule(THIS_ In_(ImageFileHandle) In_(BaseOffset) In_(ModuleSize) In_opt_(ModuleName) In_opt_(ImageName) In_(CheckSum) In_(TimeDateStamp))
        # UnloadModule(THIS_ In_opt_(ImageBaseName) In_(BaseOffset))
        # SystemError(THIS_ In_(Error) In_(Level))
        # SessionStatus(THIS_ In_(Status))
        # ChangeDebuggeeState(THIS_ In_(Flags) In_(Argument))
        # ChangeEngineState(THIS_ In_(Flags) In_(Argument))
        # ChangeSymbolState(THIS_ In_(Flags) In_(Argument))

        # Add the real callbacks, in order.
        add_com_callback(
          :breakpoint,
          :this       => THIS_,
          :breakpoint => PDEBUG_BREAKPOINT
        )
        add_com_callback(
          :exception,
          :this             => THIS_,
          :exception_record => P_EXCEPTION_RECORD64,
          :first_chance     => ULONG
        )
        add_com_callback(
          :create_thread,
          :handle       => ULONG64,
          :data_offset  => ULONG64,
          :start_offset => ULONG64
        )
        add_com_callback(
          :exit_thread,
          :this      => THIS_,
          :exit_code => ULONG
        )
        add_com_callback(
          :create_process,
          :this                  => THIS_,
          :image_file_handle     => ULONG64,
          :handle                => ULONG64,
          :base_offset           => ULONG64,
          :module_size           => ULONG,
          :module_name           => PCSTR,
          :image_name            => PCSTR,
          :checksum              => ULONG,
          :timestamp             => ULONG,
          :initial_thread_handle => ULONG64,
          :thread_data_offset    => ULONG64,
          :start_offset          => ULONG64
        )
        add_com_callback(
          :exit_process,
          :this      => THIS_,
          :exit_code => ULONG
        )
        add_com_callback(
          :load_module,
          :this        => THIS_,
          :file_handle => ULONG64,
          :base_offset => ULONG64,
          :module_size => ULONG,
          :module_name => PCSTR,
          :image_name  => PCSTR,
          :checksum    => ULONG,
          :timestamp   => ULONG
        )
        add_com_callback(
          :unload_module,
          :this        => THIS_,
          :base_offset => ULONG64
        )
        add_com_callback(
          :system_error,
          :this  => THIS_,
          :error => ULONG,
          :level => ULONG
        )
        add_com_callback(
          :session_status,
          :this   => THIS_,
          :status => ULONG
        )
        add_com_callback(
          :change_debuggee_state,
          :this     => THIS_,
          :flags    => ULONG,
          :argument => ULONG64
        )
        add_com_callback(
          :change_engine_state,
          :this     => THIS_,
          :flags    => ULONG,
          :argument => ULONG64
        )
        add_com_callback(
          :change_symbol_state,
          :this     => THIS_,
          :flags    => ULONG,
          :argument => ULONG64
        )

      end

      def add( cb_hsh )
        # This actually only changes the corresponding callbacks (Ruby level
        # Proc) in the callback table, and updates the interest mask. The real
        # callback (FFI Function) was already added in initialize.
        # INTERFACE CHANGE: All callbacks need to be added with one call to #add
        cb_hsh.each {|cb_name, new_blk|

          unless MASKS[cb_name]
            raise ArgumentError, "#{self.class}:#{__method__}: Invalid callback: #{cb_name}"
          end

          @interest_mask |= MASKS[cb_name]
          @callback_table[cb_name]=new_blk
        }

        @debugger.SetEventCallbacks interface_ptr

      end

      def remove( cb_name, &blk )

        # Can't modify callbacks once the object is set up, at the moment.
        raise NotImplementedError

        # unless MASKS[cb_name]
        #   raise ArgumentError, "#{self.class}:#{__method__}: Invalid callback: #{cb_name}"
        # end
        # @interest_mask ^= MASKS[cb_name]
        # @callback_table[cb_name]=@placeholder
        # @debugger.SetEventCallbacks( interface_ptr )

      end

      private

      def add_com_callback( name, prototype )

        # Add an FFI function to the vtable that will invoke a user-supplied
        # Proc in @callback_table. The FFI function will call the user callback
        # with a hash, keys from the prototype and the values cast by FFI.
        # Finally, the FFI function checks to make sure the user callback
        # returns a valid DEBUG_STATUS_XXX value

        func=FFI::Function.new( :int, prototype.values ) {|p, *args|

          prototype.delete :this
          # Call the user's callback
          retval = @callback_table[name].call( Hash[prototype.keys.zip(args)] )

          if (0..10).include? retval
            # user callback returned an int in the DEBUG_STATUS_XXX range,
            # so we assume they know what they're doing. Good User.
            retval
          else
            # Bad User. No biscuit.
            raise RuntimeError, "#{self.class}:#{__method__}: Invalid return from user callback: #{retval}"
          end

        }

        # Add the FFI::Function we just created to the vtable
        @vtable << func

      end
    end
  end
end
