use v6;

use Test;
use FileSystem::React;
use FileSystem::Helpers;

plan 2;

FileSystem::Helpers::temp-dir {
    my $out = '';
    my $err = '';
    react {
        my $signals = SIGHUP.join(SIGINT).join(SIGTERM);
        my @cmd = « $*EXECUTABLE -e 'say "A"' »;
        my $loop = FileSystem::React::Loop.new: @cmd, :watch($*tmpdir);
        whenever $loop.stdout.lines { $out ~= $_ }
        whenever $loop.stderr.lines { $err ~= $_ }
        whenever Promise.in(0.25) {
            my $dir = $*tmpdir;
            $dir.add('test').spurt: 'here is some text';
            whenever Promise.in(0.25) {
                note 'timed out';
                $loop.kill;
                done;
            }
        }
        once whenever $signals {
            $loop.kill: SIGHUP;
            whenever $signals { $loop.kill: $_ }
        }
        whenever $loop.start { done }
    }
    is $out, 'AA', 'stdout';
    is $err, '', 'stderr';
};

done-testing;

