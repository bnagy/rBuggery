require 'rubygems'
require 'ffi'

class EXCEPTION_RECORD64 < FFI::Struct
  layout :code, :ulong,
     :flags, :ulong,
     :record, :uint64,
     :address, :uint64,
     :number_parameters, :ulong,
     :__unused, :ulong,
     :exception_information, [:uint64, 15]

  def code
    "%8.8x" % self[:code]
  end

  def address
    "%8.8x" % self[:address]
  end

  def record
    return nil if self[:record].zero?
    EXCEPTION_RECORD64.new( FFI::Pointer.new( self[:record] ) )
  end

  def exception_information
    self[:exception_information].first( self[:number_parameters] )
  end
end
