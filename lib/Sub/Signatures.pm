package Sub::Signatures;
$REVISION = '$Id: Signatures.pm,v 1.3 2004/12/05 21:19:33 ovid Exp $';
$VERSION  = '0.1';

use 5.006;
use strict;
use warnings;
use Filter::Simple;

my $CALLPACK;
my %SIG;

my %STRICT;
my %METHODS;

sub import { 
    my $class = shift;
    my %props = map { $_ => 1 } @_;
    ($CALLPACK) = caller;
    $STRICT{$CALLPACK}  = exists $props{strict}  ? 1 : 0;
    $METHODS{$CALLPACK} = exists $props{methods} ? 1 : 0;
    if ($ENV{DEBUG}) {
        require Data::Dumper;
        Data::Dumper->import;
        $Data::Dumper::Indent = 1;
    }
}

my $signature = sub {
    my ($subname, $parameters) = @_;
    my @args = 
        map { /\s*(\w*)\s*(\$\w+)/; [$1 || 'SCALAR', $2] }
        split /(?:,|=>)/ => $parameters;
    $args[0][0] = 'SCALAR' if $METHODS{$CALLPACK}; # ignore the type of the first argument
    my $types   = join '_'  => map { $_->[0] } @args;
    $parameters = join ', ' => map { $_->[1] } @args;
    return ("_${subname}_$types", $parameters, scalar @args);
};

my $make_subs = sub {
    while (my ($pack, $subs) = each %SIG) {
        while (my ($sub, $counts) = each %$subs) {
            while (my ($count, $target) = each %$counts) {
                next if 'body' eq $count;
                if ($STRICT{$pack}) {
                    next if $subs->{$sub}{body};
                    $subs->{$sub}{body}  = <<"    END_SUB";
    my \$s = Sub::Signatures::_make_signature('$pack', \@_);
    no strict 'refs';
    goto &{"_${sub}_\$s"} if defined &{"_${sub}_\$s"};
    END_SUB
                    if ($METHODS{$pack}) {
                        $subs->{$sub}{body} .= <<"    END_SUB";
    if (my \$method = UNIVERSAL::can(\$_[0], "_${sub}_\$s")) {
        goto \$method;
    }
    END_SUB
                    }
                }
                else {
                    $subs->{$sub}{body} ||= '';
                    $subs->{$sub}{body}  .= "    goto \&$target if $count == \@_;\n";
                }
            }
        }
    }
    print Dumper(%SIG) if $ENV{DEBUG};
};

my $install_subs = sub {
    while (my ($pack, $subs) = each %SIG) {
        foreach my $sub (keys %$subs) {
            my $body = $subs->{$sub}{body};
            my $type = $METHODS{$pack} ? 'method' : 'sub';
            $body   .= <<"    END_BODY";
    # if we got to here, there was no $type to dispatch to
    require Carp;
    shift if 'method' eq '$type';
    my \$types = join ', ' => map { ref \$_ || 'SCALAR' } \@_;
    Carp::croak "Could not find a $type matching your signature: $sub(\$types)";
    END_BODY
            no warnings 'redefine';
            my $installed_sub = "package $pack;\nsub $sub {\n$body}";
            eval $installed_sub;
            die "Failed to install &${pack}::$sub\n----------\n$installed_sub\n----------\nReason:  $@" if $@;
        }
    }
};

sub _make_signature {
    my ($package, @args) = @_;
    $args[0] = '' if $METHODS{$package}; # ignore the type of the first argument
    return join '_' => map { ref $_ || 'SCALAR' } @args;
}

