package App::MarkdownBinder;

use strict;
use warnings;
use parent 'DocLife';
use Plack::Util::Accessor qw(top title tx);
use Encode;
use Encode::Locale;
use File::Spec::Functions qw(abs2rel);
use Path::Class;
use Text::Markdown;
use Text::Xslate qw/html_builder/;

if ($^O eq 'darwin') {
    require Encode::UTF8Mac;
    $Encode::Locale::ENCODING_LOCALE_FS = 'utf-8-mac';
}

sub prepare_app {
    my ($self, $env) = @_;
    $self->SUPER::prepare_app($env);
    my $tx = Text::Xslate->new(
        path => ['./view/binder'],
        module => ['Text::Xslate::Bridge::TT2Like'],
        syntax => 'TTerse',
        function => {
            markdown => html_builder {
                Text::Markdown::markdown(shift);
            },
            same_highlight => sub {
                my ($path) = @_;
                return html_builder {
                    my ($html) = @_;
                    for my $part (split '/', $path) {
                        next unless length $part;
                        $html=~s|$part|<strong>$part<\/strong>|ig;
                    }
                    $html;
                }
            }
        }
    );
    $self->tx($tx);
    $self->top('TOP') unless length $self->top;
}

sub toppage {
    my ($self, $req, $res) = @_;
    my $tx = $self->tx;
    my $file = file($self->root, $self->top . $self->suffix);
    my $page = $tx->render('wrap.tx', {
        app => $self,
        file => (-f $file ? $file : undef)
    });
    $res->body(encode_utf8($page));
}

sub page {
    my ($self, $req, $res) = @_;
    my $file = file($self->root, $req->path . $self->suffix);
    if ($req->path=~/(.*)\.html$/) {
        my $path = $1 eq '/' ? $self->top : $1;
        my $file = file($self->root, $path . $self->suffix);
        if (-f $file) {
            $res->body(Text::Markdown::markdown(scalar($file->slurp)));
        }
        else {
            $self->SUPER::not_found($req, $res);
        }
    }
    elsif (-f $file) {
        $self->format($req, $res, $file);
    }
    else {
        $self->not_found($req, $res, $file);
    }
}

sub not_found {
    my ($self, $req, $res, $file) = @_;
    
    my $body = $self->tx->render('wrap.tx', {
        is_404 => 1,
        app => $self,
        path => $req->path
    });
    $res->status(404);
    $res->body(encode_utf8($body));
}

sub format {
    my ($self, $req, $res, $file) = @_;
    my $body = $self->tx->render('wrap.tx', {
        app => $self,
        file => $file
    });
    $res->body(encode_utf8($body));
}

sub get_files {
    my ($self, $dir) = @_;
    my @files = $dir->children(no_hidden => 1);
    my $toppage = $self->top . $self->suffix;
    @files = sort {
        return $a->is_dir <=> $b->is_dir if $a->is_dir != $b->is_dir;
        return ($b->basename eq $toppage) <=> ($a->basename eq $toppage)
            if $a->basename eq $toppage or $b->basename eq $toppage;
        return $a cmp $b;
    } @files;
    \@files;
}

sub get_basename {
    my ($self, $file) = @_;
    my $suffix = $self->suffix;
    my $basename = decode('locale_fs', $file->basename);
    $basename=~s|\Q$suffix\E$||;
    $basename;
}

sub get_path {
    my ($self, $file) = @_;
    my $suffix = $self->suffix;
    my $path = decode('locale_fs', abs2rel($file, $self->root));
    $path=~s|\Q$suffix\E$||;
    $path = '' if $path eq $self->top;
    $self->base_url . $path;
}

sub get_recursive_files {
    my ($self) = @_;
    my @files;
    use File::Find;
    find( sub {
        my $file = $File::Find::name;
        if (-f $file) {
            push @files, file($file);
        } else {
            push @files, dir($file);
        }
    }, $self->root );
    return \@files;
}

=head1 NAME

MarkdownBinder

=head1 SYNOPSIS

    use strict;
    use App::MarkdownBinder;

    App::MarkdownBinder->new(
        suffix => '.md',
        root => './doc',
    );

=cut

1;
