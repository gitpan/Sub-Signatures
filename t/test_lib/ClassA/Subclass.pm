package ClassA::Subclass;
use base 'ClassA';

use strict;
use warnings;
use Sub::Signatures qw/strict methods/;

sub match($class, $bar, Regexp $foo) {
    return $bar =~ $foo;
}

sub match($class, ARRAY $bar, Regexp $foo) {
    return @$bar == grep $_ =~ $foo => @$bar;
}

1;