FILTER_ONLY code => sub {
    while (/(sub\s*(\w+)?\s*\(([^)]+)\)[^{]*{)/) {
        my ($sub_with_sig, $oldname, $parameters) = ($1, $2, $3);
        next unless $parameters; # don't process them if they don't use them

        # the following line doesn't work.  For some reason, using prototypes
        # with this module causes an infinite while loop here.
        # I'm probably overlooking something really obvious. 
        # next if $parameters =~ /^\s*[\\\$@%*;\[\]]*\s*$/; # ignore prototypes

        my ($newname, $newparams, $count);
        if ($oldname) { 
            # named sub
            ($newname, $newparams, $count) = $signature->($oldname, $parameters);
            if (exists $SIG{$CALLPACK}{$oldname} && exists $SIG{$CALLPACK}{$oldname}{$count}) {
                my $dup_method = $STRICT{$CALLPACK}
                    ? exists $SIG{$CALLPACK}{$oldname}{$count}{$newname}
                    : 1;
                if ($dup_method) {
                    my $args = $newname;
                    $args =~ s/^_\w+_//;
                    $args =~ s/_/, /g;
                    # how do I get the line number?
                    die "$oldname($args) redefined in package '$CALLPACK'";
                }
            }
            if ($STRICT{$CALLPACK}) {
                $SIG{$CALLPACK}{$oldname}{$count}{$newname} = 1;
            }
            else {
                $SIG{$CALLPACK}{$oldname}{$count} = $newname;
            }
        }
        else { 
            # anonymous sub
            $newname   = '';
            $newparams = $parameters;
        }
        s/\Q$sub_with_sig\E/sub $newname { my ($newparams) = \@_;/;
    }
    print $_ if $ENV{DEBUG};
};

CHECK {
    $make_subs->();
    $install_subs->();
}

1;

__END__

=head1 NAME

Sub::Signatures - Use proper signatures for subroutines, including dispatching.

=head1 SYNOPSIS

  use Sub::Signatures;
  
  sub foo($bar) {
    print "$bar\n";
  }

  sub foo($bar, $baz) {
    print "$bar, $baz\n";
  }

  foo(1);     # prints 1
  foo(2,3);   # prints 2, 3
  foo(2,3,4); # fatal error

=head1 ABSTRACT

 Signature based method overloading in Perl.  Strong typing optional.

=head1 DESCRIPTION

One of the strongest complaints about Perl is its poor argument handling.
Simply passing everything in the C<@_> array is a serious limitation.  This
module aims to rectify that.

We often see things like this in Perl code:

 sub name {
   my $self = shift;
   $self->set_name(@_) if @_;
   return $self->{name};
 }

 sub set_name {
   my $self = shift;
   $self->{name} = shift;
   return $self;
 }

The intent here is to allow someone to do this:

  my $name = $person->name; # fetch the name
  $person->name('Ovid');    # set the name

But what happens when someone does this?

  my $name = Name->new('Ovid');
  $person->name($name); # this fails

Or this?

  $person->name(qw/Publius Ovidius Naso/);

All of those seem reasonable but Perl will silently DWIDM (Do What I Don't
Mean) and this can be difficult to debug.  Most modern programming languages do
not have this problem (neither will Perl 6.)   The intent of C<Sub::Signatures>
is to fix this problem painlessly by allowing signature based method dispatch.
Here's how you could fix this:

  use Sub::Signatures qw/strict methods/;

  # ...

  sub name ($self) {
    return $self->{name};
  }

  sub name ($self, $name) { # without a specific type, it assumes a scalar
    $self->{name} = $name;
  }

  sub name ($self, Name $name) { # must have a Name object
    $self->{name} = $name->as_string;
  }

That allows all of the above methods except for the last one:

  $person->name(qw/Publius Ovidius Naso/);

That generates a fatal error because no C<name()> method had a matching
signature.  You could make it work with this:

  sub name ($self, $first, $middle, $last) {
    ...
  }

=head1 MODES

=head2 'loose' mode

By default C<Sub::Signatures> runs in C<loose> mode.  When in this mode,
subroutines and methods are called based on the number of arguments, not the
type.  This makes programming quick and easy:

 use Sub::Signatures;

 sub foo($bar) {
     print $bar;
 }

 sub foo($bar, $baz) {
     print "$baz, $bar";
 }

=head2 'strict' mode

What if a sub can take either an arrayref or a hashref?  Rather than have the
sub figure out what to do, you can specify the type (as determined by the
C<ref> function) of an argument in the argument list.  You do can do this with
C<loose> mode, but the type will be ignored.  Instead, switch to C<strict> mode.

 use Sub::Signatures qw/strict/;

 sub foo(ARRAY $bar) {
     print scalar @$bar;
 }

 sub foo(HASH $bar) {
     print scalar keys %$bar;
 }

If you do not specify a type for a variable in a signature, C<SCALAR> will be
assumed.

 package Foo;

 use Sub::Signatures qw/strict/;
 
 sub foo($bar) {
     print $bar;
 }

 # in another file:

 use Foo;
 Foo::bar("Ovid");     # prints 'Ovid'
 Foo::bar([qw/Ovid/]); # dies unless 'sub foo(ARRAY $bar) {}' exists.

Of course, signatures can get quite long, too:

 sub foo(ARRAY $bar, HASH $baz, CGI $query) {
     ...
 }

Note the last argument in that list.  It means that C<$query> must be a CGI
object.  Regrettably, C<Sub::Signatures> does not support allowing a subclass
there, but it may in future releases.  This rather limits the utility if the
class is not known at compile time.  However, note that subroutines without
signatures B<still behave normally>. You will still be able to do this:

 sub foo {
   my ($bar, $baz, $query) = @_;
   ...
 }

=head2 'methods' mode

The default behavior of C<Sub::Signatures> is to assume that signatures are on
subroutines.  If you use this with OO programming and have methods instead of
functions, you must specify C<methods> mode.  This is because the type of the
first argument cannot be guaranteed at compile time and we have to be able to
dispatch to a parent class if the method isn't found in the current class.

 package ClassA;
 
 use Sub::Signatures qw/strict methods/;
 
 sub new($package, HASH $properties) { 
    bless $properties => $package;
 }
 
 sub foo($class, ARRAY $bar) {
     return sprintf "arrayref with %d elements" => scalar @$bar;
 }
 
 sub name($self) {
     return $self->{name};
 }

 sub name($self, $name) {
     $self->{name} = $name;
     return $self;
 }
 
 1;

=head1 FEATURES

Currently supported features:

=over 4

=item * Methods

 use Sub::Signatures 'methods';

=item * Subroutines

 use Sub::Signatures;

=item * Optional strong typing via the C<ref> function

 use Sub::Signatures 'strict';

=item * Exporting

 use base 'Exporter';
 use Sub::Signatures;
 our @EXPORT_OK = qw/foo/;

 sub foo($bar) {...}

 sub foo($bar, $baz) {
     ...
 }

=item * No duplicate signatures

In loose mode:

 use Sub::Signatures;
 sub foo($bar) {}
 sub foo($baz) {} # won't compile
 
In strict mode:

 use Sub::Signatures 'strict';
 sub foo($bar) {}
 sub foo(HASH $bar) {} # good so far because the first is a SCALAR
 sub foo(HASH $baz) {} # This fails because we can't disambiguate them

=item * Inheritance

This works, but see caveats below.

=item * Anonymous subroutines

These mostly work, but there are limitations.  Signature-based dispatch does
not make much sense in this context, so it's not available.  The only point is
to be able to declare your anonymous subs with variables:

 my $thingy = sub ($foo, $bar) { ... };

Unlike named subs, the number of arguments is not checked, so this is
equivalent to:

 my $thingy = sub { my ($foo, $bar) = @_; ... };

=item * Useful error messages

The error messages bear some explaining.  If your code cannot find the correct
method to dispatch to, you'll see something like this:

 Could not find a sub matching your signature: foo(SCALAR, SCALAR) at ...

Or:

 Could not find a method matching your signature: foo(SCALAR) at ...

If used in method mode, the first argument to a method is actually a class or 
instance of a class, but this is B<not> in the argument list in the error
message because this seems counter-intuitive:

 $object->foo($bar);

It looks like there's really only one argument (even though we know better)
and for various reasons, the code is a bit cleaner when the error message is
handled this way.

=back

=head1 BUGS AND LIMITATIONS

Don't be discouraged by the long list of items here.  For the most part this
module I<just works>.  If you are having problems, consult this list to see
if it's covered here.

=over 4

=item * Do not mix "signatured" subs with "non-signatured" of the same name

In other words, don't do this:

 sub foo($bar) { ... }
 sub foo { ... }

However, you don't need signatures on all subs.  This is OK:

 sub foo($bar) { ... }
 sub baz { ... }

=item * Use caution when mixing functions and methods

Internally, functions and methods are handled quite differently.  If you use
this with a class, you probably do not want to use signatures with functions in
said class.  Things will usually work, but not always.  Error messages will be
misleading.

  package Foo;
  use Sub::Signatures qw/methods/;

  sub new($class) { bless {} => $class }

  sub _some_func($bar) { return scalar reverse $bar }

  sub some_method($self, $bar) { 
      $self->{bar} = _some_func($bar);
  }

  sub some_other_method($self, $bar, $baz) {
      # this fails with 
      # Could not find a method matching your signature: _some_func(SCALAR) at ...
      $self->{bar} = _some_func($bar, $baz);
  }

  1;

=item * One package per file.

Currently we cannot handle more than one package per file with this module.
It sometimes works with methods, but there are no guarantees.  When we can
parse Perl reliably, this may change :)

=item * Can only handle scalars and references in the arg list.

At the present time, the only variables allowed in signatures are those
that begin with a dollar sign:

 sub foo($bar, $baz) {...}; # good
 sub foo($bar, @baz) {...}; # not good

=item * Handle prototypes correctly

Don't try using prototypes with this module.  It currently tends to get caught
in an infinite loop if you do that, so don't do that.

 use Sub::Signatures;

 sub foo($$) {...} # don't do that

See C<t/90prototypes.t> and the code at the end if you want to fix this.

=item * How do we handle variadic subs?

At the present time, all subs and methods must have a fixed number of
arguments.  This may change in the future.

=item * Signature types ignore C<isa> relationships.

Properly a signature should be able to specify a type that an argument has
an I<isa> relationship with.  This does not yet work.

 sub foo(ParentClass $bar) { ... }

 # later

 foo(SubClassOfParentClass->new); # should work, but doesn't

If you need that behavior, don't use a signature for that subroutine or method.

=item * lvalue subroutines?

There is no support for them.  Patches welcome.

=back

=head1 HOW THIS WORKS

In a nutshell, each subroutine is renamed with a unique, signature-based name
and a sub with its original name figures out how to dispatch to it.  It loosely
works like this:

 package Some::Package;

 sub foo($bar) {
     return [$bar];
 }
 
 sub foo($bar, HASH $baz) {
     return exists $baz->{$bar};
 }
 
In loose mode, this becomes:

 # note that only the number of arguments is checked

 package Some::Package;

 sub foo {
     goto &_foo_SCALAR if 1 == @_;
     goto &_foo_SCALAR_HASH if 2 == @_;
     # die with a useful error message
 }

 sub _foo_SCALAR { my ($bar) = @_;
     return [$bar];
 }

 sub _foo_SCALAR_HASH { my ($bar, $baz) = @_;
     return exists $baz->{$bar};
 }

In strict the only difference is in how the dispatch subroutine is created.

 sub foo {
     my $s = Sub::Signatures::_make_signature('Some::Package', @_);
     no strict 'refs';
     goto &{"_foo_$s"} if defined &{"_foo_$s"};
     # die with a useful error message
 }

The C<_make_signature> subroutine returns a signature like "SCALAR_HASH_DBI",
etc., thus allowing for the type checking.

There's a bit more magic involved when it comes to methods, particulary with
trying to call an inherited method if one is not found in the current package.
However, this should give you a rough idea of what's going on and also give you
fair warning that deliberately naming subs things like
C<_subname_TYPE_TYPE_ETC> is a bad thing.

=head1 EXPORT

None.

=head1 HOW TO GET THIS BEYOND ALPHA

This is alpha code.  Many people understandably do not wish to use alpha code
in production.  To get this code robust enough for production use, send me
bug reports.  Send me patches.  Send me requests.  Send me feedback.

Naturally, since this is alpha code, the interface may change.  Hopefully I've
not made any boneheaded mistakes that necessitate this, but I will not
guarantee that I am not, in fact, boneheaded.

=head1 SEE ALSO

L<Filter::Simple>

Yes, this is based on a source filter.  If you can't stand that, don't use this
module.  However, before you ignore it, read 
L<http://use.perl.org/~Ovid/journal/22152>.

=head1 AUTHOR

Curtis "Ovid" Poe, E<lt>moc tod oohay ta eop_divo_sitrucE<gt>

Reverse the name to email me.

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Curtis "Ovid" Poe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
