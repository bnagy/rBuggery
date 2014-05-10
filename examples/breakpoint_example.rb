require 'buggery'

include Buggery::Raw
include Buggery::Structs

# Toy example, gives you a short stack trace whenever a given filename is used
# as a parameter by CreateFileW.
#
# The file you pass as the argument will not be opened automatically! You will
# need to manually open it in notepad before you see anything interesting (or just
# hover your mouse over it).

target_filename=ARGV[0]
unless target_filename and File.file? target_filename
  fail "Usage: (j)ruby #{$0} target_filename"
end

debug_client=Buggery::Debugger.new

bp_callback=lambda {|args|

  # Ruby level COM Object from FFI::Pointer
  bp = DebugBreakpoint3.new args[:breakpoint]
  params = DebugBreakpointParameters.new
  bp.GetParameters params

  # Use windbg trickiness instead of API
  if FFI::Platform::ADDRESS_SIZE==64

    # x64 stdcall, first arg is in rcx
    s = debug_client.execute '.printf "%mu", @rcx'

    # Only match our custom ID ( example pattern to manage multiple bps )
    if params[:id]==12 && s.upcase==target_filename.upcase
      puts "BP ID #{params[:id]} hit at addr #{"%16.16x" % params[:offset]}. Stack trace:"
      puts debug_client.execute 'kb 8'
    end

  else

    # x86 stdcall, first arg at esp+4
    s = debug_client.execute '.printf "%mu", poi(@esp+4)'

    # Only match our custom ID ( example pattern to manage multiple bps )
    if params[:id]==12 && s.upcase==target_filename.upcase
      puts "BP ID #{params[:id]} hit at addr #{"%8.8x" % params[:offset]}. Stack trace:"
      puts debug_client.execute 'kb 8'
    end

  end

  return 1 # DEBUG_STATUS_GO

}

debug_client.event_callbacks.add( :breakpoint=>bp_callback )

debug_client.create_process "notepad.exe"
# Custom breakpoint ID. Could also do this via the API.
debug_client.execute "bp12 kernel32!CreateFileW"

loop do
  debug_client.wait_for_event(10)
  break unless debug_client.has_target?
end
