#!/usr/bin/perl
# '$Id: 05internals.t,v 1.1 2004/12/05 21:19:33 ovid Exp $';
use warnings;
use strict;
use Test::More tests => 7;

# These tests are for some of the internals.  Do not depend on them.  In fact,
# you can ignore them entirely.  There are no user-serviceable parts in here
# and nothing in this tested in here is guaranteed to remain the same.

BEGIN
{
    chdir 't' if -d 't';
    unshift @INC => '../lib';
}

{
    use Sub::Signatures;

    sub foo($bar) {
        $bar;
    }
    sub foo($bar, $baz) {
        return [$bar, $baz];
    }

    ok defined &_foo_SCALAR, 
        'We can have subs with one argument';
    is_deeply _foo_SCALAR({this => 'one'}), {this => 'one'},    
        '... and it should behave as expected';
    ok defined &_foo_SCALAR,
        '... and we can recreate the sub with a different signature';
    is_deeply _foo_SCALAR_SCALAR(1,2), [1,2],
        '... and call the correct sub based upon the number of arguments';

    ok defined &Sub::Signatures::_make_signature,
        'The module should have a subroutines to make signatures';

    is Sub::Signatures::_make_signature('Some::Package', [],1,{}), 'ARRAY_SCALAR_HASH',
        '... and it should return valid signatures';
}

{
    package Foo;

    use Sub::Signatures qw/methods/;

    sub bar ($class, $this, $that) {
        return [$this, $that];
    }
    package main;
    is Sub::Signatures::_make_signature('Foo', [],1,{}), 'SCALAR_SCALAR_HASH',
        '... but ignore the type of the first argument with methods';
}
