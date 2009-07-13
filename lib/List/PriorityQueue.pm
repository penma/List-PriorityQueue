package List::PriorityQueue;

our $VERSION = '0.00';

use strict;
use warnings;

sub new {
	return bless {
		queue => [],
		prios => {},     # by payload
	}, shift();
}

sub pop {
	my ($self) = @_;
	if (@{$self->{queue}} == 0) {
		return undef;
	}
	delete($self->{prios}->{$self->{queue}->[0]});
	return shift(@{$self->{queue}});
}

sub insert {
	my ($self, $payload, $priority, $lower, $upper) = @_;
	$lower //= 0;
	$upper //= scalar(@{$self->{queue}}) - 1;

	# first of all, map the payload to the desired priority
	# run an update if the element already exists
	if (exists($self->{prios}->{$payload})) {
		goto &update;
	} else {
		$self->{prios}->{$payload} = $priority;
	}

	# And register the payload in the queue. There are a lot of special
	# cases that can be exploited to save us from doing the relatively
	# expensive binary search.

	# Special case: No items in the queue.  The queue IS the item.
	if (@{$self->{queue}} == 0) {
		push(@{$self->{queue}}, $payload);
		return;
	}

	# Special case: The new item belongs at the end of the queue.
	if ($priority >= $self->{prios}->{$self->{queue}->[-1]}) {
		push(@{$self->{queue}}, $payload);
		return;
	}

	# Special case: The new item belongs at the head of the queue.
	if ($priority < $self->{prios}->{$self->{queue}->[0]}) {
		unshift(@{$self->{queue}}, $payload);
		return;
	}

	# Special case: There are only two items in the queue.  This item
	# naturally belongs between them (as we have excluded the other
	# possible positions before)
	if (@{$self->{queue}} == 2) {
		splice(@{$self->{queue}}, 1, 0, $payload);
		return;
	}

	# And finally we have a nontrivial queue.  Insert the item using a
	# binary seek.
	# Do this until the upper and lower bounds crossed... in which case we
	# will insert at the lower point
	my $midpoint;
	while ($upper >= $lower) {
		$midpoint = ($upper + $lower) >> 1;

		# We're looking for a priority lower than the one at the midpoint.
		# Set the new upper point to just before the midpoint.
		if ($priority < $self->{prios}->{$self->{queue}->[$midpoint]}) {
			$upper = $midpoint - 1;
			next;
		}

		# We're looking for a priority greater or equal to the one at the
		# midpoint.  The new lower bound is just after the midpoint.
		$lower = $midpoint + 1;
	}

	splice(@{$self->{queue}}, $lower, 0, $payload);
}

sub find_payload_pos {
	my ($self, $payload) = @_;
	my $priority = $self->{prios}->{$payload};

	# Find the item with binary search.
	# Do this until the bounds are crossed, in which case the lower point
	# is aimed at an element with a higher priority than the target
	my $lower = 0;
	my $upper = @{$self->{queue}} - 1;
	my $midpoint;
	while ($upper >= $lower) {
		$midpoint = ($upper + $lower) >> 1;

		# We're looking for a priority lower than the one at the midpoint.
		# Set the new upper point to just before the midpoint.
		if ($priority < $self->{prios}->{$self->{queue}->[$midpoint]}) {
			$upper = $midpoint - 1;
			next;
		}

		# We're looking for a priority greater or equal to the one at the
		# midpoint.  The new lower bound is just after the midpoint.
		$lower = $midpoint + 1;
	}

	# The lower index is now pointing to an element with a priority higher
	# than our target.  Scan backwards until we find the target.
	while ($lower-- >= 0) {
		return $lower if ($self->{queue}->[$lower] eq $payload);
	}
}

sub delete {
	my ($self, $payload) = @_;
	my $pos = $self->find_payload_pos($payload);

	delete($self->{prios}->{$payload});
	splice(@{$self->{queue}}, $pos, 1);

	return $pos;
}

sub update {
	my ($self, $payload, $new_prio) = @_;
	my $old_prio = $self->{prios}->{$payload};
	if (!defined($old_prio)) {
		$self->insert($payload, $new_prio);
		return;
	}

	# delete the old item
	my $old_pos = $self->delete($payload);

	# reinsert the item, limiting the range for the binary search (if needed)
	# a bit by checking how the priority changed.
	my ($upper, $lower);
	if ($new_prio - $old_prio > 0) {
		$upper = @{$self->{queue}};
		$lower = $old_pos;
	} else {
		$upper = $old_pos;
		$lower = 0;
	}
	$self->insert($payload, $new_prio, $lower, $upper);
}

1;

__END__

=head1 NAME

List::PriorityQueue - high performance priority list (pure perl)

=head1 SYNOPSIS

 my $prio = new List::PriorityQueue;
 $prio->insert("foo", 2);
 $prio->insert("bar", 1);
 $prio->insert("baz", 3);
 my $next = $prio->pop(); # "bar"
 # I decided that "foo" isn't as important anymore
 $prio->update("foo", 99);

=head1 DESCRIPTION

This module implements a high-performance priority list. It's written in pure
Perl.

Available functions are:

=head2 new()

Obvious.

=head2 insert(I<$payload>, I<$priority>)

Adds the specified payload (anything fitting into a scalar) to the priority
queue, using the specified priority. Smaller means more important.

=head2 pop()

Removes the most important item (numerically lowest priority) from the queue
and returns it. If no element is there, returns I<undef>.

=head2 delete(I<$payload>)

Deletes an item known by the specified payload from the queue.

=head2 update(I<$payload>, I<$new_priority>)

Finds the item known by the specified payload, and assigns it the new priority.
It's optimized to perform better than a delete followed by insert.

=head1 DIFFERENCES TO POE::QUEUE::ARRAY

There are some things I disliked about POE::Queue::Array, which ultimately
led to the creation of this derivative.

First, it stores data in a package global variable. The author brings up a
valid argument why this is not bad in this case. However I still was somehow
not happy with the fact it used a global variable. For example, serializing
a queue would not work as the actual queue reference only stores numerical
IDs into the package variable containing all the data, but that one wouldn't
be saved.

Second, for some operations to be carried out efficiently, you have to carry
the internal IDs around in your program, else you have to do a full search
for your element everytime you want to delete or update it. While carrying it
around is relatively simple, there is no reason why the class itself shouldn't
manage this and relieve the programmer from this work.

A benchmark with POE::Queue::Array and the described payload-to-ID mapping and
this module revealed that they are equally fast.

=head1 NOTES

When inserting an item that already is in the queue, currently B<update> is
called for you. You should not rely on this behavior and use B<update>
directly. Future versions might B<croak()> on this.

=head1 BUGS

Maybe.

=head1 SEE ALSO

L<POE::Queue::Array>

=head1 AUTHORS & COPYRIGHTS

Made 2009 by Lars Stoltenow.
List::PriorityQueue is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

POE::Queue::Array is Copyright 1998-2007 Rocco Caputo. All rights reserved.
Same license.

=cut
