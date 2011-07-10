# I had some problems with Thread interactions with Sys::Proctable (which uses
# WMI) causing faults in the interpreter, with 'handle is invalid' type errors.
# Rewrote using the lower level ToolHelp32Snapshot style, and for FFI practice.
#
# Bear in mind that PROCESSENTRY32 contains much less information than you get
# from WMI, so this approach is not always going to be suitable, and it's
# pretty ugly if you need to use #each_pentry32 directly.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2011.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

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
