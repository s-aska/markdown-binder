
use strict;
use Cwd 'abs_path';
use Encode;
use File::Basename;
use File::Copy;
use File::Spec::Functions qw(abs2rel catdir catfile);
use Filesys::Notify::Simple;
use JSON;
use Path::Class;
use Plack::Builder;
use Plack::Request;
use Text::Markdown;
use Text::Xslate;

my $base_dir     = dirname(__FILE__);
my $doc_dir      = dir(abs_path($ENV{'MARKDOWN_BINDER_DOC'} || catdir($base_dir, 'doc')));
my $cache_dir    = dir(abs_path($ENV{'MARKDOWN_BINDER_CACHE'} || catdir($base_dir, 'cache')));
my $htpasswd     = file($ENV{'MARKDOWN_BINDER_PW'} || catfile($base_dir, '.htpasswd'));
my $iprules      = file($ENV{'MARKDOWN_BINDER_IP'} || catfile($base_dir, '.iprules'));
my $conf_file    = file($ENV{'MARKDOWN_BINDER_CONF'} || catfile($base_dir, 'config.json'));
my $top          = 'TOP';
my $suffix       = '.md';
my $toppage      = $top . $suffix;
my $suffix_ptn = quotemeta $suffix;

my $res_403 = [ 403, [ 'Content-Type' => 'text/html' ], [ '403 Forbidden.' ] ];
my $res_404 = [ 404, [ 'Content-Type' => 'text/html' ], [ '404 Not Found.' ] ];

my $tx = Text::Xslate->new(
    path   => ['./', $cache_dir],
    module => ['Text::Xslate::Bridge::TT2Like'],
    syntax => 'TTerse'
);

&watch();

my $app = sub {
    my $req = Plack::Request->new(shift);
    
    my $file  = ($req->path eq '/' ? $top : $req->path) . '.html';
    return $res_403 if grep($_ eq '..', split('/', $req->path));
    return $res_404 unless -f catfile($cache_dir, $file);
    
    my $conf = decode_json($conf_file->slurp);
    my $is_iphone = $req->user_agent=~/iPhone/ ? 1 : 0;
    my $template = $is_iphone ? 'iphone.html' : 'index.html';
    my $body = $tx->render($template, {
        req       => $req,
        conf      => $conf,
        cache     => $file,
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
    if ($ENV{REVERSEPROXY}) {
        enable 'XForwardedFor', trust => [qw(127.0.0.1/8)];
    }
    if (-f $htpasswd) {
        enable 'Auth::Htpasswd', file => $htpasswd;
    }
    if (-f $iprules) {
        enable 'IPAddressFilter', rules => [
            grep /\./, split "\n", $iprules->slurp
        ];
    }
    $app;
};

sub watch {
    my $pid = fork;
    return if $pid;
    
    open(STDERR, '>>debug.log') if $ENV{'DEBUG'};
    
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
    my $create_cache = sub {
        my $source = shift;
        my $rel_path = decode('utf8', abs2rel($source, $doc_dir));
        my $cache = file($cache_dir, substr($rel_path, 0, -1 * (length $suffix)) . '.html');
        return if -f $cache and $cache->stat->mtime >= $source->stat->mtime;
        $cache->dir->mkpath unless -d $cache->dir;
        my $text = $source->slurp;
        my $html = Text::Markdown->new->markdown($text);
        $html=~s|>\n{2,}<|>\n<|g;
        $html=~s|\n$||;
        my $create = not -f $cache;
        my $fh = $cache->openw;
        $fh->print($html);
        $fh->close;
        warn 'create cached ', $cache;
        return $create;
    };
    my $rebuild = sub {
        my $cache_check = shift;
        @files = ();
        $doc_dir->recurse(
            preorder => 1,
            depthfirst => 1,
            callback => sub {
                my $path = shift;
                return if $path eq $doc_dir;
                return if -f $path and $path!~m|$suffix_ptn$|;
                $create_cache->($path) if $cache_check and -f $path;
                my $rel_path = decode('utf8', '/' . abs2rel($path, $doc_dir));
                my $file = -f $path ? file($rel_path) : dir($rel_path);
                push @files, $file;
            }
        );
        
        my @dusts;
        $cache_dir->recurse(
            callback => sub {
                my $cache = shift;
                return unless -e $cache;
                my $rel_path = decode('utf8', abs2rel($cache, $cache_dir));
                return if $rel_path eq 'sidebar';
                my $source = -f $cache
                           ? file($doc_dir, substr($rel_path, 0, -5) . $suffix)
                           :  dir($doc_dir, $rel_path);
                return if -e $source;
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
        
        my $str = $tx->render('sidebar.tx', {
            files => \@files
        });
        
        my $sidebar = file($cache_dir, 'sidebar');
        my $sidebar_tmp = $sidebar . '.tmp';
        open(my $fh, '>', $sidebar_tmp) or die $!;
        print $fh encode('utf8', $str);
        close $fh;
        rename($sidebar_tmp, $sidebar);
        warn "update sidebar";
    };
    $rebuild->(1);
    
    while (1) {
        my $watcher = Filesys::Notify::Simple->new([$doc_dir]);
        $watcher->wait(sub {
            my $update;
            for my $event (@_) {
                if (-f $event->{path}) {
                    $update = 1 if $create_cache->(file($event->{path}));
                } else {
                    $update = 1;
                }
            }
            $rebuild->() if $update;
        });
    }
    
    exit(1);
}
