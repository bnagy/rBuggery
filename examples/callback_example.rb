require 'buggery'

# Toy example, to demonstrate the use of event callbacks, by registering a
# callback for LoadModule

debugger = Buggery::Debugger.new

lm_callback = lambda {|args|
  # args receives a hash, keys and values taken from the callback definition
  # in dbgeng.h, but converted to snake_case.
  puts(
    "Module Load:
    Name: #{args[:image_name].downcase} 
    Base Address: 0x#{"%16.16x" % args[:base_offset]} 
    Size: 0x#{"%x" % args[:module_size]}"
  )
  return 0 # DEBUG_STATUS_NO_CHANGE
}

debugger.event_callbacks.add( :load_module=>lm_callback )
debugger.create_process "notepad.exe"

loop do
  # We use a timeout here, because ^C won't interrupt a wait_for_event with an
  # infinite timeout ( the signal handler is ruby, but the C thread never
  # returns control to the ruby VM )
  begin
    debugger.wait_for_event 10 # msec
    break unless debugger.has_target?
  rescue
    break
  end
end
