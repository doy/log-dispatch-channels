#!/usr/bin/perl
package Log::Dispatch::Channels;
# ABSTRACT: Adds separate logging channels to Log::Dispatch
use strict;
use warnings;
use Log::Dispatch;
use Carp;

=head1 SYNOPSIS

=head1 DESCRIPTION

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

    $self->_forward_to_channels($args{channels}, 'remove', $output);
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

1;
