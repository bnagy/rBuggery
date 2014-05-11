# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2014.
# License: BSD Style, see LICENSE file for details

require 'ffi'
require 'win32/wintypes'

# typedef struct _EXCEPTION_RECORD64 {
#   DWORD ExceptionCode;
#   DWORD ExceptionFlags;
#   DWORD64 ExceptionRecord;
#   DWORD64 ExceptionAddress;
#   DWORD NumberParameters;
#   DWORD __unusedAlignment;
#   DWORD64 ExceptionInformation[EXCEPTION_MAXIMUM_PARAMETERS];
# } EXCEPTION_RECORD64,*PEXCEPTION_RECORD64;

module Buggery
  module Structs

    class ExceptionRecord64 < FFI::Struct

      EXCEPTION_MAXIMUM_PARAMETERS = 15

      include Win32::WinTypes

      layout(
        :code, DWORD,
        :flags, DWORD,
        :record, PEXCEPTION_RECORD64,
        :address, DWORD64,
        :number_parameters, DWORD,
        :__unused, DWORD,
        :exception_information, [DWORD64, EXCEPTION_MAXIMUM_PARAMETERS]
      )

      def code
        "%8.8x" % self[:code]
      end

      def address
        "%16.16x" % self[:address]
      end

      def exception_information
        self[:exception_information].first( self[:number_parameters] )
      end

    end
    
  end
end
