#!/usr/bin/perl
# '$Id: 70subclassing.t,v 1.1 2004/12/05 21:19:33 ovid Exp $';
use warnings;
use strict;
#use Test::More 'no_plan';
use Test::More tests => 16;
use Test::Exception;

my $CLASS;
BEGIN
{
#    $ENV{DEBUG} = 1;
    chdir 't' if -d 't';
    unshift @INC => '../lib', 'test_lib/';
    $CLASS = 'ClassB';
    use_ok $CLASS or die;
}

can_ok $CLASS, 'foo';
is $CLASS->foo([6,6,6]), "arrayref with 3 elements",
    '... and it should behave as expected';

throws_ok {$CLASS->foo(0)}
    qr/\QCould not find a method matching your signature: foo(SCALAR)\E/,
    '... but it will die if the signature does not match';

is_deeply $CLASS->foo({ that => 2}), {this => 1, that => 2},
    '... and we can even specify different types.';

can_ok $CLASS, 'bar';

throws_ok {$CLASS->bar([qw/an array ref/])}
    qr/\QCould not find a method matching your signature: bar(ARRAY)\E/,
    '... but we had better not pass a non-scalar to it';

ok $CLASS->match('this', qr/hi/),
    '... and we can overload the methods as much as we like';

ok !$CLASS->match('this', qr/ih/),
    '... and we can overload the methods as much as we like';

ok $CLASS->match([qw/this hi hit thistle/], qr/hi/),
    '... and sweet, sweet function overloading is ours at last';

my $object = $CLASS->new;
isa_ok($object, $CLASS);
ok $object->match('this', qr/hi/),
    '... and we can overload the methods as much as we like';

ok !$object->match('this', qr/ih/),
    '... and we can overload the methods as much as we like';

ok $object->match([qw/this hi hit thistle/], qr/hi/),
    '... and sweet, sweet function overloading is ours at last';

can_ok 'ClassA' => 'match';
is_deeply $object->match([qw/from ClassA/]), [qw/from ClassA/],
    '... even if we are inheriting the overloaded method.';
