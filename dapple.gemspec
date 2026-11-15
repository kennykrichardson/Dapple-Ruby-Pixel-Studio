# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'dapple'
  spec.version       = '0.4.1'
  spec.summary       = 'A polished procedural pixel-art studio'
  spec.description   = 'An interactive pixel editor with procedural pattern generators.'
  spec.authors       = ['Kenny Richardson']
  spec.homepage      = 'https://kennykrichardson.onrender.com/'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.files         = Dir['lib/**/*.rb', 'bin/*', 'README.md', 'CHANGELOG.md', 'LICENSE', 'Rakefile']
  spec.bindir        = 'bin'
  spec.executables   = ['dapple']
  spec.require_paths = ['lib']
  spec.add_runtime_dependency 'chunky_png', '~> 1.4'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'ruby2d', '= 1.0.0'
end
