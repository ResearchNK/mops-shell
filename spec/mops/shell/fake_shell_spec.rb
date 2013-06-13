require 'spec_helper'
require 'mops/shell/fake_shell'

describe FakeShell do

    it "can run a command" do
        expect do
            described_class.new.script do
                R double('command')
            end
        end.to_not raise_error
    end
    
    it "can capture a command output" do
        expect do
            o = described_class.new.script do
                Ci 'some_input', double('command')
            end
        end.to_not raise_error
    end
end
