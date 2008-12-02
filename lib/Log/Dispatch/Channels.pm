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

This module manages a set of Log::Dispatch objects, treating them as separate
message channels to which messages can be logged. These objects can share
Log::Dispatch::Output objects, to allow for logging to multiple places
simultaneously and automatically.

=cut

=method new

=cut

sub new {
    my $class = shift;

    my $self = bless {
        channels => {},
        outputs  => {},
    }, $class;

    return $self;
}

=method add_channel

=cut

sub add_channel {
    my $self = shift;
    my $channel = shift;

    carp "Channel $channel already exists!"
        if exists $self->{channels}{$channel};

    $self->{channels}{$channel} = Log::Dispatch->new(@_);
}

=method remove_channel

=cut

sub remove_channel {
    my $self = shift;
    my $channel = shift;

    return delete $self->{channels}{$channel};
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

=method add

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

=method remove

=cut

sub remove {
    my $self = shift;
    my $output = shift;
    my %args = @_;

    $self->_forward_to_channels(undef, 'remove', $output);
    return delete $self->{outputs}{$output};
}

=method log

=cut

sub log {
    my $self = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    $self->_forward_to_channels($channels, 'log', %args);
}

=method log_and_die

=cut

sub log_and_die {
    my $self = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    $self->_forward_to_channels($channels, 'log_and_die', %args);
}

=method log_and_croak

=cut

sub log_and_croak {
    my $self = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    $self->_forward_to_channels($channels, 'log_and_croak', %args);
}

=method log_to

=cut

sub log_to {
    my $self = shift;
    my %args = @_;
    my $output = delete $args{name};

    $self->{outputs}{$output}->log(%args);
}

=method would_log

=cut

sub would_log {
    my $self = shift;
    my $level = shift;
    my %args = @_;
    my $channels = delete $args{channels};

    return $self->_forward_to_channels($channels, 'would_log', $level);
}

=method output

=cut

sub output {
    my $self = shift;
    my $output = shift;

    return $self->{outputs}{$output} if exists $self->{outputs}{$output};
    return undef;
}

=method channel

=cut

sub channel {
    my $self = shift;
    my $channel = shift;

    return $self->{channels}{$channel} if exists $self->{channels}{$channel};
    return undef;
}

=head1 TODO

Allow top level callbacks on the Log::Dispatcher::Channels object

=head1 SEE ALSO

L<Log::Dispatch>

=cut

1;
