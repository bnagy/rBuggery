# To be included in the Buggery class. Relies on the methods debug_client and
# raise_errorcode. The intention is that Buggery object eventually hold only
# critical methods for the interface itself, and that syntactic sugar for
# various purposes be collected into themed modules.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

module BuggerySugar

  def current_offset
    retval = self.debug_client.DebugRegisters.GetInstructionOffset( offset=p_ulong_long )
    self.raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
    offset.read_ulong_long
  end

  def offset_to_symbol offset
    p_sym = p_char 256
    p_displacement = p_ulong_long
    retval = self.debug_client.DebugSymbols.GetNameByOffset(
      offset,
      p_sym,
      p_sym.size,
      nil, # size of returned name, we don't care because we read as a CSTR
      p_displacement
    )
    if retval.zero? #S_OK
      [ p_sym.read_string, p_displacement.read_ulong_long ]
    else
      [ offset.to_s(16), '00']
    end
  end

  def pseudo_register reg
    # TODO THIS IS INCOMPLETE
    p_idx = p_ulong
    retval = self.debug_client.DebugRegisters2.GetPseudoIndexByName reg, p_idx
    raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
    p_debug_value=FFI::MemoryPointer.new DEBUG_VALUE
    retval = self.debug_client.DebugRegisters2.GetPseudoValues(
      DebugRegisters2::DEBUG_REGSRC_DEBUGGEE,
      1,
      nil,
      p_idx.read_ulong,
      p_debug_value
    )
    raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
    DEBUG_VALUE.new( p_debug_value ).get_value
  end

  def current_symbol
    offset_to_symbol current_offset
  end

  # In: Nothing
  # Out: Integer( target_pid )
  def current_process
    retval=self.debug_client.DebugSystemObjects.GetCurrentProcessSystemId( pid=p_int )
    self.raise_errorcode( retval, __method__ ) unless retval.zero? # S_OK
    pid.read_int
  end

end
