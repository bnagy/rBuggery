# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2012 - 2014.
# License: BSD Style, see LICENSE file for details

# Quick script to parse GUIDs from dbgeng.h into copy paste Ruby form
# Output might need modification afterwards, but it's close enough.

s=File.read "guids.txt"
this_interface=''
start=''
puts "guids={"
s.each_line {|l|
  next if l=~/\//
    if this_interface.empty?
      this_interface=l.match(/DEFINE_GUID\((.*?),/)[1]
      start="[#{l.match(/, (.*)$/)[1]}"
    else
      finish="#{l.match(/(.*)\)/)[1]}].pack('LSSC8')"
      puts ":#{this_interface.sub('IID_I','')}=>#{start+finish.squeeze(' ')},"
      this_interface.clear
      start.clear
    end

}
puts "}"
