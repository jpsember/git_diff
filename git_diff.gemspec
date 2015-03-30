require 'rake'

Gem::Specification.new do |s|
  s.name        = 'git_diff'
  s.version     = '0.1.0'
  s.date        = '2015-03-29'
  s.summary     = "Interactive git diff utility"
  s.description = <<-EOS
    Performs an interactive 'git diff' from the command line, and gives the
    user the opportunity to review / accept / revert / edit any changes.
EOS

  s.authors     = ["Jeff Sember"]
  s.email       = 'jpsember@gmail.com'
  s.files = FileList['lib/**/*.rb',
                      'bin/*',
                      '[A-Z]*',
                      'test/**/*',
                      ]
  s.executables << 'gitdiff'
  s.add_runtime_dependency 'git_repo', '>= 0.1'
  s.add_runtime_dependency 'backup_set'

  s.homepage = 'http://www.cs.ubc.ca/~jpsember'
  s.test_files  = Dir.glob('test/*.rb')
  s.license     = 'MIT'
end
