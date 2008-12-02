#!/usr/bin/perl
package Log::Dispatch::Channels;
use strict;
use warnings;
use Log::Dispatch;
use Carp;

# ABSTRACT: Adds separate logging channels to Log::Dispatch

=head1 SYNOPSIS

  use Log::Dispatch::Channels;

  my $logger = Log::Dispatch::Channels->new;
  $logger->add_channel('foo');
  my $timestamper = sub { my %p = @_; return time . $p{message}; };
  $logger->add_channel('bar', callbacks => $timestamper);
  $logger->add(Log::Dispatch::File->new(channels  => 'foo',
                                        name      => 'foo',
                                        min_level => 'debug',
                                        filename  => 'foo.log'));
  $logger->add(Log::Dispatch::Null->new(channels  => 'bar',
                                        name      => 'bar',
                                        min_level => 'debug'));
  $logger->add(Log::Dispatch::File->new(channels  => [qw/foo bar/],
                                        name      => 'errors',
                                        min_level => 'error',
                                        filename  => 'error.log'));
  $logger->log(channels => 'foo', level => 'debug',
               message => 'For foo');
  $logger->log(channels => 'bar', level => 'error',
               message => 'For bar and errors');

=head1 DESCRIPTION

This module manages a set of L<Log::Dispatch> objects, treating them as
separate message channels to which messages can be logged. These objects can
share L<Log::Dispatch::Output> objects, to allow for logging to multiple places
simultaneously and automatically.

=cut

=method new()

Returns a new Log::Dispatch::Channels object.

=cut

sub new {
    my $class = shift;

    my $self = bless {
        channels => {},
        outputs  => {},
    }, $class;

    return $self;
}

=method add_channel(I<$NAME>, I<@ARGS>)

Adds a new message channel named I<$NAME>. This channel is actually a
L<Log::Dispatch> object, and I<@ARGS> is forwarded on to the L<Log::Dispatch>
constructor.

=cut

sub add_channel {
    my $self = shift;
    my $name = shift;

    carp "Channel $name already exists!"
        if exists $self->{channels}{$name};

    $self->{channels}{$name} = Log::Dispatch->new(@_);
}

=method remove_channel(I<$NAME>)

Removes the channel named I<$NAME> and returns it.

=cut

sub remove_channel {
    my $self = shift;
    my $name = shift;

    return delete $self->{channels}{$name};
}

sub _forward_to_channels {
    my $self = shift;
    my $channels = shift;
    my $method = shift;
    my @channels = !defined $channels
                 ? (keys %{ $self->{channels} })
                 : ref $channels
                 ? @$channels
                 : ($channels);

    # XXX: sort of a hack - the return value is only used by would_log, which
    # just wants a boolean
    my $ret = 0;
    for my $channel (@channels) {
        if (exists $self->{channels}{$channel}) {
            my $methodret = $self->{channels}{$channel}->$method(@_);
            $ret ||= $methodret;
        }
        else {
            carp "Channel $channel doesn't exist";
        }
    }
    return $ret;
}

=method add(I<$OUTPUT>[, channels => I<$NAMES>])

Adds I<$OUTPUT> (which is a L<Log::Dispatch::Output> object), and also adds it
to each channel named in I<$NAMES>. I<$NAMES> can be a string specifying a
single channel, an arrayref of strings specifying multiple channels, or left
out to add the output to all channels (this applies for each function taking a
'channels' argument).

=cut

sub add {
    my $self = shift;
    my $output = shift;
    my %args = @_;

    carp "Output " . $output->name . " already exists!"
        if exists $self->{outputs}{$output->name};

    $self->_forward_to_channels($args{channels}, 'add', $output);
    $self->{outputs}{$output->name} = $output;
}

=method remove(I<$NAME>)

Removes the output named I<$NAME> from the object and from each of the
channels, and then returns it.

=cut

sub remove {
    my $self = shift;
    my $name = shift;
    my %args = @_;

    $self->_forward_to_channels(undef, 'remove', $name);
    return delete $self->{outputs}{$name};
}

=method log([channels => I<$NAMES>,] I<%ARGS>)

Forwards I<%ARGS> on to the L<log|Log::Dispatch/log> method of each channel
listed in I<$NAMES>.

=cut

sub log {
    my $self = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    $self->_forward_to_channels($channels, 'log', %args);
}

=method log_and_die([channels => I<$NAMES>,] I<%ARGS>)

Forwards I<%ARGS> on to the L<log_and_die|Log::Dispatch/log_and_die> method of
each channel listed in I<$NAMES>.

=cut

sub log_and_die {
    my $self = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    $self->_forward_to_channels($channels, 'log_and_die', %args);
}

=method log_and_croak([channels => I<$NAMES>,] I<%ARGS>)

Forwards I<%ARGS> on to the L<log_and_croak|Log::Dispatch/log_and_croak> method
of each channel listed in I<$NAMES>.

=cut

sub log_and_croak {
    my $self = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    $self->_forward_to_channels($channels, 'log_and_croak', %args);
}

=method log_to(name => I<$NAME>, I<%ARGS>)

Forwards I<%ARGS> on to the L<log|Log::Dispatch::Output/log> method
of the output named I<$NAME>.

=cut

sub log_to {
    my $self = shift;
    my %args = @_;
    my $output = delete $args{name};

    $self->{outputs}{$output}->log(%args);
}

=method would_log(I<$LEVEL>[, channels => I<$NAMES>])

Returns true if any channel named in I<$NAMES> would log a message of level
I<$LEVEL>.

=cut

sub would_log {
    my $self = shift;
    my $level = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    return $self->_forward_to_channels($channels, 'would_log', $level);
}

=method output(I<$NAME>)

Returns the L<Log::Dispatch::Output> object named I<$NAME>.

=cut

sub output {
    my $self = shift;
    my $name = shift;

    return $self->{outputs}{$name} if exists $self->{outputs}{$name};
    return undef;
}

=method channel(I<$NAME>)

Returns the L<Log::Dispatch> object named I<$NAME>.

=cut

sub channel {
    my $self = shift;
    my $name = shift;

    return $self->{channels}{$name} if exists $self->{channels}{$name};
    return undef;
}

=head1 TODO

Allow top level callbacks on the Log::Dispatcher::Channels object

=head1 SEE ALSO

L<Log::Dispatch>

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-log-dispatch-channels at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Log-Dispatch-Channels>.

=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc Log::Dispatch::Channels

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Log-Dispatch-Channels>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Log-Dispatch-Channels>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Log-Dispatch-Channels>

=item * Search CPAN

L<http://search.cpan.org/dist/Log-Dispatch-Channels>

=back

=cut

1;
