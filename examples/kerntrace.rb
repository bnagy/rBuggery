require 'buggery'
require 'trollop'

# This is a bit of a dodgy example, since it is tied to jruby on the debuggee
# and relies on other code to make the debuggee exercise the symbol you're
# trying to trace. It's also horribly unreliable because of the brain-dead way I
# am tracking stack depth. 
#
# Anyway, I'm sticking it in, because it has some usage patterns that might be
# helpful.

OPTS = Trollop::options do
  opt :symbol, "Symbol to trace from", type: :string, required: true
  opt :depth, "Max depth to trace_into", type: :integer, default: 0
  opt :filter, "Symbol wildcards to filter", type: :string, multi: true
end

INSANITY_LIMIT = 30

warn "Attempting to trace #{OPTS[:symbol]} with max depth #{OPTS[:depth]}"

@debugger = Buggery::Debugger.new

def detach
  @debugger.go
  # this will block the main thread unless we thread it out.
  Thread.new {@debugger.wait_for_event} 
  Thread.pass # give the wait thread time to start
  exit
end

@debugger.attach_kernel
warn "Attached to kernel"
@debugger.break
@debugger.wait_for_event
warn "Broken in"
warn "Finding jruby.exe..."
eprocess = @debugger.execute("!process 0 0 jruby.exe")[ /PROCESS\s+(........)/, 1 ]
unless eprocess
  warn "Unable to find an eprocess for jruby.exe. Is it running yet?"
  detach
end
warn "EPROCESS is #{eprocess}"
warn "Setting context..."
@debugger.execute ".process /i /p /r #{eprocess}"
warn "Continuing, should break in automatically..."
@debugger.go
@debugger.wait_for_event
warn "OK, we hope. Reloading symbols"
@debugger.execute '.reload'
warn "Reloaded symbols"

begin
  @debugger.execute "ba e1 /1 #{OPTS[:symbol]}"
rescue
  warn $!
  warn "Unable to set breakpoint on #{OPTS[:symbol]}, aborting."
  detach
end

warn "Added breakpoints"
warn @debugger.execute "bl"
warn "About to wait...make the target do things now."
@debugger.go
@debugger.wait_for_event # should be at our breakpoint now.

# WARNING if you filter nt!* for example and the function you're tracing returns
# into ntoskrnl (which many do) then you'll miss your $ra and get runaways.
@debugger.execute ".step_filter \"#{OPTS[:filter].join(';')}\"" unless OPTS[:filter].empty?
stack = [ @debugger.current_symbol.first ]
ret_addr = @debugger.pseudo_register '$ra'

loop do
  if stack.size > OPTS[:depth]
    if stack.size > OPTS[:depth] + INSANITY_LIMIT
      warn "Runaway stack size, aborting trace for safety."
      detach
    end
    stepping_mode = DebugControl::DEBUG_STATUS_STEP_OVER
  else
    stepping_mode = DebugControl::DEBUG_STATUS_STEP_INTO
  end
  @debugger.raw.DebugControl.SetExecutionStatus stepping_mode
  @debugger.wait_for_event
  current_offset = @debugger.current_offset
  address, opcodes, disasm = @debugger.disassemble( current_offset ).first
  sym, displacement = @debugger.offset_to_symbol current_offset
  if sym != stack.last # something has happened
    if stack.include? sym # we're returning
      # HACK, but sometimes things return past more than one frame
      stack.pop until sym == stack.last
    else # we're calling (possibly), or jumping to an import, or... something?
      # NOTE: This is just fundamentally broken. Windows seems to happily ret to
      # symbols that aren't yet on the stack
      stack.push sym if sym=~/!/ # only push real symbols, like module!funcname
    end
  end
  next if @stutter==disasm # suppress output for rep movs etc
  @stutter=disasm
  break if current_offset == ret_addr
  puts "#{'[ ]' * stack.size} - #{sym}+#{displacement.to_s 16}> #{disasm}"
end

detach
