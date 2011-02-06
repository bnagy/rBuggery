# I know there are a bunch of libraries that parse binary data
# into Ruby objects of varying degrees of sugar, but I want to
# keep this as low level as possible, and let the clients of
# the lowlevel interface make them prettier, if they want.

module DebugStructs
    EXCEPTION_RECORD64={
        :unpack_string=>'LLQQLL16Q',
        :fields=>[
            'code',
            'flags',
            'record',
            'address',
            'num_params',
            'unused',
            *((0...15).map {|e| "info#{e}"})
        ],
        :parser=>Proc.new {|s| 
            Hash[EXCEPTION_RECORD64[:fields].zip( s.unpack(EXCEPTION_RECORD64[:unpack_string]).map {|e| "%.8x" % e} )]
        }
    }
end

