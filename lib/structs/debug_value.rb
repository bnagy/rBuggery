# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2014.
# License: BSD Style, see LICENSE file for details

require 'ffi'
require 'win32/wintypes'

# typedef struct _DEBUG_VALUE
# {
#     union
#     {
#         UCHAR I8;
#         USHORT I16;
#         ULONG I32;
#         struct
#         {
#             // Extra NAT indicator for IA64
#             // integer registers.  NAT will
#             // always be false for other CPUs.
#             ULONG64 I64;
#             BOOL Nat;
#         };
#         float F32;
#         double F64;
#         UCHAR F80Bytes[10];
#         UCHAR F82Bytes[11];
#         UCHAR F128Bytes[16];
#         // Vector interpretations.  The actual number
#         // of valid elements depends on the vector length.
#         UCHAR VI8[16];
#         USHORT VI16[8];
#         ULONG VI32[4];
#         ULONG64 VI64[2];
#         float VF32[4];
#         double VF64[2];
#         struct
#         {
#             ULONG LowPart;
#             ULONG HighPart;
#         } I64Parts32;
#         struct
#         {
#             ULONG64 LowPart;
#             LONG64 HighPart;
#         } F128Parts64;
#         // Allows raw byte access to content.  Array
#         // can be indexed for as much data as Type
#         // describes.  This array also serves to pad
#         // the structure out to 32 bytes and reserves
#         // space for future members.
#         UCHAR RawBytes[24];
#     };
#     ULONG TailOfRawBytes;
#   ULONG Type;
# } DEBUG_VALUE, *PDEBUG_VALUE;

class I64Parts32 < FFI::Struct

  include Win32::WinTypes

  layout(
    :low_part, ULONG,
    :high_part, ULONG
  )

end

class F128Parts64 < FFI::Struct

  include Win32::WinTypes

  layout(
    :low_part, ULONG64,
    :high_part, LONG64
    )
end

class I64Nat < FFI::Struct

  include Win32::WinTypes

  layout(
    :I64, ULONG64,
    :nat, BOOL
  )
end

class DebugValueUnion < FFI::Union

  include Win32::WinTypes

  layout(
    :I8, UCHAR,
    :I16, USHORT,
    :I32, ULONG,
    :I64_nat, I64Nat,
    :F32, :float,
    :F64, :double,
    :F80Bytes, [UCHAR, 10],
    :F82Bytes, [UCHAR, 11],
    :F128Bytes, [UCHAR, 16],
    :VI8, [UCHAR, 16],
    :VI16, [USHORT, 8],
    :VI32, [ULONG, 4],
    :VF32, [:float, 4],
    :VF64, [:double, 2],
    :I64_parts_32, I64Parts32,
    :F128_parts_64, F128Parts64,
    :raw_bytes, [UCHAR, 24]
  )
end

class DebugValue < FFI::Struct

  include Win32::WinTypes

  DEBUG_VALUE_INT8       =  1
  DEBUG_VALUE_INT16      =  2
  DEBUG_VALUE_INT32      =  3
  DEBUG_VALUE_INT64      =  4
  DEBUG_VALUE_FLOAT32    =  5
  DEBUG_VALUE_FLOAT64    =  6
  DEBUG_VALUE_FLOAT80    =  7
  DEBUG_VALUE_FLOAT82    =  8
  DEBUG_VALUE_FLOAT128   =  9
  DEBUG_VALUE_VECTOR64   =  10
  DEBUG_VALUE_VECTOR128  =  11

  layout(
    :u, DebugValueUnion,
    :tail_of_raw_bytes, ULONG,
    :type, ULONG
  )

  def get_value desired_array_type=nil

    case self[:type]
    when DEBUG_VALUE_INT8
      self[:u][:I8]
    when DEBUG_VALUE_INT16
      self[:u][:I16]
    when DEBUG_VALUE_INT32
      self[:u][:I32]
    when DEBUG_VALUE_INT64
      self[:u][:I64_nat][:I64]
    when DEBUG_VALUE_FLOAT32
      self[:u][:F32]
    when DEBUG_VALUE_FLOAT64
      self[:u][:F64]
    when DEBUG_VALUE_FLOAT80
      self[:u][:F80Bytes].to_a
    when DEBUG_VALUE_FLOAT128
      self[:u][:F128Bytes].to_a
    when DEBUG_VALUE_VECTOR64
      if desired_array_type
        self[:u][desired_array_type].to_a[0,self[:u][desired_array_type].size/2]
      else
        # Who knows? Let them eat :ulong
        self[:u][:VI32].to_a[0,2]
      end
    when DEBUG_VALUE_VECTOR128
      if desired_array_type
        self[:u][desired_array_type].to_a
      else
        # Who knows? Let them eat :ulong
        self[:u][:VI32].to_a
      end
    else
      raise "Internal Error"
    end
  end

  def get_raw_union
    self[:u][:raw_bytes].to_a
  end

end
