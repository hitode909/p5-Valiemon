package JSON::Schema::Validator;
use 5.008001;
use strict;
use warnings;
use utf8;

use Carp qw(croak);
use JSON::Schema::Validator::Primitives;
use JSON::Schema::Validator::Context;
use JSON::Schema::Validator::Attributes qw(attr);

use Class::Accessor::Lite (
    ro => [qw(schema options pos schema_cache)],
);

our $VERSION = "0.02";

sub new {
    my ($class, $schema, $options) = @_;

    # TODO should validate own schema
    if ($options->{validate_schema}) {}
    croak 'schema must be a hashref' unless ref $schema eq 'HASH';

    return bless {
        schema       => $schema,
        options      => $options,
        schema_cache => +{},
    }, $class;
}

sub validate {
    my ($self, $data, $context) = @_;
    my $schema = $self->schema;

    $context //= JSON::Schema::Validator::Context->new($self, $schema);

    for my $key (keys %{$schema}) {
        my $attr = attr($key);
        if ($attr) {
            my ($is_valid, $error) = $attr->is_valid($context, $schema, $data);
            unless ($is_valid) {
                $context->push_error($error);
                next;
            }
        }
    }

    my $errors = $context->errors;
    my $is_valid = scalar @$errors ? 0 : 1;
    return wantarray ? ($is_valid, $errors->[0]) : $is_valid;
}

sub prims {
    my ($self) = @_;
    return $self->{prims} //= JSON::Schema::Validator::Primitives->new(
        $self->options
    );
}

sub ref_schema_cache {
    my ($self, $ref, $schema) = @_;
    return defined $schema
        ? $self->schema_cache->{$ref} = $schema
        : $self->{schema_cache}->{ref};
}

sub resolve_ref {
    my ($self, $ref) = @_;

    # TODO follow the standard referencing
    unless ($ref =~ qr|^#/|) {
        croak 'This package support only single scope and `#/` referencing';
    }

    return $self->ref_schema_cache($ref) || do {
        my $paths = do {
            my @p = split '/', $ref;
            [ splice @p, 1 ]; # remove '#'
        };
        my $sub_schema = $self->schema;
        {
            eval { $sub_schema = $sub_schema->{$_} for @$paths };
            croak sprintf 'referencing `%s` cause error', $ref if $@;
            croak sprintf 'schema `%s` not found', $ref unless $sub_schema;
        }
        $self->ref_schema_cache($ref, $sub_schema); # caching
        $sub_schema;
    };
}


1;

__END__

=encoding utf-8

=head1 NAME

JSON::Schema::Validator - It's a validation module based on JSON Schema

http://json-schema.org/latest/json-schema-core.html
http://json-schema.org/latest/json-schema-validation.html

This module is under development!
So there are some unimplemented features, and module api will be changed.

=head1 SYNOPSIS

    use JSON::Schema::Validator;

    # create instance with schema definition
    my $validator = JSON::Schema::Validator->new({
        type => 'object',
        properties => {
            name  => { type => 'string'  },
            price => { type => 'integer' },
        },
        requried => ['name', 'price'],
    });

    # validate data
    my ($res, $error);
    ($res, $error) = $validator->validate({ name => 'unadon', price => 1200 });
    # $res   => 1
    # $error => undef

    ($res, $error) = $validator->validate({ name => 'tendon', price => 'hoge' });
    # $res   => 0
    # $error => object JSON::Schema::Validation::Error
    # $error->position => '/properties/price/type'

=head1 LICENSE

MIT

=head1 AUTHOR

pokutuna E<lt>popopopopokutuna@gmail.comE<gt>

=cut
