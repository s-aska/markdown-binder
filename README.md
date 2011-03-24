# Markdown Binder

Ajax Markdown Viewer written in Perl, to run under Plack.

- demo: [The Document of Aska](http://doc.7kai.org)
- source: [github](https://github.com/s-aska/app-markdown-binder-plack)
- author: [@su_aska](http://twitter.com/su_aska)

## Features
1. **High Speed** ( Ajax Page Loading and Pre Convert HTML )
2. pushState Support
3. no javascript Support ( bot, curl, wget...etc )
4. **Pure Markdown** ( not extend grammar )
5. Plack Application
6. HTML5

## Install

    git clone git@github.com:s-aska/app-markdown-binder-plack.git
    cd app-markdown-binder-plack
    cpanm Path::Class Text::Markdown Text::Xslate

## How to use

### Run

    plackup
    # Ctrl-C stop

### Customize title and footer

    vi config.json

### Edit page

    vi doc/TOP.md
    vi doc/Hoge.md
    mkdir doc/Foo
    vi doc/Foo/Bar.md

## See also
- PSGI/Plack: <http://plackperl.org/>
- The Plack wiki: <https://github.com/miyagawa/Plack/wiki>
- The Plack FAQ: <https://github.com/miyagawa/Plack/wiki/Faq>
- Markdown: <http://daringfireball.net/projects/markdown/>
- Markdown Syntax: <http://daringfireball.net/projects/markdown/syntax>

## License
Released under the [MIT license](http://creativecommons.org/licenses/MIT/).
