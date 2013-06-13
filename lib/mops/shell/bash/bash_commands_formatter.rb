
class BashCommandsFormatter

    #
    # Formats a command in a classic style:
    #
    # @example command "arg1" "arg2" ["arg3"...]
    #
    # @note Every argument will be quoted with double quotes. This covers
    #   most of Bash whitespace issues. At least for now this method does not
    #   escape anything else, so for example environment variables should expand.
    #   This may or may not change in the future making some incompatibilites. I
    #   can also create a new method for such cases, not sure which solution will
    #   be better.
    #
    def to_command_s(command)
        s = ''

        s << command.name.to_s
        
        if command.args.size > 0
            s << " " + command.args.map do
                |a| "#{ a }"
            end.join(" ")
        end
        
        return s
    end

    #
    # Normally we would like to handle descriptors redirections using ruby. But
    # this is not always possible. Suppose we would like to fire up a remote
    # command on a machine with no ruby installed, not to mention this gem. If
    # we still want to use the same script code to, for example, redirect a
    # remote command to a remote file, some fallback to pure shell has to be
    # done. So this command adds classic Bash-style redirection arrows, for
    # example:
    #
    # @example command "arg1" "arg2" 2>>"/path/to/some/file"
    #
    # @note Only redirections from stdout and stderr are supported at the
    #   moment. Moreover, information about about file mode must be available in
    #   order to choose between write and append. It will be, if the script
    #   contains either > or >> methods invocations. However, it is possible to
    #   manually set the stdout and stderr through #stdout! and #stderr! command
    #   methods respectively, in which case, if the values don't respond to the
    #   #mode message, an exception is raised.
    #
    # @todo Add support for any descriptor number. This requires modifications
    #   to the Command type, so it can store such information.
    #
    # @see AbstractCommand#stdout!
    # @see AbstractCommand#stderr!
    #
    def to_command_with_redirections_s(command)
        s = to_command_s(command)

        if command.stdout.respond_to?(:mode) 
            s << " #{ format_redirection_arrow(1, command.stdout) }"
        elsif not (command.stdout.respond_to?(:tty?) and command.stdout.tty?)
            raise "stdout is set to #{
                command.stdout
            }, but is not a tty and cannot deduce the opening mode."
        end

        if command.stderr.respond_to?(:mode)
            s << " #{ format_redirection_arrow(2, command.stderr) }"
        elsif not (command.stderr.respond_to?(:tty?) and command.stderr.tty?)
            raise "stderr is set to #{
                command.stderr
            }, but is not a tty and cannot deduce the opening mode."
        end

        s
    end

    private

    def format_redirection_arrow(fd, o)
       fd.to_s + case o.mode
            when 'w' then '>'
            when 'a' then '>>'
            else raise "Unsupported file opening mode: #{ command.stdout.mode }"
       end + "\"#{ o.path }\""
    end
end

