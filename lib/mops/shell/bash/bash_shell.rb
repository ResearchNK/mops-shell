require 'iron/extensions'
require 'mops/shell/shell_session'
require 'mops/shell/shell_sugars_module'
require 'mops/shell/open3_command_runner_module'
require 'mops/shell/bash/bash_commands_formatter'
require 'mops/shell/bash/bash_shell_module'

#
# Local Bash shell is a session of it's own. It holds no internal state (besides
# the external world state of course) and there are no connections, so we can
# evaluate scripts on the same object every time the #script method is called.
#
class BashShell < ShellSession

    def initialize
        super(
            {
                :commands_runner_module => Open3CommandRunnerModule,
                :shell_session_module => BashShellModule,
                :shell_sugars_module => ShellSugarsModule,
                :commands_formatter => BashCommandsFormatter.new
            }
        )
    end

    #
    # Every claims-to-be-a-shell object should be able to evaluate a script.
    #
    def script(&block)
        DslProxy.exec(self, &block)
    end
end
