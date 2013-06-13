
#
# Some sugar syntax to make the life of shell scripting... shorter ;)
#
# @note We can't use aliases here, since the covered methods are not visible
#   at the time of sourcing the file.
#
module ShellSugarsModule

    #
    # Run a command and raise an error in case of a non-zero return status.
    #
    # @return [Array<#exitstatus>]
    #
    def R(command, &block)
        run(command, &block)
    end

    #
    # Run a command and ignore the return status.
    #
    # @return [Array<#exitstatus>]
    #
    def R!(command, &block)
        run!(command, &block)
    end

    #
    # Run a command and yield last stdout. Raise an error in case of a non-zero
    # return status. Also, for every command in the pipeline yield and return a
    # process status object, responding to an #exitstatus message and probably
    # to more messages from ruby ProcessStatus class (not guaranteed though).
    #
    # @return [Array(IO, Array<#exitstatus>)]
    #
    # @yield IO
    #
    def Rr(command, &block)
        run_r(command, &block)
    end

    #
    # Run a command, yield last stdout and ignore the return status.  Also, for
    # every command in the pipeline yield and return a process status object,
    # responding to an #exitstatus message and probably to more messages from
    # ruby ProcessStatus class (not guaranteed though).
    #
    # @return [Array(IO, Array<#exitstatus>)]
    #
    # @yield IO
    #
    def Rr!(command, &block)
        run_r!(command, &block)
    end

    #
    # Return output of a command (stdout) and raise an error in case of a
    # non-zero return status.
    #
    # @return [String]
    #
    def C(command)
        capture(command)
    end

    #
    # Return output of a command (stdout) and ignore the return status.
    #
    # @return [Array(String, Array<#exitstatus>)]
    #
    def C!(command)
        capture!(command)
    end

    #
    # Return output of a command (stdout) for a given input string on stdin
    # and raise an error in case of a non-zero return status.
    #
    # @return [String]
    #
    def Ci(input_string, command)
        capture_i(input_string, command)
    end

    #
    # Return output of a command (stdout) for a given input string on stdin
    # and ignore the return status. 
    #
    # @return [Array(String, Array<#exitstatus>)]
    #
    def Ci!(input_string, command)
        capture_i!(input_string, command)
    end
end

