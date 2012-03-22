require 'rubygems'
require 'yaml'
require '../lib/buggery'

# This is mainy in response to issue #1 - multiple event callbacks not working.
# I had to change the EventCallbacks#add method to take a hash, since it seems
# multiple calls to SetEventCallbacks using the same COM object segfaults. For
# now, we only support one add call, with all of the callbacks you want to use
# as a hash, and we've disabled #remove.

debug_client=Buggery.new

bp_callback=lambda {|args|
    # Ruby level COM Object from FFI::Pointer
    bp = Breakpoint.new args[:breakpoint]
    # FFI::Struct
    params = DEBUG_BREAKPOINT_PARAMETERS.new
    bp.GetParameters params
    # Use windbg trickiness instead of API
    s = debug_client.execute '.printf "%mu", poi(@esp+4)'

    1 # DEBUG_STATUS_GO
}

exception_callback=lambda { |args|
    # FFI::Struct, with some extra sugar in the class
    puts "====   EXCEPTION ====="
    puts args.to_yaml
    exr = EXCEPTION_RECORD64.new args[:exception_record]
    if args[:first_chance].zero?
        # We can either use the EXCEPTION_RECORD64 directly
        puts "#{"%8.8x" % exr[:code]} - Second chance"
        @fatal_exception=true
        # Or any native windbg commands or extensions
        puts "\n#{debug_client.execute '!exploitable'}\n"
        puts debug_client.execute "ub @eip"
        puts debug_client.execute "u @eip"
        puts debug_client.execute "r"
    else
        puts "#{exr.code} - First chance"
        # Or sugar for the windbg '.exr' command
        puts debug_client.exception_record.to_yaml
    end
    puts "--------------"
    1 # DEBUG_STATUS_GO
}

debug_client.event_callbacks.add( :breakpoint=>bp_callback, :exception=>exception_callback )

debug_client.create_process(
    "C:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE #{ARGV[0]}"
)

debug_client.execute "!load winext\\msec.dll"
debug_client.wait_for_event 10 until @fatal_exception
