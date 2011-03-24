
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
use Text::Xslate qw(html_builder);

my $base_dir   = dirname(__FILE__);
my $doc_dir    = dir(abs_path($ENV{'MARKDOWN_BINDER_DOC'} || catdir($base_dir, 'doc')));
my $cache_dir  = dir(abs_path($ENV{'MARKDOWN_BINDER_CACHE'} || catdir($base_dir, 'cache')));
my $tx_dir     = abs_path(catdir($base_dir, 'view'));
my $htpasswd   = file(abs_path($ENV{'MARKDOWN_BINDER_PW'} || catfile($base_dir, '.htpasswd')));
my $iprules    = file(abs_path($ENV{'MARKDOWN_BINDER_IP'} || catfile($base_dir, '.iprules')));
my $conf_file  = file(abs_path($ENV{'MARKDOWN_BINDER_CONF'} || catfile($base_dir, 'config.json')));
my $top        = 'TOP';
my $suffix     = '.md';
my $watcher    = catfile($base_dir, 'watcher.pl');

my $res_403 = [ 403, [ 'Content-Type' => 'text/html' ], [ '403 Forbidden.' ] ];
my $res_404 = [ 404, [ 'Content-Type' => 'text/html' ], [ '404 Not Found.' ] ];

my $tx = Text::Xslate->new(
    path     => [$tx_dir, $cache_dir],
    module   => ['Text::Xslate::Bridge::TT2Like'],
    syntax   => 'TTerse',
    function => {
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

&watch() unless $ENV{'MARKDOWN_BINDER_VIEWER'}; # can with watch standalone only.

my $app = sub {
    my $req = Plack::Request->new(shift);
    
    my $file  = ($req->path eq '/' ? $top : $req->path) . '.html';
    return $res_403 if grep($_ eq '..', split('/', $req->path));
    
    my %extra_params;
    unless (-f catfile($cache_dir, $file)) {
        $file = '404.tx';
        $extra_params{files} = decode_json(file($cache_dir, 'sidebar.json')->slurp);
    }
    
    my $conf = decode_json($conf_file->slurp);
    my $is_iphone = $req->user_agent=~/iPhone/ ? 1 : 0;
    my $template = $is_iphone ? 'iphone.html' : 'index.html';
    my $body = $tx->render($template, {
        req       => $req,
        conf      => $conf,
        cache     => $file,
        path      => decode('utf8', $req->path),
        is_iphone => $is_iphone,
        %extra_params
    });
    
    my $res = $req->new_response(200);
    $res->content_type('text/html; charset=UTF-8');
    $res->body(encode('utf8', $body));
    $res->finalize;
};

builder {
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
    enable 'Static',
        path => qr!^/static/!, root => './htdocs/';
    enable 'Static',
        path => qr!^/(?:favicon.ico|robots.txt)$!, root => './htdocs/';
    enable 'Static',
        path => qr!\.html$!, root => $cache_dir;
    enable 'Static',
        path => qr!$suffix$!, root => $doc_dir;
    $app;
};

sub watch {
    my $pid = fork;
    return if $pid;
    $ENV{'MARKDOWN_BINDER_REQUIRE'} = 1;
    require $watcher;
}
