require 'mops/shell/command'

#
# So, the concept for a shell is to be able to provide "a session", that is an
# object, which evaluates a script instance (ruby block). If the shell is
# stateless (for example, local shell does not have to handle connections), it
# can use itself and mix shell session methods as to itself, instead of to some
# on-demand created object. It should be transparent from the script code point
# of view. As you can see, the session module is quite humble. That's because
# most of the shell script scope methods are more specific, than one may desire,
# and are implemented in command runners, also sugared by another module, which
# I wanted to be a separate concept.
#
# @see ShellSugarsModule
#
module ShellSessionModule

    def pipeline(commands)
        Pipeline.new(commands)
    end
end
