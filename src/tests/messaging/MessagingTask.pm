#-*-Mode:perl;coding:utf-8;tab-width:4;c-basic-offset:4;indent-tabs-mode:()-*-
# ex: set ft=perl fenc=utf-8 sts=4 ts=4 sw=4 et:
#
# BSD LICENSE
# 
# Copyright (c) 2014, Michael Truog <mjtruog at gmail dot com>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the
#       distribution.
#     * All advertising materials mentioning features or use of this
#       software must display the following acknowledgment:
#         This product includes software developed by Michael Truog
#     * The name of the author may not be used to endorse or promote
#       products derived from this software without specific prior
#       written permission
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
#

package MessagingTask;
use strict;
use warnings;

my $use_threads = eval 'use threads; 1';
require CloudI::API;
require CloudI::TerminateException;

sub new
{
    my $class = shift;
    my ($api, $thread_index) = @_;
    my $self = bless {
        api => $api,
        thread_index => $thread_index,
    }, $class;
    return $self;
}

sub run
{
    my $self = shift;
    eval
    {
        $self->{api}->subscribe('a/b/c/d', $self, '_sequence1_abcd');
        $self->{api}->subscribe('a/b/c/*', $self, '_sequence1_abc_');
        $self->{api}->subscribe('a/b/*/d', $self, '_sequence1_ab_d');
        $self->{api}->subscribe('a/*/c/d', $self, '_sequence1_a_cd');
        $self->{api}->subscribe('*/b/c/d', $self, '_sequence1__bcd');
        $self->{api}->subscribe('a/b/*',   $self, '_sequence1_ab__');
        $self->{api}->subscribe('a/*/d',   $self, '_sequence1_a__d');
        $self->{api}->subscribe('*/c/d',   $self, '_sequence1___cd');
        $self->{api}->subscribe('a/*',     $self, '_sequence1_a___');
        $self->{api}->subscribe('*/d',     $self, '_sequence1____d');
        $self->{api}->subscribe('*',       $self, '_sequence1_____');
        $self->{api}->subscribe('sequence1', $self, '_sequence1');
        $self->{api}->subscribe('e', $self, '_sequence2_e1');
        $self->{api}->subscribe('e', $self, '_sequence2_e2');
        $self->{api}->subscribe('e', $self, '_sequence2_e3');
        $self->{api}->subscribe('e', $self, '_sequence2_e4');
        $self->{api}->subscribe('e', $self, '_sequence2_e5');
        $self->{api}->subscribe('e', $self, '_sequence2_e6');
        $self->{api}->subscribe('e', $self, '_sequence2_e7');
        $self->{api}->subscribe('e', $self, '_sequence2_e8');
        $self->{api}->subscribe('sequence2', $self, '_sequence2');
        $self->{api}->subscribe('f1', $self, '_sequence3_f1');
        $self->{api}->subscribe('f2', $self, '_sequence3_f2');
        $self->{api}->subscribe('g1', $self, '_sequence3_g1');
        $self->{api}->subscribe('sequence3', $self, '_sequence3');
        if ($self->{thread_index} == 0)
        {
            $self->{api}->send_async(
                $self->{api}->prefix() . 'sequence1', 'start');
        }
        my $result = $self->{api}->poll();
        assert($result == 0);
    };
    my $e = $@;
    if ($e)
    {
        if ($e->isa('CloudI::TerminateException'))
        {
            1;
        }
        else
        {
            print "$e";
        }
    }
    print "terminate messaging perl\n";
}

sub assert
{
    my ($test) = @_;
    CloudI::API->assert($test);
}

