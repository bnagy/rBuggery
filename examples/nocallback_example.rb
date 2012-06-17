require 'buggery'

# This is a trivial example of manually managing events using #wait_for_event,
# instead of callbacks. This pattern is the only one you can use for DRb style
# programs, because the callback Procs don't Marshal yet.

debug_client=Buggery.new

puts "Creating..."
debug_client.create_process("notepad.exe")
debug_client.execute ".symopt+0x100" # NO_UNQUALIFIED_LOADS
debug_client.execute ".sympath C:\\windows\\system32;C:\\localsymbols"
debug_client.break
debug_client.wait_for_event( -1 ) # forever
type, desc, extra=debug_client.get_last_event_information
puts desc
puts debug_client.exception_record
puts debug_client.execute 'r'
puts debug_client.disassemble( debug_client.registers['eip'], 10 ).map {|a| a.join(' ')}
debug_client.go
debug_client.wait_for_event 2000    # 2 second timeout, returns false if no event
debug_client.break                  # will generate a breakpoint exception event
debug_client.wait_for_event(-1)     # caught here
# #registers gets a hash of all ~80 registers and pseudo-registers
puts debug_client.registers
debug_client.terminate_process
