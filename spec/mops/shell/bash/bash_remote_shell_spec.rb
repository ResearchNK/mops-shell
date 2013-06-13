require 'spec_helper'
require 'mops/shell/bash/bash_remote_shell'

describe BashRemoteShell do

    def default_host
        'some_host'
    end

    def default_user
        'some_user'
    end

    # do not mock objects you don't owe ;-)
    def ssh_channel_mock
        channel = described_class::FakeChannel.new
        ssh = double('ssh')
        ssh.stub(:open_channel).and_yield(channel).and_return(channel)
        Net::SSH.stub(:start).and_yield(ssh)
        channel
    end

    it "uses ssh channel for capturing output of a remote command" do
        channel = ssh_channel_mock

        input = 'some input'
        output = nil

        channel.stub(:output_data).and_return(input)
        channel.should_receive(:eof!)
        channel.should_receive(:send_data).with(input)

        described_class.new(default_host, default_user).script do
            output = Ci input, cat
        end

        output.should eql input
    end

    context "a content file exists" do

        it "yields each line from file" do
            some_file = "/tmp/#{ described_class }.spec.#{ Process.pid }"
            some_content = 'some content'
            channel = ssh_channel_mock

            described_class.new(default_host, default_user).script do

                begin
                    R (echo '-n', some_content) > some_file
                    
                    c = nil

                    channel.stub(:output_data).and_return(some_content)
                    each_line_from_file(some_file) do |line|
                        c = line
                    end

                    c.should eql some_content

                ensure
                    channel.stub(:output_data).and_return(nil)
                    R rm some_file
                end
            end
        end
    end
end
