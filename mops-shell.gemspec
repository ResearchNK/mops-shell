Gem::Specification.new do |s|
    s.name        = 'mops-shell'
    s.version     = '0.0.1'
    s.authors     = [ 'Konrad Procak' ]
    s.files       = Dir[ 'lib/**/*.rb' ] #+ %(LICENSE.txt README.md)
    s.test_files  = Dir[ 'spec/**/*.rb' ]
    s.summary     = "A shell scripting approach " +
                    "with ruby based DSL (extensible), support for " +
                    "Bash-like syntax, error checking (exceptions) " +
                    "and remote executions (DRY)."

    s.add_runtime_dependency 'iron-extensions' 
    s.add_runtime_dependency 'net-ssh'

    s.add_development_dependency 'rspec'
end

