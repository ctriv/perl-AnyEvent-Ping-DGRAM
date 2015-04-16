package AnyEvent::Ping::DGRAM;

use strict;
use warnings;
no warnings 'once';

use base 'AnyEvent::Ping';

use Socket qw/SOCK_DGRAM/;

sub _create_socket {
    my $self = shift;

    IO::Socket::INET->new(
        Proto    => 'icmp',
        Type     => SOCK_DGRAM,
        Blocking => 0
    ) or Carp::croak "Unable to create icmp socket : $!";
}


sub _process_chunk_to_request {
    my ($self, $chunk) = @_;

    my $icmp_msg = $^O eq 'linux' ? $chunk : substr($chunk, 20);

    my ($type, $identifier, $sequence, $data);

    $type = unpack('c', $icmp_msg);

    if ($type == $AnyEvent::Ping::ICMP_ECHOREPLY) {
        ($type, $identifier, $sequence, $data) = (unpack($AnyEvent::Ping::ICMP_PING, $icmp_msg))[0, 3, 4, 5];
    }
    elsif ($type == $AnyEvent::Ping::ICMP_DEST_UNREACH || $type == $AnyEvent::Ping::ICMP_TIME_EXCEEDED) {
        ($identifier, $sequence) = unpack('nn', substr($chunk, 52));
    }
    else {

        # Don't mind
        return;
    }

    # Find our task
    my $request = List::Util::first { $data eq $_->{data} } @{$self->{_tasks}};

    return unless $request;

    # Is it response to our latest message?
    return unless $sequence == @{$request->{results}} + 1;
    
    return ($request, $type, $data);
}

  
=head1 NAME

AnyEvent::Ping::DGRAM - Ping as Non-Root

=head1 SYNOPSIS

    use AnyEvent;
    use AnyEvent::Ping::DGRAM;

    my $host  = shift || '4.2.2.2';
    my $times = shift || 4;
    my $timeout = shift || 5;
    my $package_s = shift || 56;
    my $c = AnyEvent->condvar;

    my $ping = AnyEvent::Ping::DGRAM->new;

    print "PING $host $package_s(@{[$package_s+8]}) bytes of data\n";
    $ping->ping($host, $times, $timeout, sub {
        my $results = shift;
        foreach my $result (@$results) {
            my $status = $result->[0];
            my $time   = $result->[1];
            printf "%s from %s: time=%f ms\n", 
                $status, $host, $time * 1000;
        };
        $c->send;
    });

    $c->recv;
    $ping->end;

=head1 DESCRIPTION

L<AnyEvent::Ping::DGRAM> is an asynchronous AnyEvent pinger.

It is a subclass of L<AnyEvent::Ping> that does not require the code to run
under root.

=head1 Running On Linux

This class depends on the DGRAM style icmp ping socket that linux provides.
Doing so allows your code to run as a non-root user.  However, you will need to
whitelist a group that the code's user is in.  The relevent sysctl takes a range
of groups:

   echo '0 2000' > /proc/sys/net/ipv4/ping_group_range
   
or to make it last between reboots:

   echo "net.ipv4.ping_group_range=0 2000" > /etc/sysctl.d/60-icmp-ping.conf
   /etc/init.d/procps restart

=cut

=cut

1;
__END__
