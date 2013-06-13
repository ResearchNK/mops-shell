# mops-shell

## Introduction

mops-shell is a layer between ruby and system shell (like bash for example). It
may be thought as a powerfull way of running system commands on both local and
remote machines.

Main features:

* ruby based DSL - so it's easy to extend
* support for bash-like syntax
* error checking - you can catch exceptions on a command failure, instead of
checking the exit status at each line
* [DRY](http://en.wikipedia.org/wiki/Don%27t_repeat_yourself) principle in mind -
you write your script once and run it against different shells
* both local and remote executions
* testable - you can actually write real unit tests for your bash-like scripts

## Installation

Install the dependencies:

``` bash
$ sudo gem install net-ssh
$ sudo gem install iron-extensions
```

Checkout the project using git, enter it and build the gem.

``` bash
$ gem build mops-shell.gemspec
```

Then install it using `gem install`.

This installation method will change to simple `gem install mops-shell` as soon
as I push the mops-shell to a public domain gem repository (rubygems.org
probably).

## Usage

### Hello world!

Let's start from a classic "Hello world!" example:

``` ruby
require 'mops/shell/bash'

shell = BashShell.new

shell.script do
    R echo "Hello world!"
end
```

So, what's going on here and why not just write simple `puts`?

First of all, the script actually fires up a system `echo` command with `"Hello
world!"` as an argument. But it is still ruby code, so to be more precise, what
we actually do is:

``` ruby
shell.script do
    R(echo("Hello world!"))
end
```

but we can avoid the parentheses thanks to ruby's right-most evaluation
convention. From this, you might guess, that `R` is a function that provokes the
actual command execution, so we might as well write:

``` ruby
shell.script do
    command = echo "Hello world!"
    R command
end
```

Why not fire up the command implicitly when created? Two main reasons:

* avoid side effects
* allow commands to be run differently

As you may argue with the first bullet point, the second has a lot more of power.
Consider another example:

``` ruby
contents = nil

shell.script do
    contents = C cat 'some_file'
end

puts contents
```

This should be self-explaining, the `C` function does not simply run command,
but also returns it's output as a ruby string. You can already see the power of
this approach, we can execute some code in the script context, but still have
access to the ruby closure.

If you know ruby well, you might wonder, how is this even possible? The block
evaluation is clearly done in some other scope (you won't find `C` or `cat`
methods outside of the block), but we still are able to communicate with the
current binding somehow. This magic is hidden by a great extension written by
[Rob Morris](https://github.com/irongaze), called
[DslProxy](https://github.com/irongaze/iron-extensions/blob/master/lib/iron/extensions/dsl_proxy.rb). You can find it on github, in the
[iron-extensions](https://github.com/irongaze/iron-extensions) gem, which is
currently one of the two gems required by mops-shell (the other is
[net-ssh](http://net-ssh.github.io/net-ssh/)).

But let's start with a failure case, because it's far more interesting. What
will happen, if the file does not exist? Well, a {CommandError} will be raised!
We can deal with this situation in two ways. If we consider this as a very
unlikely situation, we're leaving with what's written, but **we still are able
to trace the problem if it occurs. This actually was the primary reason to
"reimplement" bash with `mops-shell`**, so to say. Nevertheless, we've got some
more options. We can catch the exception:

``` ruby
shell.script do
    begin
        contents = C cat 'some_file'
    rescue CommandError
        STDERR.puts 'Error while executing cat'
    end
end
```

Poor cat! We can check the file existence in the first place. Notice the
`file_exists?` method available. Check out some other helpful stuff in
{BashShellModule} and appreciate, you can not only write `file_exists?` instead
of struggling with bash nasty [file
tests](http://tldp.org/LDP/abs/html/fto.html), but you can easily write your own
extensions.

``` ruby
shell.script do

    if file_exists?('some_file')
        contents = C cat 'some_file'
    else
        puts "File does not exist"
    end
end
```

The last thing is to avoid automatic error checking and test the exit status by
yourself. Again notice, we're not using the `C` method anymore, instead we're
using another execution method, `C!`:

``` ruby
shell.script do
    contents, statuses = C! cat 'some_file'
    puts "Command exit status was: #{ statuses[0].exitstatus }"
end
```

Two questions might appear here. First of all, why multiple statuses are
returned, and why they are more complex structures than simple integers? The
first issue will become easier to grasp with a simple example of pipelining:

``` ruby
shell.script do

    statuses = R! pipeline [
        (echo "\"one\ntwo\""),
        (awk "'/two/ { print $0 } END { exit 1 }'"),
        cat
    ]

    statuses.each_with_index do |s, i|
        puts "#{ i } - exit status: #{ s.exitstatus }"
    end
end
```

When run, you will see an output similar to the one below:

    two
    0 - exit status: 0
    1 - exit status: 1
    2 - exit status: 0

Notice, that you have to use parentheses to avoid ambiguity when constructing an
array of commands.

Also, it is up to you to escape white-spaced arguments (I find any default
behaviour very misleading here) and any special characters used by the external
commands. Try to figure out, why this:

``` ruby
shell.script do
    R echo "$SHELL"
end
```

this:

``` ruby
shell.script do
    R echo '$SHELL'
end
```

and this:

``` ruby
shell.script do
    R echo '"$SHELL"'
end
```

will result in echoing expanded value (`/bin/bash` for example), and this:

``` ruby
shell.script do
    R echo "'$SHELL'"
end
```

will print `$SHELL` literally. Once you catch where the ruby declarations and
substitutions end and the shell expansions start, the "magic" will become a
triviality.

I consider varying return types from a function a very bad pattern, which is
easy to commit when using a dynamic language. This is why I prefer for example
the `C!` method to always return the same structure, whether it is called over a
single command or a pipeline. Moreover, for example capturing from a pipeline
with an input provided using `Ci!` is not yet implemented in `mops-shell`, but
it probably will be soon, and no change to old scripts will be necessary. We (or
You) can always write another running method, call it differently, sugar it in
some way and return some other, maybe less generic, but shorter to use
structure. It's quite easy.

The return status object tries to preserve ruby `Process::Status` interface. In
fact, when local shell is used, it is an object of this class. This will allow
for some deeper inspection on the processes (for example, you can extract pid
from it). However, you should not assume it won't change in the future, so don't
try to do any `instance_of?` or `kind_of?` programming. Use the interface.
Moreover, the only response guaranteed is `#exitstatus`. Others are optional.
 
### Providing a command input

To provide something to the standard input of the command, and then capture it's
output, you could write something like this:

``` ruby
shell.script do
    result = C pipeline [
        (echo "2+2"),
        bc
    ]
end
```

There is also a shortcut for this:

``` ruby
shell.script do
    result = Ci "2+2\n", bc
end
```

There are also more advanced options, read about redirections.

### Redirections

``` ruby
shell.script do
    R (echo 'some text') > 'some_file'
end
```

Why the parentheses? The evaluation is as follows:

1. create a command using method `echo` with `'some text'` as it's one and only
  argument
2. on that command invoke method `>` with `'some_file'` as an argument. What it
  does, is setting a redirection definition on the command, which stores the
  path to a file and opening mode. As you may expect from a common `>` symbol
  usage, the opening mode here is 'w' (see ruby `IO` class for more details).
3. run the command

To append to a file, use:

``` ruby
shell.script do
    R (echo 'some text') >> 'some_file'
end
```

The `>` and `>>` methods are just sugars for calling a `redirect!` method (see
{AbstractCommand}):

``` ruby
f = File.new('yet_another_file', 'w')

shell.script do
    R (echo "some text").redirect!(f, 1)
end
```

The first argument can be either an IO or a String object, the second argument
indicates, which descriptor to redirect (0 is for stdin, 1 for stdout and 2 for
stderr). The third argument (ommited here) is an opening mode required if the
first argument is a String only. If don't specify it, an error will raise when
trying to run the built command.

You can also set stdin, stdout and stderr directly, using `#stdin!`, `#stdout!`
and `#stderr!` methods, for example:

``` ruby
shell.script do
    R! (cat "some_non_existing_file").stderr!(STDOUT)
end
```

Is quite equivalent to bash:

``` bash
cat some_non_existing_file 2>&1
```

Notice the exclamation mark next to `R`, which prevents the command runner
from raising an error and just returns status, which will be 1 in this case.

You can also set stdin:

``` ruby
shell.script do
    R cat < 'some_file'
end
```

Of course not every combination of IO objects and examples showed here makes
sense. For example, you could set an output to a file opened in read only mode.
Although this will result in error when run, there may be some other nonsense
usages in which the final behavior may be undefined.

### Yielding commands

Some commands make use of blocks. Consider this example:

``` ruby
shell.script do
    each_line_from_file('some_file') do |line|
        puts line
    end
end
```

Of course, this is not a simple wrapper on ruby `File#each`, because it would be
pointless to use mops-shell, when this would be applicable. Instead, imagine
that this code will also work, when the shell is a remote ssh shell. However,
because of some ssh and multithreaded programming issues, I didn't manage to
implement `each_line_from_file` in streaming mode - the content of the file is
read at once into memory and then lines are yielded one after another, so this
should be used for small files only. For larger files, consider another
approach (ruby is not suitable for processing large files line-by-line anyway).

### Remote shell scripting

Why should we use `echo` anyway? And why not use ruby's
`File.exist?(file_name)`? Well, get this, you can actually write:

``` ruby
require 'mops/shell/bash/bash_remote_shell'

shell = BashRemoteShell.new('host', 'user')

shell.script do
    # no need to change scripts here
end
```

So you can write any script in a closure and inject a shell. It doesn't have to
be local (I put some effort to implement {SSHCommandRunnerModule}). The ruby
code is, of course, evaluated locally, but the remote machine does not have to
have ruby installed at all, it just has to have bash.

### Registering more commands

Only a limited set of commands is available by default. It will expand, but I
didn't want to generate the commands on demand. I find programming by
`method_missing` very confusing and hard to debug. So, for example, to make a
command `yes` visible to a bash shell session, register it with
{UnixShellModule}:

``` ruby
UnixShellModule.register_shell_command(:yes)
```

This requires `yes` to be at least available on system `$PATH`. You can also
provide an arbitrary path instead of a symbol, but probably quoted, if it
contains whitespaces. For those, who really like going custom, here is the
source of that method.

``` ruby
def register_shell_command(command_sym)
    define_method command_sym do |*args, &block|
        ShellCommand.new(command_sym, *args, &block)
    end
end
```

As you can see, every time you call a command method, a new object is created,
with command arguments stored. You can also create shell commands more locally
and manually using `ShellCommand.new` directly.

## Testing your scripts

You do find the lack of ability to test shell scripts an issue, right? Now,
testing shell still remains a tricksy thing. We cannot just stub some command,
since it doesn't actually perfom the action. Stubbing the execution methods is
also insufficient, because we want to perform tests in an isolated environment,
so we would need something like a fake shell, we want to run our script on, put
some expectations on it, how it should behave and verify, whether it conforms or
not without actually invoking real system commands.

Here I'm proposing one solution to this issue, but I'm also RFC. 

Let's look at a simple example:

``` ruby
class A
    attr_reader :shell

    def initialize(shell)
        @shell = shell
    end

    def foo(some_condition)

        shell.script do
            R echo 'Running a script...'

            if some_condition
                R echo 'The condition was true!'
            end
        end
    end
end
```

First of all: always allow to inject shells. If you don't want to pass them as
parameters to the instance method, make them an instance variables, but always
be able to easily use their mocked version to put expectations on in some way. 

Now, let's write some spec for this class

``` ruby
require 'spec_helper'
require 'mops/shell/fake_shell'
require 'a'

describe A do

    context "the condition is true" do

        it "runs echo confirming the condition is true" do
            shell = FakeShell.new
            command1 = double('command1')
            command2 = double('command2')

            # we have to stub all echos because of the way rspec works
            shell.should_receive(:echo).
                with('Running a script...').
                and_return(command1)

            # expect an echo command to be created with a specific argument
            shell.should_receive(:echo).
                with('The condition was true!').
                and_return(command2) 

            # expect the above commands to be run by the R method in an
            # order
            shell.should_receive(:R).with(command1).ordered
            shell.should_receive(:R).with(command2).ordered

            described_class.new(shell).foo(true)
        end 
    end

    context "the condition is false" do

        it "does not run echo about the condition" do
            shell = FakeShell.new

            # no need for stubbing other echos because of the inverted
            # logic. All we have to do is to put a constraint on the
            # command's argument.
            shell.should_not_receive(:echo).with('The condition was true!')
            described_class.new(shell).foo(false)
        end 
    end
end
```

Notice the {FakeShell} usage and how we put expectations on the flow. Also the
famous Hitler's "from now on, I want every line of code to have 10 lines of code
to test it" pattern application...

## Additional information

### List of sugars

* For a list of common sugars that are used for running commands, see
{ShellSugarsModule}.
* For a list of sugars used to construct commands itself, see {AbstractCommand}.

### List of commands available by default

Check out the source of `register_common_methods` in {UnixShellModule}.

### Ruby based DSL

Why haven't I created a language from scratch? Doesn't DSL coolness rely on it's
own constraints, like in, for example, a template language in a MVC framework?
Let's face it - bash tried to evolve from a high level and simple to a general
purpose language. Was this inevitable? Yes. Was this successful? No. Let's not
make this mistake again. We don't have any security issues here. We should allow
programmers to make fast hacks (ruby style) on the framework if we don't expect
ourselves to foresee every potential stuck point we could get into when using a
DSL. The DSL may expand, but sometimes it may be just too late - a business
opportunity is wasted. Let's not try to be smarter than any future software
community (and yes, closed classes and so called "encapsulation by using private
sections just to hide some nasty code we've written" is bad :P).

### Builder pattern application

A careful observer will notice, that commands are actually constructed, then
executed, which somehow reminds both the command programming pattern (partially)
and the builder pattern. At least for now, one cannot assume commands
immutability. So they are constructed in-place, then the final "build"
invocation is moved to another responsible party called a command runner.
Command object does not know how to execute itself, it's more like an advanced
structure of parameters needed by those, who can use them to make an actual
execution.

### Impact in a distributed environment

`mops-shell` offers a complementary approach to the one presented by `puppet` for
example - we don't distribute code, we have it centralized and we're telling
others what to do, but with an easier way to handle errors (no more
checking-the-exit-status every line), especially when it comes to executing
remote commands. `mops-shell` is a module used by another project I'm working
on, which is an experimental approach to business processes modelling and
handling. More on this soon, I hope!

## Contributing and bugs reporting

Please, contact me first.

## Author

Konrad Procak
