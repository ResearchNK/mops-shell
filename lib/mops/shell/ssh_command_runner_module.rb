require 'mops/shell/command'

#
# Most of the methods of this module are sugared anyway in {ShellSugarsModule},
# so check the documentation there.
#
module SSHCommandRunnerModule

    def run(command)
        _generic_exec(command, true, false, nil)[1]
    end

    def run!(command)
        _generic_exec(command, false, false, nil)[1]
    end

    def run_r(command, &block)
    
        #
        # This is somehow poor implementation, no real pipelining here.
        #

        io = StringIO.new
        io.write(capture(command))
        io.rewind
        yield io
        nil
    end

    def capture(command)
        _generic_exec(command, true, true, nil)[0]
    end

    def capture_i!(input_string, command)
        _generic_exec(command, false, true, input_string)[0]
    end

    def capture_i(input_string, command)
        _generic_exec(command, true, true, input_string)[0]
    end

    private
    
    # @!visibility public
    def _generic_exec(command, check_exit_status, capture_output, input_string)
        output = nil
        sent = false
        exit_status = nil

        ch = ssh.open_channel do |ch|
            
            ch.exec commands_formatter.to_command_with_redirections_s(command) do |ch, success|
                raise CommandError.new(command) unless success

                if input_string
                    ch.on_process do
                        if not sent then
                            ch.send_data(input_string)
                            ch.eof!
                            sent = true
                        end
                    end
                end

                ch.on_data do |ch, data|

                    if capture_output
                        raise 'Multipart output return not supported' if output
                        output = data
                    else
                        get_file_object(command.stdout).write(data)
                    end
                end

                ch.on_extended_data do |ch, type, data|
                    get_file_object(command.stderr).write(data)
                end

                ch.on_request 'exit-status' do |ch, data|
                    exit_status = data.read_long
                end
            end
        end

        ch.wait

        # keep the Process::Status interface for this
        status = Class.new do
            define_method :exitstatus do
                exit_status
            end
        end.new

        if check_exit_status
            raise CommandError.new(
                command,
                status
            ) unless exit_status == 0
        end

        [ output, [ status ] ]
    end

    private

    def get_file_object(object)
        if object.kind_of?(IO)
            return object
        else
            # How to create a "remote File object" and is it a really good idea?
            raise NotImplementedError,
                "Cannot create File object for the remote object: #{ object }"
        end
    end
end

