#!/usr/bin/perl
# '$Id: 50strict_methods.t,v 1.2 2004/12/05 21:19:33 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 3;
#use Test::More 'no_plan';
use Test::Exception;

my $CLASS;
BEGIN
{
#    $ENV{DEBUG} = 1;
    chdir 't' if -d 't';
    unshift @INC => '../lib', 'test_lib';
    $CLASS = 'Sub::Signatures';
    use_ok( 'ClassA::Subclass' ) or die;
}
use Sub::Signatures 'strict';

my $object = ClassA::Subclass->new;
isa_ok $object, 'ClassA::Subclass';

sub this(ClassA::Subclass $o) {
    $o->foo([]);;
}

is this($object), 'arrayref with 0 elements',
    '... and we should be able to use classnames with colons';
