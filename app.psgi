
use strict;
use Encode;
use Path::Class;
use Plack::Builder;
use Plack::Request;
use Text::Markdown;
use Text::Xslate;

my $doc_dir = dir($ENV{'MKREADER_DOC'} || './doc/')->absolute;
my $top     = $ENV{'MKREADER_TOP'} || 'TOP';
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

my $cache = {};

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
            $cache->{encode('utf8', $path)} = $html;
            warn 'cached ', $path;
        } else {
            $path = dir($path);
        }
        push @files, $path;
    }
);
my $get_html = sub {
    my $path = shift;
    $path.= $suffix;
    warn "not found $path" unless exists $cache->{$path};
    return '404 not found.' unless exists $cache->{$path};
    return $cache->{$path};
};

my $app = sub {
    my $req = Plack::Request->new(shift);

    return [ 200, [ 'Content-Type' => 'text/plain' ], [ '' ] ]
        if $req->path eq '/favicon.ico';


    my $res = $req->new_response(200);
    
    if (my $file = $req->param('file')) {
        $file.= $top if $file eq '/';
        my $html = $get_html->($file);
        $res->content_type('text/html; charset=UTF-8');
        $res->body($html);
    }

    else {
        my $file = substr $req->path, 1;
           $file ||= $top;
        my $html = $get_html->($file);
        my @dirs;
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
