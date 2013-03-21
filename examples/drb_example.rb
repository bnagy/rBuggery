require 'rubygems'
require 'pp'
require 'drb'
require 'trollop'
require 'buggery'

# This is an example of using a separate process to run the debugger, and
# connecting to it using DRb. It also doubles as a toy benchmark / memory leak
# testing script (change from 1000.times to loop do for leak testing)

OPTS=Trollop::options do
  opt :port, "Port to listen on", :type=>:integer, :default=>8889
  opt :debug, "Debug output", :type=>:boolean
end

Thread.new {
  # Need to thread out for JRuby compatability, because system hangs.
  system("start drb_debug_server -p #{OPTS[:port]} #{OPTS[:debug]? ' -d' : ''}")
}
sleep 5 # give it time to start up

debug_client=DRbObject.new nil, "druby://127.0.0.1:#{OPTS[:port]}"
mark=Time.now
1000.times do
  # Just do some random stuff....
  debug_client.execute ".symopt+0x100" # NO_UNQUALIFIED_LOADS
  debug_client.execute ".sympath C:\\windows\\system32;C:\\localsymbols"
  debug_client.create_process("notepad.exe")
  debug_client.break
  debug_client.wait_for_event( -1 ) # which will be the breakpoint event
  type, desc, extra=debug_client.get_last_event_information
  puts desc
  pp debug_client.exception_record
  puts debug_client.execute ".lastevent"
  ip = debug_client.pseudo_register '$ip'
  puts debug_client.disassemble( ip, 10 ).map {|ary| ary.join(' ')}
  debug_client.go
  debug_client.terminate_process
end
puts Time.now - mark # ~140s on my MBP
debug_client.destroy rescue nil
