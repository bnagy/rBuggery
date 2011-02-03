require 'win32/api'
require File.dirname(__FILE__) + '/lowlevel_buggery'

debug_client=Bugger.new

debug_client.create_process("c:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE /Q /X C:\\crash-OFELS-1112053.doc")
debug_client.wait_for_event( -1 )
type, desc, extra=debug_client.get_last_event_information
p debug_client.lookup_event( type )
puts debug_client.disassemble( debug_client.registers['eip'], 15 ).map {|a| a.join(' ')}
debug_client.execute '.sympath C:\\localsymbols'
puts debug_client.execute( "!address" )
debug_client.terminate_process
