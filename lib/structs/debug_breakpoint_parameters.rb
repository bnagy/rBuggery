# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2014.
# License: BSD Style, see LICENSE file for details

require 'ffi'
require 'win32/wintypes'

# // Structure for querying breakpoint information
# // all at once.
# typedef struct _DEBUG_BREAKPOINT_PARAMETERS
# {
#     ULONG64 Offset;
#     ULONG Id;
#     ULONG BreakType;
#     ULONG ProcType;
#     ULONG Flags;
#     ULONG DataSize;
#     ULONG DataAccessType;
#     ULONG PassCount;
#     ULONG CurrentPassCount;
#     ULONG MatchThread;
#     ULONG CommandSize;
#     ULONG OffsetExpressionSize;
# } DEBUG_BREAKPOINT_PARAMETERS, *PDEBUG_BREAKPOINT_PARAMETERS;

module Buggery
  module Structs

    class DebugBreakpointParameters < FFI::Struct

      include Win32::WinTypes

      layout(
        :offset, ULONG64,
        :id, ULONG,
        :break_type, ULONG,
        :proc_type, ULONG,
        :flags, ULONG,
        :data_size, ULONG,
        :data_access_type, ULONG,
        :pass_count, ULONG,
        :current_pass_count, ULONG,
        :match_thread, ULONG,
        :command_size, ULONG,
        :offset_expression_size, ULONG
        )

    end

  end
end
