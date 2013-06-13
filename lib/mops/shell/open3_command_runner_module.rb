require 'open3'
require 'mops/shell/command'

#
# This command runner runs commands locally, using standard ruby's Open3
# solution. I find Open3 module most generic but also flexible way to run
# commands in ruby, especially when it comes to piping and interacting with
# streams. It was also an inspiration to write a consistent set of methods
# required to run shell commands in most of the desired ways. If you've found
# some more cool way to run commands locally, please, let us know. We may write
# another command runner without changing scripts already written just to prove
# how awesome ruby is.
#
# @note Most of the methods of this module are sugared anyway in
#   {ShellSugarsModule}, so check the documentation there, as the sugars module
#   is usually a well defined interface to command runners.
#
# @see ShellSugarsModule
#
module Open3CommandRunnerModule
    module_function

    def run(command, &block)
        p = command.to_pipeline
        statuses = run!(p, &block)
        check_pipeline_status(p, statuses)
        statuses
    end

    def run!(command, &block)
        open3_run(:pipeline, command.to_pipeline, &block)
    end

    def run_r(command, &block)
        p = command.to_pipeline
        last_stdout, statuses = run_r!(p, &block)
        check_pipeline_status(p, statuses)
        [ last_stdout, statuses ]
    end

    def run_r!(command, &block)
        last_stdout, threads = nil, nil

        begin
            last_stdout, threads = open3_run(:pipeline_r, command.to_pipeline)
            yield last_stdout, threads
        ensure
            if last_stdout.respond_to?(:close)
                last_stdout.close
            end
        end
        
        [ last_stdout, threads.map do |t| t.value end ]
    end

    def run_rw!(command, &block)
        open3_run(:pipeline_rw, command, &block)
    end

    def capture(command)
        p = command.to_pipeline
        output, statuses = capture!(p)
        check_pipeline_status(p, statuses)
        output
    end

    def capture!(command)
        output = nil

        last_stdout, statuses = run_r!(command) do |last_stdout|
            output = last_stdout.read
        end

        [ output, statuses ]
    end

    def capture_i(input_string, command)
        output, statuses = capture_i!(input_string, command)
        check_command_process_status(command, statuses[0])
        output
    end

    def capture_i!(input_string, command)
        output, status = open3_run(:capture2, command, :stdin_data => input_string)
        [ output, [ status ] ]
    end

    private

    def capture2i(input_string, command)
        open3_run(:capture2, command, :stdin_data => input_string)
    end

    def open3_run(method, command, options = nil, &block)

        if block_given?
            Open3.send(
                method,
                *command.to_commands_sa(commands_formatter),
                options || new_spawn_options(command),
                &block
            )
        else
            Open3.send(
                method,
                *command.to_commands_sa(commands_formatter),
                options || new_spawn_options(command)
            )
        end
    end

    def check_pipeline_status(p, statuses)
        p.commands.zip(statuses) do |command, status|
            check_command_process_status(command, status)
        end
    end

    def check_command_process_status(command, process_status, msg = nil)
        if process_status.exited? and not process_status.success?
            raise CommandError.new(command, process_status, msg)
        end
    end

    def new_spawn_options(command)
        {
            :in => get_file_object(command.stdin).fileno,
            :out => get_file_object(command.stdout).fileno,
            :err => get_file_object(command.stderr).fileno
        }
    end

    def get_file_object(object)
        if object.kind_of?(IO)
            return object
        else
            return File.new(object.path, object.mode)
        end
    end
end

