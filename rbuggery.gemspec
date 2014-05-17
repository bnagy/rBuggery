Gem::Specification.new do |spec|
  spec.name       = 'rbuggery'
  spec.version    = '1.1.0'
  spec.author     = 'Ben Nagy'
  spec.license    = 'BSD'
  spec.email      = 'ben@iagu.net'
  spec.homepage   = 'https://github.com/bnagy/rBuggery'
  spec.summary    = 'An interface to the Windows Debugging Engine'
  spec.test_files = Dir['test/*.rb']
  spec.files      = Dir['**/*'].delete_if{ |item| item.include?('git') }

  spec.executables      = ['drb_debug_server','json_debug_server']
  spec.extra_rdoc_files = ['CHANGES', 'README', 'README_LOCAL_KERNEL', 'MANIFEST']

  spec.add_dependency('ffi')
  spec.add_dependency('trollop')
  # Not adding the sinatra dependency, it's too heavy to make users install
  # just in case they happen to want json_debug_server
  spec.add_development_dependency('test-unit')

  spec.description = <<-EOF
    The rBuggery gem provides an interface for the Windows Debugging
    Engine, dbgeng.dll.
  EOF
end