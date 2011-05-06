# App::MarkdownBinder

App::MarkdownBinder is Ajax Markdown Viewer written in Perl, to run under Plack.

- source: [github](https://github.com/s-aska/markdown-binder)
- author: [@su_aska](http://twitter.com/su_aska)
- author's note(and demo): [The Document of Aska](http://doc.7kai.org)

## Features
1. **High Speed** ( Ajax Page Loading )
2. pushState Support
3. no javascript Support ( bot, curl, **wget -r** ...etc )
4. **Pure Markdown** ( not extend grammar )
5. **Text Editor** \> WYSIWIG
6. Plack Application
7. HTML5

## Demo
<iframe src="http://www.screenr.com/embed/yDo" width="650" height="396" frameborder="0"></iframe>

## Install
    git clone git@github.com:s-aska/markdown-binder.git
    cd markdown-binder
    cpanm DocLife Text::Xslate

## How to use

### Run
    plackup

### Edit
    # create page
    touch doc/README.md
    
    # modify page
    vi doc/README.md
    
    # remove page
    rm doc/README.md
    
    # create directory
    mkdir doc/howto

## See also
- PSGI/Plack: <http://plackperl.org/>
- The Plack wiki: <https://github.com/miyagawa/Plack/wiki>
- The Plack FAQ: <https://github.com/miyagawa/Plack/wiki/Faq>
- Markdown: <http://daringfireball.net/projects/markdown/>
- Markdown Syntax: <http://daringfireball.net/projects/markdown/syntax>

## License
Released under the [MIT license](http://creativecommons.org/licenses/MIT/).


<!-- # README

Document Viewer written in Perl, to run under Plack.

Pod Viewer

    plackup -MDocLife::Pod -e 'DocLife::Pod->new( { root => "./lib" } )->to_app'

Pod and Markdown Viewer

    use strict;
    use Plack::Builder;
    use DocLife::Pod;
    use DocLife::Markdown;

    my $pod_app = DocLife::Pod->new(
        root => './lib',
        base_url => '/pod/'
    );

    my $doc_app = DocLife::Markdown->new(
        root => './doc',
        suffix => '.md',
        base_url => '/doc/'
    );

    builder {
        mount '/doc' => $md_app;
        mount '/pod' => $pod_app;
    };

- Demo: <http://pad.demo.7kai.org>

Blog and Note with Dropbox.

    use strict;
    use Plack::Builder;
    use App::MarkdownBinder;
    use App::MarkdownDiary;

    my $doc_app = App::MarkdownBinder->new(
        root => $ENV{'HOME'}.'/Dropbox/doc',
        suffix => '.md',
        base_url => '/',
        title => 'The Document of Aska'
    );

    my $blog_app = App::MarkdownDiary->new(
        root => $ENV{'HOME'}.'/Dropbox/blog',
        suffix => '.md',
        base_url => '/',
        title => 'The Diary of Aska',
        footer => '&copy; 七階',
        rss_url => 'http://blog.7kai.org'
    );

    builder {
        enable 'Static',
            path => qr!^/static/!, root => './htdocs/';
        enable 'Static',
            path => qr!^/(?:favicon.ico|robots.txt)$!, root => './htdocs/';
        mount 'http://doc.7kai.org/' => $doc_app;
        mount 'http://blog.7kai.org/' => $blog_app;
    }; -->
