package SMS::Handler::Ping;

require 5.005_62;

use Carp;
use strict;
use warnings;
use SMS::Handler;
use vars qw(@ISA);
use Net::SMPP 1.04;
use Params::Validate qw(:all);

# $Id: Ping.pm,v 1.7 2003/01/14 20:32:34 lem Exp $

(our $VERSION = q$Revision: 1.7 $) =~ s/Revision //;

our $Debug = 0;

=pod

=head1 NAME

SMS::Handler::Ping - Simple test for SMS::Handler

=head1 SYNOPSIS

  use SMS::Handler::Ping;

  my $h = SMS::Handler::Ping->new(-message => "It's alive",
				  -queue => $queue_obj,
				  -addr => '9.9.5551212',
				  -dest => '9.9.5551313',
				  );

 $h->handle({ ... });

=head1 DESCRIPTION

This module implements a simple responder class. It will respond to
any message directed to the specified phone number, with the specified
message.

The following methods are provided:

=over 4

=item C<-E<gt>new()>

Creates a new C<SMS::Handler::Ping> object. It accepts parameters as a
number of key / value pairs. The following parameters are supported.

=over 2

=item C<message =E<gt> $message>

The text of the message that must be returned. If it is left
unspecified, the word B<"Pong"> will be used.

Note that if the SMS text matches this, no answer will be produced to
avoid loops.

=item C<queue =E<gt> $queue_obj>

An object obeying the interface defined in L<Queue::Dir>, where the
response message generated by this module will be stored.

=item C<addr =E<gt> $my_addr>

The address assigned to this service, in B<pon.npi.phone> format. The
destination address of the SMS, must match this argument. If this
address is left unspecified, the SMS will be accepted no matter what
destination address is used.

=item C<dest =E<gt> $dest_addr>

If this argument is supplied, any answers will be sent to this
address.

=back

=cut

sub new 
{
    my $name	= shift;
    my $class	= ref($name) || $name;

    my %self = validate_with 
	( 
	  params	=> \@_,
	  ignore_case	=> 1,
	  strip_leading	=> '-',
	  spec => 
	  {
	      message =>
	      {
		  type		=> SCALAR,
		  default	=> 'Pong',
	      },
	      queue =>
	      {
		  type		=> OBJECT,
		  can		=> [ qw(store) ],
	      },
	      addr =>
	      {
		  type		=> SCALAR,
		  default	=> undef,
		  callbacks	=>
		  {
		      'address format' => sub { $_[0] =~ /^\d+\.\d+\.\d+$/; }
		  }
	      },
	      dest =>
	      {
		  type		=> SCALAR,
		  default	=> undef,
		  callbacks	=>
		  {
		      'address format' => sub { $_[0] =~ /^\d+\.\d+\.\d+$/; }
		  }
	      }
	  });
    
    if ($self{addr}) 
    {
	($self{ton}, $self{npi}, $self{number}) = split(/\./, $self{addr}, 3);
    }

    if ($self{dest}) 
    {
	($self{dton}, $self{dnpi}, $self{dnumber}) = 
	    split(/\./, $self{dest}, 3);
    }
    
    return bless \%self, $class;
}

=pod

=item C<-E<gt>handle()>

Process the given SMS. The source and destination addresses are
reversed.

=cut

sub handle 
{
    my $self = shift;
    my $hsms = shift;

    if ($self->{number})
    {
	unless ($hsms->{dest_addr_ton} == $self->{ton})
	{
	    warn "Ping: Destination address did not match TON\n" if $Debug;
	    return SMS_CONTINUE;
	}
        unless ($hsms->{dest_addr_npi} == $self->{npi})
	{
	    warn "Ping: Destination address did not match NPI\n" if $Debug;
	    return SMS_CONTINUE;
	}
	unless ($hsms->{destination_addr} == $self->{number})
	{
	    warn "Ping: Destination address did not match NUMBER\n" if $Debug;
	    return SMS_CONTINUE;
	}
    }

    if ($hsms->{short_message} ne $self->{message})
    {

	my $pdu = new Net::SMPP::PDU;

	$pdu->source_addr_ton($hsms->{dest_addr_ton});
	$pdu->source_addr_npi($hsms->{dest_addr_npi});
	$pdu->source_addr($hsms->{destination_addr});
	$pdu->dest_addr_ton($self->{dton} || $hsms->{source_addr_ton});
	$pdu->dest_addr_npi($self->{dnpi} || $hsms->{source_addr_npi});
	$pdu->destination_addr($self->{dnumber} || $hsms->{source_addr});
	$pdu->short_message($self->{message});
	
	my ($fh, $qid) = $self->{queue}->store;
	
	$pdu->nstore_fd($fh);

	if ($fh->close)
	{
	    warn "Ping: Unlocking and commiting response message\n" if $Debug;
	    $self->{queue}->unlock($qid);
	    return SMS_STOP | SMS_DEQUEUE;
	}

	warn "Ping: close() failed (unlocking response): $!\n" if $Debug;
	$self->{queue}->unlock($qid);
    }
    else
    {
	warn "Ping: destroy source message\n" if $Debug;
	return SMS_STOP | SMS_DEQUEUE;
    }

    warn "Ping: SMS_CONTINUE\n" if $Debug;
    return SMS_CONTINUE;
}

1;
__END__

=pod

=head2 EXPORT

None by default.

=head1 LICENSE AND WARRANTY

This code comes with no warranty of any kind. The author cannot be
held liable for anything arising of the use of this code under no
circumstances.

This code is released under the terms and conditions of the
GPL. Please see the file LICENSE that accompains this distribution for
more specific information.

This code is (c) 2002 Luis E. Mu�oz.

=head1 HISTORY

$Log: Ping.pm,v $
Revision 1.7  2003/01/14 20:32:34  lem
Got rid of Net::SMPP::XML

Revision 1.6  2002/12/22 19:03:02  lem
Set license GPL

Revision 1.5  2002/12/20 01:25:57  lem
Changed emails for redistribution

Revision 1.4  2002/12/09 22:04:28  lem
Added ::Blackhole

Revision 1.3  2002/12/09 21:40:25  lem
Better error recovery

Revision 1.2  2002/12/09 20:53:58  lem
Added loop prevention, a test for this and the possibility to specify a fixed destiantion address

Revision 1.1  2002/12/06 15:50:31  lem
Added ::Ping and its tests


=head1 AUTHOR

Luis E. Mu�oz <luismunoz@cpan.org>

=head1 SEE ALSO

L<SMS::Handler>, L<Queue::Dir>, perl(1).

=cut

