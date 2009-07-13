#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 8;

use List::PriorityQueue;

my $q = new List::PriorityQueue;

# try to insert an already existing element.
# you shouldn't do that anyway and use update instead, but if you suck so
# much that you cannot, then you at least shouldn't confuse the module with
# duplicates. - so insert DOES call update if the entry exists, but it
# could just as well croak.
$q->insert("a", 2);
$q->insert("a", 5);
$q->insert("b", 3);
is($q->pop(), "b", "1st retrieved element is b");
is($q->pop(), "a", "2nd retrieved element is a");
ok(!defined($q->pop()), "no 3rd element");

# what happens when an element is deleted that is not in the queue?
ok(!defined($q->delete("x")), "returns undef when deleting from empty queue");
$q->insert("blah", 5);
ok(!defined($q->delete("x")), "returns undef when deleting non-present item");

# if a non existing element is updated, it should be added.
# (note: future versions might recommend update() for everything, in this case
#  this test is irrelevant as insert() has already been tested.)
$q->update("foo", 2);
is($q->pop(), "foo",  "1st retrieved element is foo");
is($q->pop(), "blah", "2nd retrieved element is blah");
ok(!defined($q->pop()), "no 3rd element");

