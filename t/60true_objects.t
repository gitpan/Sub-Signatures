#!/usr/bin/perl
# '$Id: 60true_objects.t,v 1.2 2004/12/05 21:19:33 ovid Exp $';
use warnings;
use strict;
#use Test::More 'no_plan';
use Test::More tests => 16;
use Test::Exception;

BEGIN
{
#    $ENV{DEBUG} = 1;
    chdir 't' if -d 't';
    unshift @INC => '../lib';
}

my $CLASS = 'Some::Package';

{
    package Some::Package;
    use Sub::Signatures qw/strict methods/;

    sub new { bless {} => shift }
    
    sub foo($class, ARRAY $bar) {
        return sprintf "arrayref with %d elements" => scalar @$bar;
    }
    
    sub foo($class, HASH $bar) {
        $bar->{this} = 1; 
        $bar;
    }

    sub bar($class, $bar) {
        $bar;
    }

    sub match($class, $bar, Regexp $foo) {
        return $bar =~ $foo;
    }

    sub match($class, ARRAY $bar, Regexp $foo) {
        return @$bar == grep $_ =~ $foo => @$bar;
    }
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

{
    package Some::Other::Package;
    our @ISA = $CLASS;

    use Sub::Signatures qw/strict methods/;
    
    sub match($proto, HASH $bar) { $bar }
}

$object = Some::Other::Package->new;
isa_ok $object => 'Some::Other::Package';
is_deeply $object->match({1,2}), {1,2},
    '... and we can use classes that have inherited methods';
ok $object->match([qw/this hi hit thistle/], qr/hi/),
    '... without conflict';