
use strict;
use Encode;
use Path::Class;
use Plack::Builder;
use Plack::Request;
use Text::Markdown;
use Text::Xslate;

my $doc_dir = dir($ENV{'MARKDOWN_BINDER_DOC'} || './doc/')->absolute;
my $top     = $ENV{'MARKDOWN_BINDER_TOP'} || 'TOP';
my $suffix  = '.txt';

no strict 'refs';
*{'Path::Class::Entity::depth'} = sub {
  my ($self) = @_;
  scalar( () = $self=~/(\/)/g );
};
*{'Path::Class::Dir::children'} = sub {
  my ($self, %opts) = @_;
  
  my $dh = $self->open or Carp::croak( "Can't open directory $self: $!" );
  
  my @out;
  while (defined(my $entry = $dh->read)) {
    next if !$opts{all} && $self->_is_local_dot_dir($entry);
    next if ($opts{no_hidden} && $entry =~ /^\./);
    push @out, $self->file($entry);
    $out[-1] = $self->subdir($entry) if -d $out[-1];
  }
  return sort {
    return $a->is_dir <=> $b->is_dir if $a->is_dir != $b->is_dir;
    return $a cmp $b;
  } @out;
};

my $cache = {
    doc_files => [],
    doc_mtime => undef,
    docs      => {}
};

my $get_files = sub {
    if ($doc_dir->stat->mtime > $cache->{doc_mtime}) {
        my @files;
        $doc_dir->recurse(
            preorder => 1,
            depthfirst => 1,
            callback => sub {
                my $file = shift;
                my $path = decode('utf8', $file);
                $path=~s|^$doc_dir||;
                return unless length $path;
                $path = -f $file ? file($path) : dir($path);
                push @files, $path;
            }
        );
        $cache->{doc_files} = \@files;
        $cache->{doc_mtime} = $doc_dir->stat->mtime;
        return @files;
    } else {
        return @{ $cache->{doc_files} };
    }
};

my $get_html = sub {
    my $file = shift;
    my $base_path = quotemeta $doc_dir;
    return 'security error.' unless $file=~/^$base_path/;
    return '404 not found.' unless -f $file;
    if ($file->stat->mtime > $cache->{docs}->{$file->stringify}->{mtime}) {
        my $text = $file->slurp;
        my $html = Text::Markdown->new->markdown($text);
        $cache->{docs}->{$file->stringify}->{mtime} = $file->stat->mtime;
        $cache->{docs}->{$file->stringify}->{html} = $html;
        return $html;
    } else {
        return $cache->{docs}->{$file->stringify}->{html};
    }
};

my $app = sub {
    my $req = Plack::Request->new(shift);

    return [ 200, [ 'Content-Type' => 'text/plain' ], [ '' ] ]
        if $req->path eq '/favicon.ico';


    my $res = $req->new_response(200);
    
    if (my $file = $req->param('file')) {
        $file.= $top if $file eq '/';
        my $path = file($doc_dir, $file . $suffix)->resolve;
        my $html = $get_html->($path);
        $res->content_type('text/html; charset=UTF-8');
        $res->body($html);
    }

    else {
        my $file = substr $req->path, 1;
           $file ||= $top;
        my $path = file($doc_dir, $file . $suffix)->resolve;
        my $html = $get_html->($path);
        my @dirs;
        my @files = $get_files->();
        my $tx = Text::Xslate->new(
            path   => './',
            module => ['Text::Xslate::Bridge::TT2Like'],
            syntax => 'TTerse'
        );
        my $content = $tx->render('index.html', { files => \@files, content => $html });
        $res->content_type('text/html; charset=UTF-8');
        $res->body(encode('utf8', $content));
    }
    
    return $res->finalize;
};

builder {
    enable 'Static',
        path => qr!^/static!, root => './htdocs/';
    $app;
};
