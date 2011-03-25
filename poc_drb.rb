require 'rubygems'
require 'drb'
require 'trollop'
require 'win32/api'
require File.dirname(__FILE__) + '/lowlevel_buggery'

OPTS=Trollop::options do
    opt :port, "Port to listen on", :type=>:integer, :default=>8888
    opt :debug, "Debug output", :type=>:boolean
end

#system("start cmd /k ruby \"#{File.dirname(__FILE__) + '/drb_debug_server.rb'}\" -p #{OPTS[:port]+1} #{OPTS[:debug]? ' -d' : ''}")

debug_client=DRbObject.new nil, "druby://127.0.0.1:#{OPTS[:port]+1}"
mark=Time.now
loop do
    debug_client.execute ".symopt+0x100" # NO_UNQUALIFIED_LOADS
    debug_client.execute ".sympath C:\\windows\\system32;C:\\localsymbols"
    puts debug_client.get_output
    debug_client.create_process("c:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE /Q")
exit
    debug_client.break
    debug_client.wait_for_event( -1 ) # which will be the breakpoint event
    puts debug_client.get_output
    debug_client.clear_output # discard startup blurb
    type, desc, extra=debug_client.get_last_event_information
    p debug_client.exception_record
    puts debug_client.execute ".lastevent"
    puts debug_client.disassemble( debug_client.registers['eip'], 10 ).map {|a| a.join(' ')}
    debug_client.go
    debug_client.terminate_process
end
puts Time.now - mark
