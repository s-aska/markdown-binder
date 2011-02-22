
use strict;
use Encode;
use Path::Class;
use Plack::Builder;
use Plack::Request;
use Text::Markdown;
use Text::Xslate;

my $doc_dir   = dir($ENV{'MARKDOWN_BINDER_DOC'} || './doc/')->absolute;
my $top       = $ENV{'MARKDOWN_BINDER_TOP'} || 'TOP';
my $suffix    = '.txt';
my $cache_dir = dir($ENV{'MARKDOWN_BINDER_CACHE'} || './cache/')->absolute;

$cache_dir->rmtree if -d $cache_dir;
$cache_dir->mkpath;

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

my @files;
$doc_dir->recurse(
    preorder => 1,
    depthfirst => 1,
    callback => sub {
        my $file = shift;
        my $path = decode('utf8', $file);
        $path=~s|^$doc_dir||;
        return unless length $path;
        if (-f $file) {
            $path = file($path);
            my $text = $file->slurp;
            my $html = Text::Markdown->new->markdown($text);
            my $cache_file = file($cache_dir, substr($path, 0, -4) . '.html');
            $cache_file->dir->mkpath unless -d $cache_file->dir;
            my $fh = $cache_file->openw;
            $fh->print($html);
            $fh->close;
            warn 'cached ', $path;
        } else {
            $path = dir($path);
        }
        push @files, $path;
    }
);

my $app = sub {
    my $req = Plack::Request->new(shift);

    my $file = $req->path;
       $file.= $top if $file eq '/';
    my $path = file($cache_dir, $file . '.html');
    if ($path->resolve!~/^$cache_dir/) {
        return [ 200, [ 'Content-Type' => 'text/plain' ], [ '403 Forbidden.' ] ];
    } elsif (!-f $path) {
        return [ 200, [ 'Content-Type' => 'text/plain' ], [ '404 Not Found.' ] ];
    }
    my $html = $path->slurp;
    my $tx = Text::Xslate->new(
        path   => './',
        module => ['Text::Xslate::Bridge::TT2Like'],
        syntax => 'TTerse'
    );
    my $content = $tx->render('index.html', { files => \@files, content => $html });
    my $res = $req->new_response(200);
    $res->content_type('text/html; charset=UTF-8');
    $res->body(encode('utf8', $content));
    
    return $res->finalize;
};

builder {
    enable 'Static',
        path => qr!^/static|^(/favicon.ico|/robots.txt)$!, root => './htdocs/';
    enable 'Static',
        path => qr!\.html$!, root => $cache_dir;
    enable 'Static',
        path => qr!\.txt$!, root => $doc_dir;
    $app;
};
