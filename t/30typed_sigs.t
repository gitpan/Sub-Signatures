#!/usr/bin/perl
# '$Id: 30typed_sigs.t,v 1.1 2004/12/05 03:02:01 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 10;
use Test::Exception;

my $CLASS;
BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
    $CLASS = 'Sub::Signatures';
    use_ok($CLASS, 'strict') or die;
}

sub foo(ARRAY $bar) {
    return sprintf "arrayref with %d elements" => scalar @$bar;
}

sub foo(HASH $bar)
{ $bar->{this} = 1; $bar }

ok defined &foo, 
    'We can have typed subs with one argument';
is foo([6,6,6]), "arrayref with 3 elements",
    '... and they should behave as expected';

throws_ok {foo(0)}
    qr/Could not find a sub matching your signature/,
    '... but it will die if the signature does not match';

is_deeply foo({ that => 2}), {this => 1, that => 2},
    '... and we can even specify different types.';

sub bar($bar) {
    $bar;
}

ok defined &bar,
    'We do not have to specify the type if it is a scalar';
throws_ok {bar([qw/an array ref/])}
    qr/Could not find a sub matching your signature/,
    '... but we had better not pass a non-scalar to it';

sub match($bar, Regexp $foo) {
    return $bar =~ $foo;
}

sub match(ARRAY $bar, Regexp $foo) {
    return @$bar == grep $_ =~ $foo => @$bar;
}

ok match('this', qr/hi/),
    '... and we can overload the methods as much as we like';

ok !match('this', qr/ih/),
    '... and we can overload the methods as much as we like';

ok match([qw/this hi hit thistle/], qr/hi/),
    '... and sweet, sweet function overloading is ours at last';
