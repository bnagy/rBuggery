# This is mainly so that the rest of the code will appear consistent with
# Windows documentation, and allows me to quickly prototype new APIs by copying
# directly from MSDN.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'ffi'

module Win32
  module WinTypes

    # This is a roundabout way of doing things, but I am trying to keep
    # definitions consistent with the types found here:
    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa383751(v=vs.85).aspx
    WIN64=FFI::Platform::ADDRESS_SIZE==64
    if WIN64
      ULONG_PTR = FFI::TypeDefs[:uint64]
      LONG_PTR  = FFI::TypeDefs[:uint64]
    else
      ULONG_PTR = FFI::TypeDefs[:ulong]
      LONG_PTR  = FFI::TypeDefs[:long]
    end
    ULONG     = FFI::TypeDefs[:ulong]
    ULONG64   = FFI::TypeDefs[:ulong_long]
    LONG      = FFI::TypeDefs[:long]
    INT       = FFI::TypeDefs[:int]
    WORD      = FFI::TypeDefs[:uint16]
    BYTE      = FFI::TypeDefs[:uchar]
    DWORD     = FFI::TypeDefs[:ulong]
    DWORD64   = FFI::TypeDefs[:uint64]
    BOOL      = FFI::TypeDefs[:int]     # srsly??
    BOOLEAN   = BYTE                    # not making this up.
    UINT      = FFI::TypeDefs[:uint]
    POINTER   = FFI::TypeDefs[:pointer]
    SHORT     = FFI::TypeDefs[:short]
    VOID      = FFI::TypeDefs[:void]
    THIS_     = POINTER
    REFIID    = POINTER
    SIZE_T    = ULONG_PTR
    TCHAR     = WCHAR = WORD            # let's assume unicode is always defined
    CHAR      = UCHAR = BYTE
    LPVOID    = POINTER
    PVOID     = POINTER
    HANDLE    = ULONG_PTR               # handles are pointers, lol
    HRESULT   = LONG                    # HRESULT is not a handle, lol
    NTSTATUS  = LONG
    HWND      = HICON = HCURSOR = HBRUSH = HDC = HINSTANCE = HGDIOBJ =
      HMENU = HMODULE = HFONT = HMETAFILE = HANDLE
    LPARAM    = LONG_PTR
    WPARAM    = ULONG_PTR
    LPSTRUCT  = LPVOID                  # Use for when too lazy to add below
    LPCTSTR   = LPMSG = LPRECT = LPBOOL = LPPAINTSTRUCT = LPDX = LPSIZE =
      LPLF = LPCWSTR = LPLOGFONT = LPTEXTMETRIC = LPBITMAPINFO =
      LPDWORD = LPINITDATA = LPDOCINFO = LPVOID
    LRESULT   = LONG_PTR
    ATOM      = WORD

    PULONG = PULONG64 = PBOOL = POINTER
    # These *_OUT types I just made up. It's because it's nice to be able to
    # pass a string to __in params, but for __out params we need to pass a
    # pointer to the FFI func and read_string to get the filled value.
    PSTR_OUT = PWSTR_OUT = POINTER
    PCSTR = PSTR = PCWSTR = PWSTR = FFI::TypeDefs[:string]

    # WARNING! NOT IMPLEMENTED
    PVA_LIST = POINTER

    # These should be gradually translated into ruby FFI structs, then they
    # can be replaced in the FFI declarations with the Ruby-level struct type,
    # indicating a pointer to that struct and allowing better checking.
    #
    # OLD: FFI::Function.new( HRESULT, [THIS_, PDEBUG_SYMBOL_GROUP], ...
    # NEW: FFI::Function.new( HRESULT, [THIS_, Buggery::Structs::DebugSymbolGroup], ...

    PDEBUG_CLIENT = PDEBUG_INPUT_CALLBACKS = PDEBUG_OUTPUT_CALLBACKS =
      PDEBUG_EVENT_CALLBACKS = PDEBUG_BREAKPOINT_PARAMETERS = PDEBUG_OUTPUT_CALLBACKS_WIDE =
      PDEBUG_EVENT_CALLBACKS_WIDE = PDEBUG_STACK_FRAME = PDEBUG_BREAKPOINT =
      PDEBUG_VALUE = FARPROC = PWINDBG_EXTENSION_APIS32 =
      PWINDBG_EXTENSION_APIS64 = PDEBUG_SPECIFIC_FILTER_PARAMETERS = PDEBUG_EXCEPTION_FILTER_PARAMETERS =
      PMEMORY_BASIC_INFORMATION64 = LPGUID = PIMAGE_NT_HEADERS64 =
      PEXCEPTION_RECORD64 = PDEBUG_BREAKPOINT2 = PDEBUG_REGISTER_DESCRIPTION =
      PDEBUG_SYMBOL_PARAMETERS = PDEBUG_MODULE_PARAMETERS = PDEBUG_SYMBOL_GROUP =
      PDEBUG_SYMBOL_GROUP2 = PDEBUG_MODULE_AND_ID = PDEBUG_SYMBOL_SOURCE_ENTRY =
      PDEBUG_OFFSET_REGION = POINTER

  end
end
