
use strict;
use Encode;
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use JSON;
use Path::Class;
use Plack::Builder;
use Plack::Request;
use Text::Markdown;
use Text::Xslate;

my $base_dir     = dirname(__FILE__);
my $doc_dir      = dir($ENV{'MARKDOWN_BINDER_DOC'} || catdir($base_dir, 'doc'))->absolute;
my $cache_dir    = dir($ENV{'MARKDOWN_BINDER_CACHE'} || catdir($base_dir, 'cache'))->absolute;
my $htpasswd     = file($ENV{'MARKDOWN_BINDER_PW'} || catfile($base_dir, '.htpasswd'));
my $conf_file    = file($ENV{'MARKDOWN_BINDER_CONF'} || catfile($base_dir, 'config.json'));
my $top          = 'TOP';
my $suffix       = '.md';
my $toppage      = $top . $suffix;

my $conf = decode_json($conf_file->slurp);

# override Path::Class method
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
    return ($b->basename eq $toppage) <=> ($a->basename eq $toppage)
        if $a->basename eq $toppage or $b->basename eq $toppage;
    return $a cmp $b;
  } @out;
};

my @files;
my $doc_dir_regexp = quotemeta $doc_dir;
my $cache_dir_regexp = quotemeta $cache_dir;
my $suffix_regexp = quotemeta $suffix;
my $rebuild = sub {
    @files = ();
    $doc_dir->recurse(
        preorder => 1,
        depthfirst => 1,
        callback => sub {
            my $path = shift;
            my ($file) = decode('utf8', $path)=~m|^$doc_dir_regexp(.*)$|;
            return if substr(basename($path), 0, 1) eq '.';
            return unless length $file;
            if (-f $path and $file=~m|^(.*)$suffix_regexp$|) {
                $file = file($file);
                my $cache = file($cache_dir, $1 . '.html');
                my $text = $path->slurp;
                my $html = Text::Markdown->new->markdown($text);
                $html=~s|>\n{2,}<|>\n<|g;
                $html=~s|\n$||;
                if (!-f $cache or ($cache->stat->mtime <= $path->stat->mtime)) {
                    $cache->dir->mkpath unless -d $cache->dir;
                    my $fh = $cache->openw;
                    $fh->print($html);
                    $fh->close;
                    warn 'create cached ', $path;
                } else {
                    warn 'find cached ', $path;
                }
            } elsif (-d $path) {
                $file = dir($file);
                warn 'find dir ', $file;
            } else {
                warn $path;
            }
            push @files, $file;
        }
    );
    my @dusts;
    $cache_dir->recurse(
        callback => sub {
            my $cache = shift;
            return if (!-f $cache) and (!-d $cache);
            my ($file) = decode('utf8', $cache)=~m|^$cache_dir_regexp(.*)$|;
            if (-f $cache and $file=~m|^(.*)\.html$|) {
                return if -f file($doc_dir, $1 . $suffix);
            } elsif (-d $cache) {
                return if -d dir($doc_dir, $file);
            }
            push @dusts, $cache;
        }
    );
    for my $dust (@dusts) {
        if (-f $dust) {
            $dust->remove;
            warn "remove cached $dust";
        } elsif (-d $dust) {
            $dust->rmtree;
            warn "rmtree cached $dust";
        }
    }
};
$rebuild->();

my $res_403 = [ 403, [ 'Content-Type' => 'text/html' ], [ '403 Forbidden.' ] ];
my $res_404 = [ 404, [ 'Content-Type' => 'text/html' ], [ '404 Not Found.' ] ];

my $tx = Text::Xslate->new(
    path   => './',
    module => ['Text::Xslate::Bridge::TT2Like'],
    syntax => 'TTerse'
);

my $app = sub {
    my $req = Plack::Request->new(shift);
    
    my $cache = $req->path eq '/'
              ? file($cache_dir, $top . '.html')
              : file($cache_dir, $req->path . '.html');
    return $res_403 if grep($_ eq '..', split('/', $req->path));
    return $res_404 unless -f $cache;
    
    my $is_iphone = $req->user_agent=~/iPhone/ ? 1 : 0;
    my $template = $is_iphone ? 'iphone.html' : 'index.html';
    my $body = $tx->render($template, {
        req       => $req,
        conf      => $conf,
        files     => \@files,
        content   => decode('utf8', $cache->slurp),
        path      => decode('utf8', $req->path),
        is_iphone => $is_iphone
    });
    
    my $res = $req->new_response(200);
    $res->content_type('text/html; charset=UTF-8');
    $res->body(encode('utf8', $body));
    $res->finalize;
};

builder {
    enable 'Static',
        path => qr!^/static/!, root => './htdocs/';
    enable 'Static',
        path => qr!^/(?:favicon.ico|robots.txt)$!, root => './htdocs/';
    enable 'Static',
        path => qr!\.html$!, root => $cache_dir;
    enable 'Static',
        path => qr!$suffix$!, root => $doc_dir;
    if (-f $htpasswd) {
        enable 'Auth::Htpasswd', file => $htpasswd;
    }
#    enable 'XForwardedFor',
#        trust => [qw(127.0.0.1/8)];
    $app;
};
