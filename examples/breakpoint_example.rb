require 'buggery'

# Toy example, gives you a short stack trace whenever a given filename is used
# as a parameter by CreateFileW.
#
# The file you pass as the argument will not be opened automatically! You will
# need to manually open it in Word before you see anything interesting (or just
# hover your mouse over it).

target_filename=ARGV[0]
unless target_filename and File.file? target_filename
    fail "Usage: ruby #{$0} target_filename" 
end

debug_client=Buggery.new

bp_callback=lambda {|args|
    # Ruby level COM Object from FFI::Pointer
    bp=Breakpoint.new args[:breakpoint]
    # FFI::Struct
    params=DEBUG_BREAKPOINT_PARAMETERS.new
    bp.GetParameters params
    # Use windbg trickiness instead of API
    s=debug_client.execute '.printf "%mu", poi(@esp+4)'
    # Only match our custom ID ( example pattern to manage multiple bps )
    if params[:id]==12 && s.upcase==target_filename.upcase
        puts "BP ID #{params[:id]} hit at addr #{"%8.8x" % params[:offset]}. Stack trace:" 
        puts debug_client.execute 'kb 8'
    end
    1 # DEBUG_STATUS_GO
}

debug_client.event_callbacks.add( :breakpoint=>bp_callback )

debug_client.create_process "C:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE"
# Custom breakpoint ID. Could also do this via the API.
debug_client.execute "bp12 kernel32!CreateFileW"
loop do
    debug_client.wait_for_event(10)
    break unless debug_client.has_target?
end

