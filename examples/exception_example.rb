require 'pp'
require File.dirname(__FILE__) + '/lowlevel_buggery'

debug_client=Buggery.new

debug_client.event_callbacks.add( :exception ) {|args|
    # We can either use the EXCEPTION_RECORD64 directly
    exr=EXCEPTION_RECORD64.new args[:exception_record]
    if args[:first_chance].zero? # Non-continuable exception
        puts "#{"%8.8x" % exr[:code]} - Second chance"
        @fatal_exception=true
        # Or any native windbg commands or extensions
        puts "\n#{debug_client.execute '!exploitable'}\n" 
        puts debug_client.execute "ub @eip"
        puts debug_client.execute "u @eip"
        puts debug_client.execute "r"
    else
        puts "#{exr.code} - First chance"
        # Or sugar for the .exr command
        pp debug_client.exception_record
    end
    puts "--------------"
    1 # DEBUG_STATUS_GO
}

debug_client.create_process(
    "C:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE" +
    " #{ARGV[0]}"
)
debug_client.execute "!load winext\\msec.dll"
debug_client.wait_for_event(10) until @fatal_exception
