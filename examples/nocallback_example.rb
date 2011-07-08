require File.dirname(__FILE__) + '/../buggery'

debug_client=Buggery.new

mark=Time.now
1.times do
    begin
        puts "Creating..."
        debug_client.create_process("C:\\Program Files\\Adobe\\Reader 10.0\\Reader\\AcroRd32.exe")
        debug_client.execute ".symopt+0x100" # NO_UNQUALIFIED_LOADS
        debug_client.execute ".sympath C:\\windows\\system32;C:\\localsymbols"
        debug_client.break
        debug_client.wait_for_event( -1 )
        type, desc, extra=debug_client.get_last_event_information
        puts desc
        puts debug_client.exception_record
        puts debug_client.execute 'r'
        puts debug_client.disassemble( debug_client.registers['eip'], 10 ).map {|a| a.join(' ')}
        debug_client.go
        debug_client.wait_for_event 2000
        debug_client.break
        debug_client.wait_for_event(-1)
        puts debug_client.registers
        debug_client.terminate_process
    rescue
        puts $!
        puts $@
    end
end
puts Time.now - mark
