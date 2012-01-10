package WebService::MyGengo::Response;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

extends 'WebService::MyGengo::Base';

use HTTP::Response;
use JSON;

=head1 NAME

WebService::MyGengo::Response - An API response object

=head1 DESCRIPTION

A generic API response object.

Wraps a L<HTTP::Response> received from the API with extra functionality.

=head1 SYNOPSIS

    # Responses are created for you by WebService::MyGengo::Client
    my $http_res = $user_agent->request( $some_request );
    my $res = WebService::MyGengo::Response->new( $http_res );

    # Some deserialized data structure from the API
    my $struct = $res->response_struct; # ref($struct) eq 'HASH'

=head1 ATTRIBUTES

=head2 response_struct

Returns the deserialized response structure for successful API calls as a
hashref.

If the API response is not a hash it will be wrapped into a hash as
`{ elements => \@elements }` for consistency.

If the response was a failure, returns undef.

=cut
has response_struct => (
    is => 'ro'
    , isa => 'Maybe[HashRef]'
    , lazy => 1
    , builder => '_build_response_struct'
    );
sub _build_response_struct {
    my ( $self ) = ( shift );

    $self->is_error and return undef;

    my $struct = $self->_deserialized->{response};

    ref($struct) ne 'HASH' and return { elements => $struct };

    return $struct;
}

=head2 error_code

If the HTTP request was successful, but the API returned an error response,
returns the API error code.

If the HTTP request was successful and the API returned a non-error response,
returns undef.

If the L<HTTP::Response> itself was an error, no API payload will be available;
 In this case returns 0.

todo Use the Exception object or make an APIError object

todo This needs a big rethink: complex.

=cut
has error_code => (
    is          => 'ro'
    , isa       => 'Maybe[WebService::MyGengo::ErrorCode]'
    , lazy      => 1
    , builder   => '_build_error_code'
    );
sub _build_error_code {
    my ( $self ) = ( shift );

    $self->_raw_response->is_error and return 0;

    my $struct = $self->_deserialized
        or return undef;

    $struct->{opstat} eq 'error'
        and return $struct->{err}->{code};

    return undef;
}

=head2 _raw_response

The original HTTP::Response object.

Provides: code, message, status_line

=cut
has _raw_response => (
    is          => 'ro'
    , isa       => 'HTTP::Response'
    , required  => 1
    # todo I think there's moose sugar to avoid listing all of these
    , handles => [ qw/code message status_line/ ]
#                code message header content decoded_content request previous
#                status_line base filename as_string is_info
#                is_redirect error_as_HTML redirects current_age
#                freshness_lifetime is_fresh fresh_until
#                / ]
    );

=head2 _serializer

A JSON object.

B<Note:> The API also supports XML. We do not. :)

=cut
has _serializer => (
    is          => 'ro'
    , isa       => 'JSON'
    , init_arg  => undef
    , lazy      => 1
    , builder   => '_build__serializer'
    );
sub _build__serializer {
    return new JSON;
}

=head2 _deserialized

The deserialized response body.

Returns undef if the body could not be deserialized.

=cut
has _deserialized => (
    is          => 'ro'
    , isa       => 'Maybe[HashRef]'
    , init_arg  => undef
    , lazy      => 1
    , builder   => '_build__deserialized'
    );
sub _build__deserialized {
    my ( $self ) = ( shift );

    my $raw = $self->_raw_response;
    my $struct = eval {
        return $self->_serializer->allow_nonref->utf8->relaxed
                    ->decode( $raw->content );
    };

    # This will never be called outside of testing
    $@ and Carp::cluck("Could not deserialize response: " . $raw->status_line );

    return $struct;
}
   
=head1 METHODS

=head2 BUILDARGS

Accept arguments as a list.

=cut
around BUILDARGS  => sub {
    my ( $orig, $class, $args ) = ( shift, shift, @_ );

    return { _raw_response => shift };
};

=head2 is_success

If the original response is_success, then also check for errors in the
response payload.

Otherwise, return false.

=cut
sub is_success {
    my ( $self ) = ( shift );

    $self->_raw_response->is_error and return 0;

    return !$self->error_code;
}

=head2 is_error

Returns the opposite of L<is_success>

=cut
sub is_error { return !shift->is_success; }


__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;

=head2 TODO

 * Would inheriting from L<HTTP::Response> be worthwhile?

=head1 AUTHOR

Nathaniel Heinrichs

=head1 LICENSE

Copyright (c) 2011, Nathaniel Heinrichs <nheinric-at-cpan.org>.
All rights reserved.

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
