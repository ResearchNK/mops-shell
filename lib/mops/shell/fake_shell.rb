require 'iron/extensions'
require 'mops/shell/shell_session'
require 'mops/shell/shell_sugars_module'
require 'mops/shell/fake_command_runner_module'
require 'mops/shell/bash/bash_shell_module'
require 'mops/shell/bash/bash_commands_formatter'

#
# This fake shell is used for mocking and testing. Should have no effect on the
# external environment. Commands run by this shell do almost nothing, they might
# be traced though in some way. Their behavior can also be altered with rspec
# stubbing.
#
# @see FakeCommandRunnerModule
#
class FakeShell < ShellSession

    def initialize
        super(
            {
                :commands_runner_module => FakeCommandRunnerModule,
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

