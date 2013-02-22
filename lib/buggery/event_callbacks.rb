# A class to be a fake IDebugEventCallbacks COM object, based on the
# FakeCOM class. Exposes #add and #remove for Rubyness.
# eg:
# @cbh=CallbackHandler.new
# @cbh.add(:breakpoint) {|args|
#   # handle IDebugBreakpoint object somehow
#   bp_pointer=args[:breakpoint]
# }
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'ffi'
require 'buggery/fake_com'

class EventCallbacks < FakeCOM
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
    @vtable << FFI::Function.new( :int, [:pointer, :pointer] ) {|this,mask|
      mask.write_ulong @interest_mask
      0 # S_OK
    }
    # Add the real callbacks, in order.
    add_com_callback(
      :breakpoint,
      :this => :pointer,
      :breakpoint => :pointer
    )
    add_com_callback(
      :exception,
      :this => :pointer,
      :exception_record => :pointer,
      :first_chance => :ulong
    )
    add_com_callback(
      :create_thread,
      :handle => :uint64,
      :data_offset => :uint64,
      :start_offset => :uint64
    )
    add_com_callback(
      :exit_thread,
      :this => :pointer,
      :exit_code => :ulong
    )
    add_com_callback(
      :create_process,
      :this => :pointer,
      :image_file_handle => :uint64,
      :handle => :uint64,
      :base_offset => :uint64,
      :module_size => :ulong,
      :module_name => :string,
      :image_name => :string,
      :checksum => :ulong,
      :timestamp => :ulong,
      :initial_thread_handle => :uint64,
      :thread_data_offset => :uint64,
      :start_offset => :uint64
    )
    add_com_callback(
      :exit_process,
      :this => :pointer,
      :exit_code => :ulong
    )
    add_com_callback(
      :load_module,
      :this => :pointer,
      :file_handle => :uint64,
      :base_offset => :uint64,
      :module_size => :ulong,
      :module_name => :string,
      :image_name => :string,
      :checksum => :ulong,
      :timestamp => :ulong
    )
    add_com_callback(
      :unload_module,
      :this => :pointer,
      :base_offset => :uint64
    )
    add_com_callback(
      :system_error,
      :this => :pointer,
      :error => :ulong,
      :level => :ulong
    )
    add_com_callback(
      :session_status,
      :this => :pointer,
      :status => :ulong
    )
    add_com_callback(
      :change_debuggee_state,
      :this => :pointer,
      :flags => :ulong,
      :argument => :uint64
    )
    add_com_callback(
      :change_engine_state,
      :this => :pointer,
      :flags => :ulong,
      :argument => :uint64
    )
    add_com_callback(
      :change_symbol_state,
      :this => :pointer,
      :flags => :ulong,
      :argument => :uint64
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
    unless MASKS[cb_name]
      raise ArgumentError, "#{self.class}:#{__method__}: Invalid callback: #{cb_name}"
    end
    @interest_mask ^= MASKS[cb_name]
    @callback_table[cb_name]=@placeholder
    @debugger.SetEventCallbacks( interface_ptr )
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
      retval=@callback_table[name].call( Hash[prototype.keys.zip(args)] )
      if (0..10)===retval
        # user callback returned an int in the DEBUG_STATUS_XXX range,
        # so we assume they know what they're doing. Good User.
        retval
      else
        # Bad User. No biscuit.
        raise RuntimeError, "#{self.class}:#{__method__}: Invalid return from user callback: #{retval}"
      end
    }
    @vtable << func
  end
end
