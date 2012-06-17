require 'ffi'

class I64Parts32 < FFI::Struct
    layout :low_part, :ulong,
           :high_part, :ulong
end

class F128Parts64 < FFI::Struct
    layout :low_part, :uint64,
           :high_part, :int64
end

class I64Nat < FFI::Struct
    layout :I64, :uint64,
           :nat, :int
end

class DebugValueUnion < FFI::Union
    layout :I8, :uchar,
           :I16, :ushort,
           :I32, :ulong,
           :I64_nat, I64Nat,
           :F32, :float,
           :F64, :double,
           :F80Bytes, [:uchar, 10],
           :F82Bytes, [:uchar, 11],
           :F128Bytes, [:uchar, 16],
           :VI8, [:uchar, 16],
           :VI16, [:ushort, 8],
           :VI32, [:ulong, 4],
           :VF32, [:float, 4],
           :VF64, [:double, 2],
           :I64_parts_32, I64Parts32,
           :F128_parts_64, F128Parts64,
           :raw_bytes, [:uchar, 24]
end

class DEBUG_VALUE < FFI::Struct
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

    layout :u, DebugValueUnion,
           :tail_of_raw_bytes, :ulong,
           :type, :ulong

    def get_value( desired_array_type=nil )
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
