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
        my $subdir = $dir.add('sub');
        mkdir $subdir;
        my $file = $subdir.add('A');
        $file.spurt: 'some text';
        my @cmd = « $*EXECUTABLE -e 'say "A"' »;
        my $loop = FileSystem::React::Loop.new: @cmd, :watch($dir);
        whenever $loop.stdout { $out ~= $_ }
        whenever $loop.stderr { $err ~= $_ }
        once whenever $loop.ready {
            $file.spurt: 'x', :append;
        }
        whenever $loop.start { done }
        whenever Promise.in(2) {
            note 'timed out';
            $loop.kill;
            done;
        }
    }
    cmp-ok $out, '~~', /[A\n] ** 2..*/, 'stdout';
    cmp-ok $err, '~~', /FileChanged: \S*/, 'stderr';
};

done-testing;

