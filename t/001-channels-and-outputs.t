#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 13;
use Test::Deep;
use Log::Dispatch::ToString;

my $logger = Log::Dispatch::Channels->new;
for my $channel (1..3) {
    $logger->add_channel($channel);
    $logger->add(Log::Dispatch::ToString->new(name => $channel,
                                              min_level => 'debug'),
                 channels => $channel);
}

$logger->add(Log::Dispatch::ToString->new(name => 'all',
                                          min_level => 'debug'));
$logger->add(Log::Dispatch::ToString->new(name => 'one_and_two',
                                          min_level => 'debug'),
             channels => [qw/1 2/]);

for my $channel (1..3) {
    isa_ok($logger->channel($channel), 'Log::Dispatch');
    isa_ok($logger->output($channel), 'Log::Dispatch::ToString');
}

isa_ok($logger->channel('1')->output('all'), 'Log::Dispatch::ToString');
my $all_output = $logger->output('all');
my $set = set();
for my $channel (1..3) {
    $set->add(shallow($logger->channel($channel)->output('all')));
}
cmp_deeply([$all_output], $set, "output 'all' is shared between all channels");

is($logger->channel('3')->output('one_and_two'), undef,
   "output 'one_and_two' isn't added to channel '3'");

$logger->remove('one_and_two');
is($logger->channel('1')->output('one_and_two'), undef,
   "output 'one_and_two' is gone from channel '1'");
is($logger->channel('2')->output('one_and_two'), undef,
   "output 'one_and_two' is gone from channel '2'");
is($logger->output('one_and_two'), undef,
   "output 'one_and_two' is gone after we remove it");
$logger->remove_channel('1');
is($logger->channel('1'), undef,
   "channel '1' is gone after we remove it");
