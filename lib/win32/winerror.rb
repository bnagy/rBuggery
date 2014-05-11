# Quick wrapper to get nice Win32 error messages.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2014.
# License: BSD Style, see LICENSE file for details

require 'ffi'

module Win32
  module WinError

    MAX_PATH                      = 260
    FORMAT_MESSAGE_FROM_SYSTEM    = 0x00001000
    FORMAT_MESSAGE_ARGUMENT_ARRAY = 0x00002000

    extend FFI::Library
    ffi_lib 'kernel32'
    ffi_convention :stdcall

    attach_function :GetLastError, [], :ulong
    attach_function(
      :FormatMessageA,
      [:ulong, :ulong, :ulong, :ulong, :pointer, :ulong, :pointer],
      :ulong
    )

    module_function

    def get_last_error
      buf = FFI::MemoryPointer.new :char, MAX_PATH
      err_code = GetLastError()
      flags = FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_ARGUMENT_ARRAY
      FormatMessageA flags, 0, err_code, 0, buf, buf.size, nil
      text = buf.read_string.strip
      "#{err_code}: #{text}"
    end

  end
end