sub _sequence1_abcd
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . 'a/b/c/d'));
    assert($request eq 'test1');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1_abc_
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . 'a/b/c/*'));
    assert($request eq 'test2' || $request eq 'test3');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1_ab_d
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . 'a/b/*/d'));
    assert($request eq 'test4' || $request eq 'test5');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1_a_cd
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . 'a/*/c/d'));
    assert($request eq 'test6' || $request eq 'test7');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1__bcd
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . '*/b/c/d'));
    assert($request eq 'test8' || $request eq 'test9');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1_ab__
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . 'a/b/*'));
    assert($request eq 'test10');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1_a__d
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . 'a/*/d'));
    assert($request eq 'test11');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1___cd
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . '*/c/d'));
    assert($request eq 'test12');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1_a___
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . 'a/*'));
    assert($request eq 'test13');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1____d
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . '*/d'));
    assert($request eq 'test14');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1_____
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    assert($pattern eq ($self->{api}->prefix() . '*'));
    assert($request eq 'test15');
    $self->{api}->return_($command, $name, $pattern,
                          '', $request, $timeout, $trans_id, $pid);
}

sub _sequence1
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    my @end = $self->{api}->recv_async(1000);
    while ($end[1] eq 'end')
    {
        @end = $self->{api}->recv_async(1000);
    }
    print "messaging sequence1 start perl\n";
    assert($request eq 'start');
    # n.b., depends on cloudi_constants.hrl having
    # SERVICE_NAME_PATTERN_MATCHING defined
    my $test1_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/b/c/d',  'test1');
    my $test2_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/b/c/z',  'test2');
    my $test3_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/b/c/dd', 'test3');
    my $test4_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/b/z/d',  'test4');
    my $test5_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/b/cc/d', 'test5');
    my $test6_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/z/c/d',  'test6');
    my $test7_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/bb/c/d', 'test7');
    my $test8_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'z/b/c/d',  'test8');
    my $test9_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'aa/b/c/d', 'test9');
    my $test10_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/b/czd',  'test10');
    my $test11_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/bzc/d',  'test11');
    my $test12_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'azb/c/d',  'test12');
    my $test13_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'a/bzczd',  'test13');
    my $test14_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'azbzc/d',  'test14');
    my $test15_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'azbzczd',  'test15');
    # n.b., depends on cloudi_constants.hrl having
    # RECV_ASYNC_STRATEGY == recv_async_select_oldest
    my $tmp;
    $self->{api}->recv_async(undef, $test1_id, 0);
    my $test1_check;
    my $test1_id_check;
    ($tmp, $test1_check, $test1_id_check) = $self->{api}->recv_async();
    assert($test1_check eq 'test1');
    assert($test1_id_check eq $test1_id);
    $self->{api}->recv_async(undef, $test2_id, 0);
    my $test2_check;
    my $test2_id_check;
    ($tmp, $test2_check, $test2_id_check) = $self->{api}->recv_async();
    assert($test2_check eq 'test2');
    assert($test2_id_check eq $test2_id);
    $self->{api}->recv_async(undef, $test3_id, 0);
    my $test3_check;
    my $test3_id_check;
    ($tmp, $test3_check, $test3_id_check) = $self->{api}->recv_async();
    assert($test3_check eq 'test3');
    assert($test3_id_check eq $test3_id);
    $self->{api}->recv_async(undef, $test4_id, 0);
    my $test4_check;
    my $test4_id_check;
    ($tmp, $test4_check, $test4_id_check) = $self->{api}->recv_async();
    assert($test4_check eq 'test4');
    assert($test4_id_check eq $test4_id);
    $self->{api}->recv_async(undef, $test5_id, 0);
    my $test5_check;
    my $test5_id_check;
    ($tmp, $test5_check, $test5_id_check) = $self->{api}->recv_async();
    assert($test5_check eq 'test5');
    assert($test5_id_check eq $test5_id);
    $self->{api}->recv_async(undef, $test6_id, 0);
    my $test6_check;
    my $test6_id_check;
    ($tmp, $test6_check, $test6_id_check) = $self->{api}->recv_async();
    assert($test6_check eq 'test6');
    assert($test6_id_check eq $test6_id);
    $self->{api}->recv_async(undef, $test7_id, 0);
    my $test7_check;
    my $test7_id_check;
    ($tmp, $test7_check, $test7_id_check) = $self->{api}->recv_async();
    assert($test7_check eq 'test7');
    assert($test7_id_check eq $test7_id);
    $self->{api}->recv_async(undef, $test8_id, 0);
    my $test8_check;
    my $test8_id_check;
    ($tmp, $test8_check, $test8_id_check) = $self->{api}->recv_async();
    assert($test8_check eq 'test8');
    assert($test8_id_check eq $test8_id);
    $self->{api}->recv_async(undef, $test9_id, 0);
    my $test9_check;
    my $test9_id_check;
    ($tmp, $test9_check, $test9_id_check) = $self->{api}->recv_async();
    assert($test9_check eq 'test9');
    assert($test9_id_check eq $test9_id);
    $self->{api}->recv_async(undef, $test10_id, 0);
    my $test10_check;
    my $test10_id_check;
    ($tmp, $test10_check, $test10_id_check) = $self->{api}->recv_async();
    assert($test10_check eq 'test10');
    assert($test10_id_check eq $test10_id);
    $self->{api}->recv_async(undef, $test11_id, 0);
    my $test11_check;
    my $test11_id_check;
    ($tmp, $test11_check, $test11_id_check) = $self->{api}->recv_async();
    assert($test11_check eq 'test11');
    assert($test11_id_check eq $test11_id);
    $self->{api}->recv_async(undef, $test12_id, 0);
    my $test12_check;
    my $test12_id_check;
    ($tmp, $test12_check, $test12_id_check) = $self->{api}->recv_async();
    assert($test12_check eq 'test12');
    assert($test12_id_check eq $test12_id);
    $self->{api}->recv_async(undef, $test13_id, 0);
    my $test13_check;
    my $test13_id_check;
    ($tmp, $test13_check, $test13_id_check) = $self->{api}->recv_async();
    assert($test13_check eq 'test13');
    assert($test13_id_check eq $test13_id);
    $self->{api}->recv_async(undef, $test14_id, 0);
    my $test14_check;
    my $test14_id_check;
    ($tmp, $test14_check, $test14_id_check) = $self->{api}->recv_async();
    assert($test14_check eq 'test14');
    assert($test14_id_check eq $test14_id);
    $self->{api}->recv_async(undef, $test15_id, 0);
    my $test15_check;
    my $test15_id_check;
    ($tmp, $test15_check, $test15_id_check) = $self->{api}->recv_async();
    assert($test15_check eq 'test15');
    assert($test15_id_check eq $test15_id);
    print "messaging sequence1 end perl\n";
    # start sequence2
    $self->{api}->send_async($self->{api}->prefix() . 'sequence2', 'start');
    $self->{api}->return_($command, $name, $pattern,
                          '', 'end', $timeout, $trans_id, $pid);
}

