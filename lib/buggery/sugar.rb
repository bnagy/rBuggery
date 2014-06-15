# To be included in the Buggery class. Relies on the methods debug_client and
# raise_errorcode, as well as the private pointer creation shortcut methods
# p_int, p_ulong etc etc. The intention is that Buggery object eventually hold
# only critical methods for the interface itself, and that syntactic sugar for
# various purposes be collected into themed modules.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2014.
# License: BSD Style, see LICENSE file for details

module Buggery

  module Sugar

    include Raw
    include Structs

    # In: Nothing
    # Out: Numeric( current_offset )
    def current_offset
      @p_offset ||= p_ulong_long
      retval = self.debug_client.DebugRegisters.GetInstructionOffset( @p_offset )
      self.raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
      @p_offset.read_ulong_long
    end

    # In: Numeric( offset )
    # Out: Array of [ String( current_symbol ), Integer( displacement ) ]
    #
    # The displacement returned is from the symbol base. If there is no matching
    # symbol, the address is returned as a hexstring.
    def offset_to_symbol offset

      @p_sym ||= p_char 256
      @p_displacement ||= p_ulong_long
      retval = self.debug_client.DebugSymbols.GetNameByOffset(
        offset,
        @p_sym,
        @p_sym.size,
        nil, # size of returned name, we don't care because we read as a CSTR
        @p_displacement
      )

      if retval.zero? #S_OK
        [ @p_sym.read_string, @p_displacement.read_ulong_long ]
      else
        [ offset.to_s(16), '00']
      end

    end

    # In: String( regname )
    # Out: Either a Numeric or an Array of Numerics, depending on the register
    #
    # Gets the value held in a given pseudo-register. The pseudo register
    # needs to be specified as in the debugging tools documentation, including
    # the $, eg "$ra"
    def pseudo_register reg

      @p_idx ||= p_ulong
      retval = self.debug_client.DebugRegisters2.GetPseudoIndexByName reg, @p_idx
      raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK

      @p_debug_value ||= FFI::MemoryPointer.new DebugValue
      retval = self.debug_client.DebugRegisters2.GetPseudoValues(
        DebugRegisters2::DEBUG_REGSRC_DEBUGGEE,
        1,
        nil,
        @p_idx.read_ulong,
        @p_debug_value
      )
      raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK

      DebugValue.new( @p_debug_value ).get_value

    end

    # In: Nothing
    # Out: Array of [ String( current_symbol ), Integer( displacement ) ]
    #
    # The displacement returned is from the symbol base. If there is no matching
    # symbol, the address is returned as a hexstring.
    def current_symbol
      offset_to_symbol current_offset
    end

    # In: Nothing
    # Out: Integer( target_pid )
    def current_process
      @p_pid ||= p_int
      retval = self.debug_client.DebugSystemObjects.GetCurrentProcessSystemId( @p_pid )
      self.raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
      current_process = @p_pid.read_int
      current_process
    end

    # In Numeric( offset ), Numeric( len )
    # Out: String( contents ) or raise
    #
    # Reads len bytes from the given offset in the target's virtual address
    # space and returns the contents as a string. If the read succeeds it may
    # still return less bytes than specified.
    def read_virtual offset, len

      outbuf = p_char len
      outlen = p_ulong
      retval = self.debug_client.DebugDataSpaces.ReadVirtual( Integer(offset), outbuf, Integer(len), outlen )
      self.raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK

      outbuf.read_array_of_char(outlen.read_ulong).pack('c*')

    end

    def read_pointers offset, count=1
      # HRESULT ReadPointersVirtual(
      #   [in]   ULONG Count,
      #   [in]   ULONG64 Offset,
      #   [out]  PULONG64 Ptrs
      # );
      count = Integer(count)
      offset = Integer(offset)
      outbuf = FFI::MemoryPointer.new :pointer, count
      retval = self.debug_client.DebugDataSpaces.ReadPointersVirtual(count, offset, outbuf)
      self.raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK

      outbuf.read_array_of_pointer count

    end

  end
end
