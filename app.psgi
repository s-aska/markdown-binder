
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
my $top          = $ENV{'MARKDOWN_BINDER_TOP'} || 'TOP';
my $suffix       = '.md';
my $toppage      = $top . $suffix;

my $default_conf = {
    title => 'no title',
    footer => 'copyright'
};

my $conf = -f $conf_file ? decode_json($conf_file->slurp) : $default_conf;

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
my $rebuild = sub {
    my $cache_clean = shift;
    @files = ();
    if ($cache_clean) {
        $cache_dir->rmtree if -d $cache_dir;
        $cache_dir->mkpath;
    }
    $doc_dir->recurse(
        preorder => 1,
        depthfirst => 1,
        callback => sub {
            my $file = shift;
            my $path = decode('utf8', $file);
            $path=~s|^$doc_dir||;
            return if substr(file($path)->basename, 0, 1) eq '.';
            return unless length $path;
            if (-f $file && $file=~/$suffix$/) {
                $path = file($path);
                my $text = $file->slurp;
                my $html = Text::Markdown->new->markdown($text);
                $html=~s|>\n{2,}<|>\n<|g;
                $html=~s|\n$||;
                my $cache_file = file($cache_dir, substr($path, 0, -3) . '.html');
                if (!-f $cache_file or ($cache_file->stat->mtime <= $file->stat->mtime)) {
                    $cache_file->dir->mkpath unless -d $cache_file->dir;
                    my $fh = $cache_file->openw;
                    $fh->print($html);
                    $fh->close;
                    warn 'create cached ', $path;
                } else {
                    warn 'find cached ', $path;
                }
            } elsif (-d $file) {
                $path = dir($path);
                warn 'find dir ', $path;
            }
            push @files, $path;
        }
    );
};
$rebuild->();

my $res_200 = [ 200, [ 'Content-Type' => 'text/html' ], [ '' ] ];
my $res_403 = [ 403, [ 'Content-Type' => 'text/html' ], [ '403 Forbidden.' ] ];
my $res_404 = [ 404, [ 'Content-Type' => 'text/html' ], [ '404 Not Found.' ] ];

my $check_path = sub {
    return 1 if grep($_ eq '..', split('/', shift));
    return ;
};

my $render = sub {
    my ($req, $path, $params) = @_;
    my $tx = Text::Xslate->new(
        path   => './',
        module => ['Text::Xslate::Bridge::TT2Like'],
        syntax => 'TTerse'
    );
    my $content = $tx->render($path, $params);
    my $res = $req->new_response(200);
    $res->content_type('text/html; charset=UTF-8');
    $res->body(encode('utf8', $content));
    return $res->finalize;
};

my $app = sub {
    my $req = Plack::Request->new(shift);
    
    # check path
    return $res_403 if $check_path->($req->path);

    my $file = $req->path;
       $file.= $top if $file eq '/';
    
    my $cache_file = file($cache_dir, $file . '.html');
    my $text_file = file($doc_dir, $file . $suffix);
    
    if (!-f $cache_file) {
        return $res_404;
    }
    
    my $html = decode('utf8', $cache_file->slurp);
    
    my $template = 'index.html';
    
    $template = 'iphone.html' if $req->user_agent=~/iPhone/;
    
    return
        $render->($req, $template, {
            req     => $req,
            conf    => $conf,
            files   => \@files,
            content => $html,
            path    => decode('utf8', $req->path)
        });
};

builder {
    enable 'Static',
        path => qr!^/static|^(/favicon.ico|/robots.txt)$!, root => './htdocs/';
    enable 'Static',
        path => qr!\.html$!, root => $cache_dir;
    enable 'Static',
        path => qr!\.(txt|md)$!, root => $doc_dir;
    if (-f $htpasswd) {
        enable 'Auth::Htpasswd', file => $htpasswd;
    }
#    enable 'XForwardedFor',
#        trust => [qw(127.0.0.1/8)];
    $app;
};
