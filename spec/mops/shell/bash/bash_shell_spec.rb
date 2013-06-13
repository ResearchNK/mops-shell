require 'spec_helper'
require 'mops/shell/bash/bash_shell'

describe BashShell do

    it "redirects a command output to /dev/null" do

        expect do
            described_class.new.script do
                R! (echo "Hello") > '/dev/null'
            end
        end.not_to raise_error
    end

    it "captures a command output to a variable" do
        test_string = "Hello!"
        output = nil

        described_class.new.script do
            output = C (echo '-n', test_string)
        end

        output.should eql test_string
    end

    it "captures a pipeline output to a variable" do
        output = nil

        described_class.new.script do
            output = C pipeline [
                (echo "\"one\ntwo\nthree\""),
                (grep "two")
            ]
        end

        output.should eql "two\n"
    end

    it "captures output of a command with a given input string" do
        test_string = "Hello!"
        output = nil

        described_class.new.script do
            output = Ci test_string, cat
        end

        output.should eql test_string
    end

    it "checks for file existence" do
        described_class.new.file_exists?('.').should be_true
        described_class.new.file_exists?(
            '/some/impossible/path/to/a/file'
        ).should be_false
    end

    context "a content file exists" do

        it "yields each line from file" do
            some_file = "/tmp/#{ described_class }.spec.1.#{ Process.pid }"
            some_content = 'some content'

            described_class.new.script do

                begin
                    R (echo '-n', some_content) > some_file
                    
                    c = nil

                    each_line_from_file(some_file) do |line|
                        c = line
                    end

                    c.should eql some_content

                ensure
                    R rm '-f', some_file
                end
            end
        end

        it "can set the file as standard input" do
            some_file = "/tmp/#{ described_class }.spec.2.#{ Process.pid }"
            some_content = 'some content'

            described_class.new.script do

                begin
                    R (echo '-n', some_content) > some_file
                    (C cat<some_file).should eql some_content
                ensure
                    R rm '-f', some_file
                end
            end

        end
    end

    context "file does not exist" do

        it "properly fails on reading lines from that file" do
            nonexisting_file = '/some/really/nasty/and/unlikely/to/exist/path'

            described_class.new.script do
                
                expect do
                    each_line_from_file(nonexisting_file) do |line|

                    end
                end.to raise_error(CommandError)
            end
        end
    end
end
 
