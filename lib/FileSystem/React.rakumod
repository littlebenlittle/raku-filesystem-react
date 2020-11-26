
unit package FileSystem::React:auth<github:littlebenlittle>:ver<0.0.0>;

use Grammars::QuotedTerms;

class Loop {
    has Str:D    @.cmd   is required;
    has IO::Path $.watch is required;
    has Supplier:D $!kill   = Supplier.new;
    has Supplier:D $!reset  = Supplier.new;
    has Supplier:D $!stdout = Supplier.new;
    has Supplier:D $!stderr = Supplier.new;
    has Supplier:D $!ready  = Supplier.new;
    submethod BUILD(:@!cmd, :$!watch) { }
    method new(@cmd, IO() :$watch is required) {
        self.bless(:@cmd, :$watch)
    }
    method start (-->Promise)  {
        Promise.start: {
            my $continue = True;
            while $continue {
                react {
                    my $proc = Proc::Async.new: @.cmd;
                    my $watch = establish-watches $.watch;
                    whenever $!reset.Supply { $proc.kill: $_ }
                    whenever $!kill.Supply { 
                        $continue = False;
                        $proc.kill: $_;
                    }
                    whenever $watch {
                        $!stderr.emit: "{$_.event}: {$_.path}";
                        $.reset;
                    }
                    whenever $proc.stdout { $!stdout.emit: $_ }
                    whenever $proc.stderr { $!stderr.emit: $_ }
                    note "# Running:   {@.cmd.join: ' '}" if $*verbose;
                    whenever $proc.start {
                        note "# exited {.exitcode}" if $*verbose;
                        done unless $continue;
                        whenever $watch {
                            done
                        }
                        whenever $!reset.Supply { done }
                        whenever $!kill.Supply {
                            $continue = False;
                            done
                        }
                    }
                    whenever Promise.in(0.25) {
                        $!ready.emit: Any;
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
    method ready  { $!ready.Supply }
}

sub establish-watches(IO::Path $target) {
    note "# Establishing watches for: {$target.absolute}" if $*verbose;
    my $watch = $target.watch;
    if $target.d {
        $watch .= merge(establish-watches($_)) for $target.dir;
    }
    return $watch;
}

#| Run a command each time a directory or file changes
sub MAIN(
    Str:D $cmd;           #= command to run
    IO() :$dir = $*CWD;   #= target to watch
    Bool :$*verbose;      #= enable verbose output
) is export(:MAIN) {
    say "Watching $dir";
    my Str:D @cmd =
        Grammars::QuotedTerms.parse($cmd).made
        // die "cannot parse as command: $cmd" unless @cmd;
    my $loop = FileSystem::React::Loop.new: @cmd, :watch($dir);
    react {
        my $signals = signal(SIGHUP, SIGINT, SIGTERM);
        whenever $loop.stdout.lines { .say  }
        whenever $loop.stderr.lines { .note }
        once whenever $signals {
            $loop.kill: SIGHUP;
            whenever $signals { $loop.kill: $_ }
        }
        whenever $loop.start { done }
    }
}

