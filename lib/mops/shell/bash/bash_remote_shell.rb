require 'mops/shell/shell_session'
require 'mops/shell/shell_sugars_module'
require 'mops/shell/ssh_command_runner_module'
require 'mops/shell/bash/bash_commands_formatter'
require 'mops/shell/bash/bash_shell_module'
require 'iron/extensions'
require 'net/ssh'

#
# This shell is used for a remote command execution through SSH.
#
class BashRemoteShell

    #
    # Fake SSH channel used for tests. I know I should not reimplement objects I
    # don't owe. But I did. There is not much code here and the ssh package
    # seems to be in a quite mature state. Testing something called "a remote
    # shell" without actually having any "remotion" here would be impossible
    # with unit testing. Should I use some integration tests? Maybe, but unit
    # testing this should not be so harmful, and gives me a great feedback
    # especially when refactoring.
    #
    # @private
    class FakeChannel
        @on_process_block
        @on_data_block
        @on_extended_data_block
        @on_request_blocks

        def initialize
            @on_request_blocks = {}
        end

        def on_process(&block)
            @on_process_block = block
        end

        def on_data(&block)
            @on_data_block = block
        end

        def on_extended_data(&block)
            @on_extended_data_block = block
        end

        def on_request(type, &block)
            @on_request_blocks[type] = block
        end

        def exec(command)
            yield self, true
        end

        def exit_status
            0
        end

        def wait
            @on_process_block.call(self) if @on_process_block

            if respond_to?(:output_data) and output_data
                @on_data_block.call(self, output_data)
            end

            if respond_to?(:extended_data) and extended_data
                @on_extended_data_block.call(self, 1, extended_data)
            end

            exitstatus = exit_status

            @on_request_blocks['exit-status'].call(
                self,
                Class.new do
                    define_method :read_long do
                        exitstatus
                    end
                end.new
            )
        end
    end

    #
    # Remote Bash shell is a stateful creature. So every script is evaluated on
    # a special session object, which encapsulates the connection state.
    #
    # @private
    class Session < ShellSession
        attr_reader :ssh

        def initialize(ssh)
            super(
                {
                    :commands_runner_module => SSHCommandRunnerModule,
                    :shell_session_module => BashShellModule,
                    :shell_sugars_module => ShellSugarsModule,
                    :commands_formatter => BashCommandsFormatter.new
                }
            )
            @ssh = ssh
        end
    end

    @host
    @user

    #
    # No password here to inject? Well, use SSH authentication with private and
    # public keys, for God's sake!
    #
    def initialize(host, user)
        @host = host
        @user = user
    end

    #
    # Every claims-to-be-a-shell object should be able to evaluate a script.
    # This one creates a new session every time challenged.
    # 
    def script(&block)

        Net::SSH.start(@host, @user) do |ssh|
            session = create_session(ssh)
            DslProxy.exec(session, &block)
        end
    end

    private

    def create_session(*args)
        BashRemoteShell::Session.new(*args)
    end
end

