use v6;

use Test;
use FileSystem::React;
use FileSystem::Helpers;

plan 2;

FileSystem::Helpers::temp-dir {
    my $out = '';
    my $err = '';
    react {
        my $dir = $*tmpdir;
        my @cmd = « $*EXECUTABLE -e 'say "A"' »;
        my $loop = FileSystem::React::Loop.new: @cmd, :watch($dir);
        whenever $loop.stdout.lines { $out ~= $_ }
        whenever $loop.stderr.lines { $err ~= $_ }
        once whenever $loop.ready {
            once whenever $loop.ready {
                my $subdir = $dir.add('sub');
                once whenever $loop.ready {
                    once whenever $loop.ready { done }
                    $subdir.add('B').spurt: 'some text'
                }
                mkdir $subdir;
            }
            $dir.add('A').spurt: 'some text';
        }
        whenever $loop.start { done }
        whenever Promise.in(2) {
            note 'timed out';
            $loop.kill;
            done;
        }
    }
    is $out, 'AAAA', 'stdout';
    is $err, '', 'stderr';
};

done-testing;

