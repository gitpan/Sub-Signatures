#!/usr/bin/perl
# '$Id: 10sub_signatures.t,v 1.3 2004/12/05 21:19:33 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 8;
use Test::Exception;

my $CLASS;
BEGIN
{
#    $ENV{DEBUG} = 1;
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'Sub::Signatures';
    use_ok($CLASS) or die;
}

sub foo($bar) {
    $bar;
}

ok defined &foo, 
    'We can have subs with one argument';
is foo(3), 3,
    '... and it should behave as expected';

throws_ok {foo(1,2)}
    qr/\QCould not find a sub matching your signature: foo(SCALAR, SCALAR)\E/,
    '... and it should die with an appropriate error message';

sub bar($bar, $baz) {
    [$baz, $bar];
}

ok defined &bar,
    'We can have subs with multiple arguments';
is_deeply bar(1,2), [2,1],
    '... and it should also behave as expected';

sub baz($this, $that) { [$this, $that] } 

ok defined &baz,
    'We should be able to declare subs on one line';
is_deeply baz(1,2), [1,2],
    '... and they should still behave as expected';
