require File.dirname(__FILE__) + '/lowlevel_buggery'

target_filename=ARGV[0]
debug_client=Buggery.new
debug_client.event_callbacks.add( :breakpoint ) {|args|
    bp=Breakpoint.new(args[:breakpoint])
    params=DEBUG_BREAKPOINT_PARAMETERS.new
    bp.GetParameters params
    p Hash[*(params.members.zip( params.values).flatten)]
    s=debug_client.execute(".printf \"%mu\", poi(@esp+4)")
    if s==target_filename
        puts "File accessed. Stack trace:" 
        puts debug_client.execute("kb 8")
    end
    1 # DEBUG_STATUS_GO
}
debug_client.create_process("C:\\Program Files\\Microsoft Office\\Office12\\WINWORD.EXE")
debug_client.execute "bp kernel32!CreateFileW"
loop do
    debug_client.wait_for_event(10)
end

