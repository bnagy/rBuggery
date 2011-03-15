require 'win32/api'
require File.dirname(__FILE__) + '/lowlevel_buggery'

debug_client=Buggery.new

i=0
100.times do
    begin
        debug_client.create_process("c:\\Windows\\System32\\notepad.exe")
        debug_client.execute ".symopt+0x100" # NO_UNQUALIFIED_LOADS
        debug_client.execute ".sympath C:\\windows\\system32;C:\\localsymbols"
        debug_client.break
        debug_client.wait_for_event( -1 )
        type, desc, extra=debug_client.get_last_event_information
        puts debug_client.exception_record
        puts debug_client.execute 'r'
        puts debug_client.disassemble( debug_client.registers['eip'], 10 ).map {|a| a.join(' ')}
        debug_client.terminate_process
    rescue
        puts $!
        puts $@
    end
    puts i+=1
end
