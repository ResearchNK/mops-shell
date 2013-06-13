#
# This command runner tries to make as few side effects, as possible. It lets
# the commands to "pass through", just pretending to run them.  Nevertheless, it
# does not do nothing. It at least tries to return successful exit statuses duck
# objects, where applicable. It may also trace invocations.
#
# @note Most of the methods of this module are sugared anyway in
#   {ShellSugarsModule}, so check the documentation there, as the sugars module
#   is usually a well defined interface to command runners.
#
# @see ShellSugarsModule
# @see FakeShell
#
module FakeCommandRunnerModule

    #
    # A duck type for returning exit statuses.
    #
    class Status
        attr_reader :exitstatus

        def initialize(exitstatus)
            @exitstatus = exitstatus
        end
    end

    def run(command)
        run!(command) 
    end

    def run!(command)
        # puts "[running] #{ command }"
        [ Status.new(0) ]
    end

    def run_r(command)
        run(command) 
    end

    def capture(command)
        capture!(command)
    end

    def capture!(command)
        # puts "[capturing] #{ command }"
        ''
    end

    def capture2i(input_string, command)
        raise NotImplementedError
    end

    def capture_i(input_string, command)
        capture_i!(input_string, command)
    end

    def capture_i!(input_string, command)
        capture!(command)
    end
end

