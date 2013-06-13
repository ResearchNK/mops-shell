require 'open3'

class CommandError < StandardError
    attr_reader :command
    attr_reader :process_status
    
    def initialize(command, process_status = nil, msg = nil)
        super(msg)
        @command = command
        @process_status = process_status
    end

    def to_s
        s = String.new
    
        if @msg
            s << "#{ @msg }\n"
        end
        
        s << "Command: '#{ @command.to_s }'"

        if @process_status.respond_to?(:exitstatus)
            s << ", exit status: #{ @process_status.exitstatus }"
        end

        return s
    end
end

#
# A command represents a building block in a builder pattern, but without an
# actual "build" method in the end. Building (execution) is moved to another
# concept, named "a command runner", because there might be different ways to
# run the same command, which itself should be treated more like an abstract
# prescription or a minimal set of information needed for any form of execution.
#
# @note Ideally, every node in the chain should return a new chain and do not
#   modify the previous node (nodes should be immutable). I didn't manage to
#   achieve this, so the chain is constructed "in place", meaning that for
#   example adding an stdout object to a command does not generate a new command.
#   Instead, an internal state of the command is affected. Sad but true, I
#   struggled too much with the language limitations, including inconsistent 
#   ruby objects freezing concept and no real built in immutability mechanisms
#   (like for example in Scala).
#
# @abstract
#
class AbstractCommand

    #
    # A duck type that responds to a minimal subset of the IO object methods,
    # used for wrapping string paths together with file opening mode.
    #
    # @private
    #
    class RedirectionDefinition
        attr_reader :path
        attr_reader :mode

        def initialize(path, mode)
            @path = path
            @mode = mode
        end
    
        def to_s
            "('#{ path }', '#{ mode }')"
        end
    end

    attr_reader :stdin
    attr_reader :stdout
    attr_reader :stderr

    def initialize
        @stdin = STDIN
        @stdout = STDOUT
        @stderr = STDERR
    end

    #
    # This is a general redirection method. It sets the configuration of the
    # command, so that it is possible for the command runner to perform an
    # appropriate outputs redirections. It will probably be rarely used in
    # scripts, because of the existence of other, more convinient sugars
    # described in this class.
    #
    # @note This is not a simple setter. The information is wrapped into a more
    #   general structure if necessary, depending on whether you specify a String
    #   or an IO object. An actual file is created at command execution, not at
    #   the moment of calling this method.
    #
    # @param [String, IO] to_object where to redirect, can be either path to a
    #   file or an IO object. Not all operations make sense on every IO object,
    #   so be aware of possible unexpected behaviour when you inject an invalid
    #   IO object.
    #
    # @param [Fixnum] from_descriptor a descriptor number indicating, which
    #   descriptor should be the redirection performed from. Currently,
    #   only two values are supported, 1 for stdout and 2 for stderr. 
    #
    # @param [String] mode file opening mode, can be either 'w' or 'a'.
    #
    # @return self
    #
    def redirect!(to_object, from_descriptor, mode = 'w')

        case from_descriptor
            when 0 then stdin!(
                get_redirection_definition_object(to_object, mode)
            )
            when 1 then stdout!(
                get_redirection_definition_object(to_object, mode)
            )
            when 2 then stderr!(
                get_redirection_definition_object(to_object, mode)
            )
            else raise "Redirecting from descriptor #{
                from_descriptor
            } not supported"
        end
    end

    #
    # This method redirects commands output to a file in a write mode (the
    # contents of the file will be wiped).
    #
    # @param [String, IO] object Either path or an IO object 
    # @param [Fixnum] fd file descriptor number
    #
    # @return self
    #
    # @see #redirect!
    #
    def >(object, fd = 1)
        redirect!(object, fd, 'w')
    end


    #
    # This method redirects commands output to a file in an append mode.
    #
    # @param [String, IO] object Either path or an IO object
    # @param [Fixnum] fd file descriptor number
    #
    # @return self
    #
    # @see #redirect!
    #
    def >>(object, fd = 1)
        redirect!(object, fd, 'a')
    end

    #
    # This method redirects commands input to a file in a read only mode.
    #
    # @param [String, IO] object Either path or an IO object
    #
    # @return self
    #
    # @see #redirect!
    #
    def <(object)
        redirect!(object, 0, 'r')
    end

    #
    # Sets stdout without any processing.
    #
    # @note We don't use ruby standard setting method, since '=' must return the
    #   value set and we want to return self, because we're implementing a
    #   builder pattern.
    # 
    # @return self
    #
    def stdout!(stdout)
        @stdout = stdout
        self
    end

    #
    # Sets stdin without any processing.
    #
    # @note We don't use ruby standard setting method, since '=' must return the
    #   value set and we want to return self, because we're implementing a
    #   builder pattern.
    # 
    # @return self
    # 
    def stdin!(stdin)
        @stdin = stdin
        self
    end

    #
    # Sets stderr without any processing.
    #
    # @note We don't use ruby standard setting method, since '=' must return the
    #   value set and we want to return self, because we're implementing a
    #   builder pattern.
    # 
    # @return self
    # 
    def stderr!(stderr)
        @stderr = stderr
        self
    end

    private

    #
    # @param [ String, IO ] object
    #
    # @param [ String ] mode file opening mode
    #
    # @return [ #path, #mode ]
    #
    def get_redirection_definition_object(object, mode)
        if object.kind_of?(IO)
            return object
        else
            return RedirectionDefinition.new(object, mode)
        end 
    end
end

#
# A shell command, it has it's name and arguments in addition to everything the
# abstract command has.
#
class ShellCommand < AbstractCommand
    attr_reader :name
    attr_reader :args
    @block

    def initialize(name, *args, &block)
        super()
        @name = name
        @args = args
        @block = block
    end

    #
    # This method is used to present the command in a form that is easier
    # consumable by a command runner.
    #
    # @return [Array<String>] commands in a form of strings. This array will
    #   contain only one element, of course.
    #
    def to_commands_sa(formatter)
        return [ formatter.to_command_s(self) ]
    end

    #
    # There are situations, where we would like to look at a command as we look
    # at a pipeline with a single command in it.
    #
    # @note Every shell command can be seen as a pipeline, but not every
    #   pipeline can be seen as a command, so this is not a bijective function.
    #
    # @see Pipeline
    #
    def to_pipeline
        p = Pipeline.new([ self ])
        p.stdin!(self.stdin)
        p.stdout!(self.stdout)
        p.stderr!(self.stderr)
    end

    def to_s
        s = ''

        s << @name.to_s
        
        if @args.size > 0
            s << " " + @args.map do
                |a| "#{ a }"
            end.join(" ")
        end
        
        return s
    end
end

#
# Pipeline is a kind of an abstract command. It may be executed, it has it's own
# stdin and stdout concepts. Pipeline holds one or more shell commands connected
# by a stdout-to-stdin chain.
#
class Pipeline < AbstractCommand
    attr_reader :commands

    def initialize(commands)
        super()
        @commands = commands
    end

    def to_commands_sa(formatter)
        return @commands.map do |c|
            formatter.to_command_s(c)
        end
    end

    def to_pipeline
        self
    end
end

