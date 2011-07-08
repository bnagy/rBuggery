# How to build COM Objects in Ruby when there is no equivalent to Python
# comtypes, and you're too lazy to write C? FakeCOM!
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2011.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)
#
# THANKS: Daniel Berger and especially Park Heesob, for the initial code behind
# FakeCOM, which has now been converted to use FFI.

require 'ffi'

class FakeCOM
    # This class builds a fake COM object, which can be
    # used to implement IDebugOutputCallbacks, EventCallbacks etc.
    # Since we don't have any pretty wrapper around Win32 COM, and
    # it would suck to write a DLL which would have to be registered,
    # we cheat and just build the object raw in memory. A COM object is
    # basically just a pointer to a vtable at offset 0, and a vtable of
    # functions somewhere in memory. Don't try and get too fancy with
    # this stuff, it's pretty ghetto...
    def initialize
        # All objects need to implement these functions from IUnknown
        @refs=0
        query_interface=FFI::Function.new(:ulong, [:pointer, :pointer, :pointer]) {|this,riid,ppv|
            # Yeah there should be some logic here for incrementing ref counts
            # and such, but screw it.
            1 # E_NOINTERFACE
        }
        add_ref=FFI::Function.new(:ulong, [:pointer]) {|this|
            @refs+=1
        }
        release=FFI::Function.new(:ulong, [:pointer]) {|this|
            @refs-=1
        }
        @vtable=[query_interface, add_ref, release]
    end

    # Add a new function to the end of the vtable. Check the FFI docs for valid
    # prototype symbols, but windows probably mainly uses :ulong, :uint64, and
    # :pointer
    def add_function( ret, proto_ary, &blk )
        raise ArgumentError, "#{self.class}:#{__method__}: Need a block to add!" unless block_given?
        @vtable << FFI::Function.new( ret, proto_ary, &blk )
    end

    def interface_ptr
        unless @iface_ptr
            # Alloc a chunk of memory, platform specific pointer size
            @p=FFI::MemoryPointer.new :pointer, @vtable.size
            @p.write_array_of_pointer @vtable.map {|f| f.address}
            # Interface pointer is **vtable
            @iface_ptr=FFI::MemoryPointer.new :pointer
            @iface_ptr.write_pointer @p.address
        end
        @iface_ptr
    end
end