sub _sequence2_e1
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '1', $timeout, $trans_id, $pid);
}

sub _sequence2_e2
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '2', $timeout, $trans_id, $pid);
}

sub _sequence2_e3
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '3', $timeout, $trans_id, $pid);
}

sub _sequence2_e4
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '4', $timeout, $trans_id, $pid);
}

sub _sequence2_e5
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '5', $timeout, $trans_id, $pid);
}

sub _sequence2_e6
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '6', $timeout, $trans_id, $pid);
}

sub _sequence2_e7
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '7', $timeout, $trans_id, $pid);
}

sub _sequence2_e8
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', '8', $timeout, $trans_id, $pid);
}

sub _sequence2
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    print "messaging sequence2 start perl\n";
    assert($request eq 'start');
    while (1)
    {
        # the sending process is excluded from the services that receive
        # the asynchronous message, so in this case, the receiving thread
        # will not be called, despite the fact it has subscribed to 'e',
        # to prevent a process (in this case thread) from deadlocking
        # with itself.
        my @e_ids = $self->{api}->mcast_async(
            $self->{api}->prefix() . 'e', ' ');
        # 4 * 8 == 32, but only 3 out of 4 threads can receive messages,
        # since 1 thread is sending the mcast_async, so 3 * 8 == 24
        if (scalar(@e_ids) == 24)
        {
            my @e_check_list = ();
            for my $e_id (@e_ids)
            {
                my ($tmp,
                    $e_check,
                    $e_id_check) = $self->{api}->recv_async(undef, $e_id);
                assert($e_id eq $e_id_check);
                push(@e_check_list, $e_check);
            }
            assert(join('', sort(@e_check_list)) eq '111222333444555666777888');
            last;
        }
        else
        {
            my $services = 4 - scalar(@e_ids) / 8.0;
            print "Waiting for $services services to initialize\n";
            for my $e_id (@e_ids)
            {
                my ($tmp,
                    $e_check,
                    $e_id_check) = $self->{api}->recv_async(undef, $e_id);
                assert($e_id eq $e_id_check);
            }
            my @null = $self->{api}->recv_async(1000);
            assert($null[2] eq "\0" x 16);
        }
    }
    print "messaging sequence2 end perl\n";
    # start sequence3
    $self->{api}->send_async($self->{api}->prefix() . 'sequence3', 'start');
    $self->{api}->return_($command, $name, $pattern,
                          '', 'end', $timeout, $trans_id, $pid);
}

