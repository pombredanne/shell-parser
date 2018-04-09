#!/usr/bin/perl
use 5.16.0;
use warnings FATAL => 'all';

use Test::Simple tests => 17;
use IO::Handle;

my $cmd = "./parse";

system("mkdir -p tmp");

my @scripts = glob("tests/*.sh");

for my $script (@scripts) {
    system("rm -f tmp/raw tmp/output");
    system("timeout 5 $cmd < $script > tmp/raw");

    my $correct = $script;
    $correct =~ s/\.sh$/.out/;
    system("cp $correct tmp/expect");

    my $output = `cat tmp/raw`;
    $output =~ s/^\w+\$\s*//mg;
    open my $fh, ">", "tmp/output";
    $fh->print($output);
    close $fh;

    my $diff = `diff tmp/expect tmp/output`;

    ok($diff eq "", $script);
    if ($diff ne "") {
        $diff =~ s/^/# /mg;
        print $diff;
    }
}

sub check_errors {
    my ($errs) = @_;
    chomp $errs;
    if ($errs ne "") {
        $errs =~ s/^/# /mg;
        warn $errs;
        return 0;
    }
    else {
        return 1;
    }
}

sub clang_check {
    my $errs = `clang-check -analyze *.c --`;
    return check_errors($errs);
}

sub valgrind() {
    system(qq{valgrind -q --leak-check=full --log-file=valgrind.out ./parse < tests/02-echo-twice.sh > /dev/null});
    return `cat -n valgrind.out` eq "";
}


ok(clang_check(), "clang check");
ok(valgrind(), "valgrind");

my $procs = `ps | grep memcheck`;
chomp $procs;

ok($procs eq "", "no stray processes after tests");
if ($procs ne "") {
    system("killall memcheck-amd64-");
}

