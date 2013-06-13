
#
# A base class for shells sessions. Not required, but used to avoid some
# copypasterism.
#
class ShellSession

    def initialize(params = {})
        extend params[:commands_runner_module]
        extend params[:shell_session_module]
        extend params[:shell_sugars_module]
        @commands_formatter = params[:commands_formatter] or raise ArgumentError
    end

    private

    attr_reader :commands_formatter
end

