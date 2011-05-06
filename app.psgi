use strict;
use lib qw(lib);
use Plack::Builder;
use App::MarkdownBinder;

my $app = App::MarkdownBinder->new(
    root => './doc',
    suffix => '.md',
    base_url => '/',
    title => 'App::MarkdownBinder',
    top => 'README'
);

builder {
    enable 'Static',
        path => qr!^/static/!, root => './htdocs/';
    enable 'Static',
        path => qr!^/(?:favicon.ico|robots.txt)$!, root => './htdocs/';
    $app;
};
