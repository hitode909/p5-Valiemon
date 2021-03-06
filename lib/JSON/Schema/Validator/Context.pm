package JSON::Schema::Validator::Context;
use strict;
use warnings;
use utf8;

use JSON::Schema::Validator::ValidationError;

use Class::Accessor::Lite (
    ro => [qw(root_validator root_schema errors positions)],
);

sub new {
    my ($class, $validator, $schema) = @_;
    return bless {
        root_validator => $validator,
        root_schema    => $schema,
        errors         => [],
        positions      => [],
    }, $class;
}

sub rv { $_[0]->root_validator }
sub rs { $_[0]->root_schema }

sub prims { $_[0]->root_validator->prims } # TODO refactor

sub push_error {
    my ($self, $error) = @_;
    push @{$self->errors}, $error;
}

sub push_pos {
    my ($self, $pos) = @_;
    push @{$self->positions}, $pos;
}

sub pop_pos {
    my ($self) = @_;
    pop @{$self->positions};
}

sub is_root {
    my ($self) = @_;
    return scalar @{$self->positions} == 0 ? 1 : 0;
}

sub position {
    my ($self) = @_;
    return '/' . join '/', @{$self->positions};
}

sub generate_error {
    my ($self, $attr) = @_;
    return JSON::Schema::Validator::ValidationError->new($attr, $self->position);
}

sub in_attr ($&) {
    my ($self, $attr, $code) = @_;
    $self->push_pos($attr->attr_name);
    my $is_valid = $code->();
    my @res = $is_valid ? (1, undef) : (0, $self->generate_error($attr));
    $self->pop_pos();
    return @res;
}

sub in ($&) {
    my ($self, $pos, $code) = @_;
    $self->push_pos($pos);
    my $res = $code->();
    $self->pop_pos();
    return $res;
}

sub sub_validator {
    my ($self, $sub_schema) = @_;
    require JSON::Schema::Validator;
    return JSON::Schema::Validator->new(
        $sub_schema,
        $self->rv->options, # inherit options
    );
}

1;
