# Quick helper to get formatted errors using GetLastError
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2012.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'ffi'

module WinError

  MAX_PATH=260
  FORMAT_MESSAGE_FROM_SYSTEM       = 0x00001000
  FORMAT_MESSAGE_ARGUMENT_ARRAY    = 0x00002000

  extend FFI::Library
  ffi_lib 'kernel32'
  ffi_convention :stdcall

  attach_function :GetLastError, [], :ulong
  attach_function :FormatMessageA, [:ulong, :ulong, :ulong, :ulong, :pointer, :ulong, :pointer], :ulong 

  def get_last_error
    buf = FFI::MemoryPointer.new :char, MAX_PATH
    err_code = self.GetLastError
    flags = FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_ARGUMENT_ARRAY
    self.FormatMessageA( flags, 0, err_code, 0, buf, buf.size, nil )
    buf.read_string.strip
  end
  module_function :get_last_error

end
