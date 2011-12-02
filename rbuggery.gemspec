require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'rbuggery'
  spec.version    = '0.0.1'
  spec.author     = 'Ben Nagy'
  spec.license    = 'MIT'
  spec.email      = 'ben@iagu.net'
  spec.homepage   = 'https://github.com/bnagy/rBuggery'
  spec.summary    = 'An interface to the Windows Debugging Engine'
  spec.test_files = Dir['test/*.rb']
  spec.files      = Dir['**/*'].delete_if{ |item| item.include?('git') }

  spec.extra_rdoc_files = ['CHANGES', 'README', 'MANIFEST']

  spec.add_dependency('ffi')
  spec.add_development_dependency('test-unit')

  spec.description = <<-EOF
    The rdebuggery gem provides an interface for the Windows Debugging
    Engine, i.e. dbgeng.dll.
  EOF
end
