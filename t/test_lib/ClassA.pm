package ClassA;

use strict;
use warnings;
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

sub match($class, ARRAY $bar) {
    return $bar;
}

1;
