require 'mops/shell/unix/unix_shell_module'

#
# Some shell commands are so Bash-specific, they cannot be put in the general
# unix shell module. Nevertheless, methods names should stay the same for any
# other shell implementation. 
#
module BashShellModule

    #
    # Mix methods for all unix shell sessions.
    #
    include UnixShellModule

    #
    # @return [boolean]
    #
    def file_exists?(path)
        command = ShellCommand.new('[', '-e', path, ']')
        status, = R! command
        status.exitstatus == 0
    end

    #
    # Yields each line from file. The block is required.
    #
    def each_line_from_file(path, &block)

        Rr (cat path).redirect!('/dev/null', 2) do |last_stdout|
            last_stdout.each_line(&block) 
        end
    end
end
