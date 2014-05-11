require 'pp'
require 'buggery'

# This is mainy in response to issue #1 - multiple event callbacks not working.
# I had to change the EventCallbacks#add method to take a hash, since it seems
# multiple calls to SetEventCallbacks using the same COM object segfaults. For
# now, we only support one add call, with all of the callbacks you want to use
# as a hash, and we've disabled #remove.

include Buggery::Structs
include Buggery::Raw

debugger = Buggery::Debugger.new

target_filename=ARGV[0]
unless target_filename and File.file? target_filename
  fail "Usage: (j)ruby #{$0} target_filename"
end

bp_callback=lambda {|args|

  # Ruby level COM Object from FFI::Pointer
  bp = DebugBreakpoint.new args[:breakpoint]
  params = DebugBreakpointParameters.new
  bp.GetParameters params

  if FFI::Platform::ADDRESS_SIZE==64

    # x64 stdcall, first arg is in rcx
    s = debugger.execute '.printf "%mu", @rcx'

    # Only match our custom ID ( example pattern to manage multiple bps )
    if params[:id]==12 && s.upcase==target_filename.upcase
      puts "==== BREAKPOINT CALLBACK ===="
      puts "BP ID #{params[:id]} hit at addr #{"%16.16x" % params[:offset]}. Stack trace:"
      puts debugger.execute 'kb 8'
    end

  else

    # x86 stdcall, first arg at esp+4
    s = debugger.execute '.printf "%mu", poi(@esp+4)'

    # Only match our custom ID ( example pattern to manage multiple bps )
    if params[:id]==12 && s.upcase==target_filename.upcase
      puts "==== BREAKPOINT CALLBACK ===="
      puts "BP ID #{params[:id]} hit at addr #{"%8.8x" % params[:offset]}. Stack trace:"
      puts debugger.execute 'kb 8'
    end

  end

  return 1 # DEBUG_STATUS_GO

}

exception_callback = lambda {|args|

  puts "==== EXCEPTION CALLBACK ===="
  pp args

  exr = ExceptionRecord64.new args[:exception_record]

  if args[:first_chance].zero?
    # We can either use the EXCEPTION_RECORD64 directly
    puts "#{"%8.8x" % exr[:code]} - Second chance"
    @fatal_exception=true
  else
    puts "#{exr.code} - First chance"
    pp debugger.exception_record
  end

  # Or any native windbg commands or extensions
  puts "===!exploitable==="
  puts debugger.execute '!exploitable -m'
  puts "===END !exploitable==="
  # Use pseudo registers for x86 / x64 compatability
  puts debugger.execute "ub @$ip"
  puts debugger.execute "u @$ip"
  puts debugger.execute "r"
  puts "--------------"

  return 1 # DEBUG_STATUS_GO
}

puts "STARTING EXAMPLE, Buggery lib version #{Buggery::VERSION}"
puts debugger.execute 'version' # windbg version

debugger.event_callbacks.add( :breakpoint=>bp_callback, :exception=>exception_callback )
# POSSIBLE BUG? Must load msec before create process, here
debugger.execute "!load winext\\msec.dll"

debugger.create_process(
  "notepad.exe #{ARGV[0]}"
)
debugger.execute "bp12 kernel32!CreateFileW"

loop do
  begin
    debugger.wait_for_event(10)
    break if @fatal_exception
    break unless debugger.has_target?
  rescue
    puts $!
    break
  end
end
