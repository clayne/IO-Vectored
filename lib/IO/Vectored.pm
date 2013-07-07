package IO::Vectored;

use strict;

use Carp;

our $VERSION = '0.100';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(sysreadv syswritev);

require XSLoader;
XSLoader::load('IO::Vectored', $VERSION);


sub sysreadv(*@) {
  my $fh = shift;

  my $fileno = fileno($fh);
  croak("closed or invalid file-handle passed to sysreadv") if !defined $fileno || $fileno < 0;

  return _backend($fileno, 0, @_);
}

sub syswritev(*@) {
  my $fh = shift;

  my $fileno = fileno($fh);
  croak("closed or invalid file-handle passed to syswritev") if !defined $fileno || $fileno < 0;

  return _backend($fileno, 1, @_);
}

sub IOV_MAX() {
  return _get_iov_max();
}

1;



__END__


=encoding utf-8

=head1 NAME

IO::Vectored - Read from or write to multiple buffers at once


=head1 WRITE SYNOPSIS

    use IO::Vectored;

    syswritev($file_handle, "hello", "world") || die "syswritev: $!";


=head1 READ SYNOPSIS

    use IO::Vectored;

    my $buf1 = ' ' x 5;
    my $buf2 = ' ' x 5;

    sysreadv($file_handle, $buf1, $buf2) || die "sysreadv: $!";

    ## if input is "abcdef" then:
    ##  $buf1 eq "abcde"
    ##  $buf2 eq "d    "


=head1 IOV_MAX SYNOPSIS

    use IO::Vectored;

    print "This system's maximum number of elements in a vector is: " . IO::Vectored::IOV_MAX;


=head1 DESCRIPTION

Vectored-IO is sometimes called "scatter/gather IO". The idea is that instead of doing multiple C<read(2)> or C<write(2)> system calls for each string you wish to read/write, your userspace program creates a vector of the various strings and does a single system call.

Although some people consider these interfaces contrary to the simple design principles of unix, they are often more efficient for several reasons.

This module is an interface to your system's L<readv(2)|http://pubs.opengroup.org/onlinepubs/009695399/functions/readv.html> and L<writev(2)|http://pubs.opengroup.org/onlinepubs/009695399/functions/writev.html> vectored-IO system calls specified by POSIX.1. It exports the functions C<syswritev> and C<sysreadv> which are almost the same as the L<syswrite> and L<sysread> perl functions except for some minor differences described below.

The most apparent advantage of vectored-IO is that it reduces the number of system calls required and system calls have a certain overhead.

Another potential advantage of vectored-IO is that doing multiple system calls can sometimes result in excess network packets being sent. The classic example of this is a web-server writing an HTTP response. If the server C<write(2)>s the HTTP headers and then C<write(2)>s the HTTP body then the kernel might send the headers and body in separate network packets instead of a single packet which is more latency and bandwidth-optimal. L<TCP_CORK|http://baus.net/on-tcp_cork/> is a solution to this issue but it is linux-specific and can require more system calls.

Of course an alternative to vectored-IO is to copy the buffers together into a contiguous buffer before calling C<write(2)>. The performance disadvantage in this is that a potentially large buffer needs to be allocated and then all the smaller buffers copied into it. Also, if your buffers are backed by memory-mapped files (ie with L<File::Map>) then this approach results in an unnecessary copy of the data to userspace. If you use vectored-IO then files can be copied directly from the file-system cache into the socket's L<mbuf|http://www.openbsd.org/cgi-bin/man.cgi?query=mbuf>. The non-standard C<sendfile(2)> system call can theoretically do this with even fewer copies but it requires a system call for each file sent, unlike C<syswritev>.

Note that as with anything the performance benefits of vectored-IO will vary from application to application and you shouldn't retro-fit vectored-IO onto an application unless benchmarking has shown measurable benefits. However, vectored-IO can sometimes be more convenient than regular-IO and may be worth using for this reason alone.



=head1 RETURN VALUES AND ERROR CONDITIONS

As mentioned above, this module's interface mirrors C<syswrite> and C<sysread> so the same caveats that apply to those functions apply to the vectored interfaces. In particular, you should not mix these calls with userspace-buffered interfaces such as L<print> or L<seek>. Mixing the vectored interfaces with C<syswrite> and C<sysread> is fine though.

C<syswritev> returns the number of bytes written (usually the sum of the lengths of all arguments). C<sysreadv> returns the number of bytes read. Note that unlike C<sysread>, C<sysreadv> will not truncate any buffers (see the L<READ SYNOPSIS> above).

Both of these functions can also return C<undef> if the underlying C<readv(2)> or C<writev(2)> system calls fail for any reason other than C<EINTR>. In this case, C<$!> will be set with the error.

Like C<sysread>/C<syswrite>, the vectored versions also croak for various reasons (see the C<t/exceptions.t> test for a full list). Some examples are: passing in too many arguments (greater than the C<IO::Vectored::IOV_MAX> constant), trying to use a closed file-handle, and trying to write to a read-only/constant string.



=head1 TODO

To the extent possible, make it do the right thing for file-handles with non-raw encodings and unicode strings.

Investigate if there is a performance benefit from eliminating the perl wrapper subs and re-implementing their logic in XS.

Think about truncating strings like C<sysread>. Don't depend on this behaviour of C<sysreadv> until version 1.000: You have been warned. :)

Think about whether this module should support vectors larger than C<IOV_MAX> by calling C<writev>/C<readv> multiple times. This should probably be a opt-in because it breaks atomicity guarantees.

Support windows with C<ReadFileScatter>, C<WriteFileGather>, L<WSASend>, and L<WSARecv>.



=head1 SEE ALSO

L<IO-Vectored github repo|https://github.com/hoytech/IO-Vectored>

Useful modules to combine with vectored-IO:

L<File::Map> / L<Sys::Mmap>

L<String::Slice> / L<overload::substr>

C<sendfile()> interfaces (less general than and not really compatible with vectored-IO):

L<Sys::Sendfile> / L<Sys::Syscall> / L<Sys::Sendfile::FreeBSD>


=head1 AUTHOR

Doug Hoyte, C<< <doug@hcsw.org> >>


=head1 COPYRIGHT & LICENSE

Copyright 2013 Doug Hoyte.

This module is licensed under the same terms as perl itself.

=cut
