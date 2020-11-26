
unit package FileSystem::React:auth<github:littlebenlittle>:ver<0.0.0>;

class Loop {
    has Str:D    @.cmd   is required;
    has IO::Path $.watch is required;
    has Supplier:D $!kill   is required;
    has Supplier:D $!reset  is required;
    has Supplier:D $!stdout is required;
    has Supplier:D $!stderr is required;
    submethod BUILD(:@!cmd, :$!watch) {
        $!kill   = Supplier.new;
        $!reset  = Supplier.new;
        $!stdout = Supplier.new;
        $!stderr = Supplier.new;
    }
    method new(@cmd, IO() :$watch is required) {
        self.bless(:@cmd, :$watch)
    }
    method start (-->Promise)  {
        Promise.start: {
            my $continue = True;
            my $count = 0;
            while $continue {
                $count++;
                my $watch = IO::Notification.watch-path: $.watch;
                react {
                    my $proc = Proc::Async.new: @.cmd;
                    my $done = False;
                    whenever $watch { $.reset }
                    whenever $proc.stdout { $!stdout.emit: $_ }
                    whenever $proc.stderr { $!stderr.emit: $_ }
                    whenever $!reset.Supply { $proc.kill: $_ }
                    whenever $!kill.Supply { 
                        $continue = False;
                        $proc.kill: $_;
                    }
                    whenever $proc.start {
                        done unless $continue;
                        whenever $watch { done }
                        whenever $!reset.Supply { done }
                        whenever $!kill.Supply {
                            $continue = False;
                            done
                        }
                    }
                }
            }
        };
    }
    multi method kill { callwith SIGINT }
    multi method kill($signal) { $!kill.emit: $signal }
    multi method reset { callwith SIGINT }
    multi method reset($signal) { $!reset.emit: $signal }
    method stdout { $!stdout.Supply }
    method stderr { $!stderr.Supply }
}

#| Run a command each time a directory or file changes
sub MAIN(
    Str:D $cmd;           #= command to run
    IO() :$dir = $*CWD;   #= target to watch
) is export(:MAIN) {
    say "Watching $dir";
    my @cmd = $cmd.split: /\s+/;
    my $loop = FileSystem::React::Loop.new: @cmd, :watch($dir);
    react {
        my $signals = SIGHUP.join(SIGINT).join(SIGTERM);
        whenever $loop.stdout.lines { .say }
        whenever $loop.stderr.lines { .note }
        once whenever $signals {
            $loop.kill: SIGHUP;
            whenever $signals { $loop.kill: $_ }
        }
        whenever $loop.start { done }
    }
}

