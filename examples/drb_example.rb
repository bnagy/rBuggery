require 'rubygems'
require 'pp'
require 'drb'
require 'trollop'
require File.dirname(__FILE__) + '/../buggery'

OPTS=Trollop::options do
    opt :port, "Port to listen on", :type=>:integer, :default=>8889
    opt :debug, "Debug output", :type=>:boolean
end

system("start cmd /k ruby \"#{File.dirname(__FILE__) + '/../drb_debug_server.rb'}\" -p #{OPTS[:port]} #{OPTS[:debug]? ' -d' : ''}")
sleep 5 # give it time to start up

debug_client=DRbObject.new nil, "druby://127.0.0.1:#{OPTS[:port]}"
mark=Time.now
loop do
    # Just do some random stuff....
    debug_client.execute ".symopt+0x100" # NO_UNQUALIFIED_LOADS
    debug_client.execute ".sympath C:\\windows\\system32;C:\\localsymbols"
    debug_client.create_process("c:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE /Q")
    debug_client.break
    debug_client.wait_for_event( -1 ) # which will be the breakpoint event
    type, desc, extra=debug_client.get_last_event_information
    puts desc
    pp debug_client.exception_record
    puts debug_client.execute ".lastevent"
    ip=debug_client.registers[ 'eip' ]
    puts debug_client.disassemble( ip, 10 ).map {|a| a.join(' ')}
    debug_client.go
    debug_client.terminate_process
end
debug_client.destroy
puts Time.now - mark # ~140s on my MBP
