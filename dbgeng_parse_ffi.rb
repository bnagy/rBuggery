# Let's never speak of this script again.

s=File.read "dbgeng.h"
Translate={
    'ULONG'=>':ulong',
    'ULONG64'=>':uint64',
    'REFIID'=>':pointer',
    'BOOL'=>':int',
    'VOID'=>':void',
    'VOID*'=>':void',
    'PVOID'=>':void',
    'LONG'=>':ulong'
}
apis=[]
this_api_args=''
in_api=false
ruby_api_name=''
in_interface=false
counter=0
s.each_line {|l|
    if l=~ /\/\//
        next
    end
        if l=~/define/
            apis << l.squeeze(' ').split(' ').last(2).join( '=' )
            next
        end
    if l=~/DECLARE_INTERFACE/
        iface_name=l.match( /\((.*),/ )[1]
        apis << "===> #{iface_name}"
        iface_name=iface_name.scan( /[A-Z].*?(?=[A-Z]|$)/ ).map {|e| e.downcase}.join('_')
        ruby_api_name=iface_name.sub('i_debug','vtable_idebug')
        in_interface=true
        counter=0
        next
    end
    if in_interface
        if l=~ /^};/
            in_interface=false
            next
        end
        if l=~/STDMETHOD/
            apiname=l.match( /\((.*)\)/ )[1].tr(' ','').split(',').last
            # emit definition start
            apis << ":#{apiname}=>FFI::Function.new( :ulong, ["
            counter+=1
            in_api=true
            this_api_args=[]
            next
        end
        if in_api
            if l=~ /\) PURE;/
                # finish definition
                in_api=false 
                apis.last << this_api_args.join(',') << "], @vtable[#{counter-1}], convention: :stdcall  ),"
                this_api_args=[]
                next
            end
            args=l.sub(/\/\*.*\*\//, '').split
            if args[0]=~/THIS/
                this_api_args << ':pointer'
            else
                if args[1]=~/P.*STR/ and args[0]=~/__in/
                    this_api_args << ':string'
                elsif args[1]=~/^P/
                    this_api_args << ':pointer'
                else
                    this_api_args << Translate[args[1]] rescue puts args[1]
                end
            end
            next
        end
    end
}
puts apis
