require 'mops/shell/shell_session_module'
require 'mops/shell/command'

#
# This module delivers unix-specific commands in a shell session.
#
module UnixShellModule

    #
    # mix common methods for a shell session module
    #
    include ShellSessionModule

    class << self

        def register_shell_command(command_sym)
            define_method command_sym do |*args, &block|
                ShellCommand.new(command_sym, *args, &block)
            end
        end

        def register_common_methods

            common_methods = [
                :alias,
                :awk,
                :bc,
                :cat,
                :chmod,
                :chown,
                :cp,
                :cut,
                :date,
                :df,
                :diff,
                :du,
                :echo,
                :export,
                :find,
                :grep,
                :gzip,
                :head,
                :kill,
                :ls,
                :mkdir,
                :mv,
                :patch,
                :ps,
                :pwd,
                :readlink,
                :rm,
                :rmdir,
                :sed,
                :sudo,
                :tar,
                :scp,
                :source,
                :tail,
                :umask,
                :uptime,
                :wc,
                :whereis
            ]

            common_methods.each do |m|
                register_shell_command(m)
            end
        end
    end

    register_common_methods # my "static" constructor, harmless ;p
end

