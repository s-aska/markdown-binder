# Markdown Binder

Ajax Markdown Viewer written in Perl, to run under Plack.

- demo: [The Document of Aska](http://doc.7kai.org)
- source: [github](https://github.com/s-aska/app-markdown-binder-plack)
- author: [@su_aska](http://twitter.com/su_aska)

## Features
1. Pure Markdown ( not extend grammar )
2. Plack Application
3. HTML5
4. Ajax Page Loading
5. pushState Support
6. no javascript Support ( bot, curl, wget...etc )

## Install

    git clone git@github.com:s-aska/app-markdown-binder-plack.git
    cd app-markdown-binder-plack
    cpanm Path::Class Text::Markdown Text::Xslate

## How to use

### Run

    plackup -R doc

### Customize title and footer

    vi config.json

### Edit page

    vi doc/TOP.md
    vi doc/Hoge.md
    mkdir doc/Foo
    vi doc/Foo/Bar.md

### Private ( Basic Auth )

    cpanm Plack::Middleware::Auth::Htpasswd
    htpasswd -c .htpasswd username

## See also
- PSGI/Plack: <http://plackperl.org/>
- The Plack wiki: <https://github.com/miyagawa/Plack/wiki>
- The Plack FAQ: <https://github.com/miyagawa/Plack/wiki/Faq>
- Markdown: <http://daringfireball.net/projects/markdown/>
- Markdown Syntax: <http://daringfireball.net/projects/markdown/syntax>

## License
Released under the [MIT license](http://creativecommons.org/licenses/MIT/).