sub _sequence3_f1
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request_i,
        $timeout, $priority, $trans_id, $pid) = @_;
    if ($request_i == 4)
    {
        return 'done';
    }
    my $request_new = $request_i + 2; # two steps forward
    $self->{api}->forward_($command, $self->{api}->prefix() . 'f2',
                           $request_info, $request_new,
                           $timeout, $priority, $trans_id, $pid);
}

sub _sequence3_f2
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request_i,
        $timeout, $priority, $trans_id, $pid) = @_;
    my $request_new = $request_i - 1; # one step back
    $self->{api}->forward_($command, $self->{api}->prefix() . 'f1',
                           $request_info, $request_new,
                           $timeout, $priority, $trans_id, $pid);
}

sub _sequence3_g1
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    $self->{api}->return_($command, $name, $pattern,
                          '', $request . 'suffix', $timeout, $trans_id, $pid);
}

sub _sequence3
{
    my $self = shift;
    my ($command, $name, $pattern, $request_info, $request,
        $timeout, $priority, $trans_id, $pid) = @_;
    print "messaging sequence3 start perl\n";
    assert($request eq 'start');
    my $test1_id = $self->{api}->send_async(
        $self->{api}->prefix() . 'f1',  '0');
    my $tmp;
    my $test1_check;
    my $test1_id_check;
    ($tmp, $test1_check, $test1_id_check) = $self->{api}->recv_async(
        undef, $test1_id);
    assert($test1_id_check eq $test1_id);
    assert($test1_check eq 'done');
    my $test2_check;
    my $test2_id_check;
    ($tmp, $test2_check, $test2_id_check) = $self->{api}->send_sync(
        $self->{api}->prefix() . 'g1',  'prefix_');
    assert($test2_check eq 'prefix_suffix');
    print "messaging sequence3 end perl\n";
    # loop to find any infrequent problems, restart sequence1
    $self->{api}->send_async($self->{api}->prefix() . 'sequence1', 'start');
    $self->{api}->return_($command, $name, $pattern,
                          '', 'end', $timeout, $trans_id, $pid);
}

{
    assert($use_threads);
    my $thread_count = CloudI::API->thread_count();
    my @threads = ();
    for my $i (0 .. ($thread_count - 1))
    {
        my $t = threads->create(sub
        {
            my $task = MessagingTask->new(CloudI::API->new($i), $i);
            return $task->run();
        });
        assert(defined($t));
        push(@threads, $t);
    }
    for my $t (@threads)
    {
        $t->join();
    }
}

1;
