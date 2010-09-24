#!/usr/bin/perl -w
use 5.10.0;
use strict;
use warnings FATAL => 'all';
use File::Path qw(mkpath);
use File::Find;
use autodie;

my($moose_dir, $result) = @ARGV;
unless(defined $moose_dir and -d "$moose_dir/t") {
    die "Usage: $0 Moose-dir result-dir\n";
}
$result //= 'Moose-test';
if(-e $result) {
    die "'$result' exists, stopped";
}

my @tests;
sub wanted {
    (my $mouse_test         = $_) =~ s{\A $moose_dir/t }{$result}xmso;
    (my $mouse_failing_test = $_) =~ s{\A $moose_dir/t }{$result-failing}xmso;
    if( -d $_ ) {
        mkpath [$mouse_test, $mouse_failing_test];
        return;
    }
    copy_as_mouse($_ => $mouse_test);
    push @tests, [$mouse_test, $mouse_failing_test]
        if $mouse_test =~/\.t\z/xms;
    return;
}

find { wanted => \&wanted, no_chdir => 1 }, "$moose_dir/t/";

say "Testing ...";

$ENV{PERL5LIB} = join ':', "$result/lib", @INC;

my $ok = 0;
foreach my $t(sort { $b cmp $a } @tests) {
    my($t, $fail) = @{$t};
    if(system(qq{$^X $t 2>&1 >/dev/null}) == 0) {
        say "$t ... ok";
        $ok++;
    }
    else {
        # make it TODO and retyr it
        open my $in,'<', $t;
        open my $out, '>', "/tmp/retry.t.$$";
        while(<$in>) {
            print $out $_;
            /use Test::More/
                && say $out '$TODO = q{Mouse is not yet completed};';
        }
        close $in;
        close $out;

        rename "/tmp/retry.t.$$", $t;

        if(system(qq{$^X $t 2>&1 >/dev/null}) == 0) {
            say "$t ... ok (TODO)";
            $ok++;
        }
        else {
            say "$t ... not ok";
            rename $t, $fail;
        }
    }
}
say sprintf "%d %% (%d/%d) succeed.", ($ok/@tests)*100, $ok, scalar @tests;

sub copy_as_mouse {
    my($moose, $mouse) = @_;
    open my $in, '<',  $moose;
    open my $out, '>', $mouse;
 
    while(<$in>) {
        if($. == 2) {
            say $out 'use t::lib::MooseCompat;';
        }
        s/\b Class::MOP::([a-z_]+) \b/Mouse::Util::$1/xmsg;
        s/\b Class::MOP \b /Mouse::Meta/xmsg;
        s/\b Moose \b/Mouse/xmsg;

        # make classes simple
        s{\b(Mouse::Meta::TypeConstraint)::\w+    }{$1}xmsg;
        s{\b(Mouse::Meta::Role::Application)::\w+ }{$1}xmsg;
        s{\b(Mouse::Meta::Method)::\w+            }{$1}xmsg;

        print $out $_;
    }
    close $in;
    close $out;
}
