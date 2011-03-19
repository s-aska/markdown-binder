# Markdown Binder

Markdown Viewer

[demo](http://doc.7kai.org)

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

    vi doc/TOP.txt
    vi doc/Hoge.txt
    mkdir doc/Foo
    vi doc/Foo/Bar.txt

## Directory

    ├── app.psgi    ... server side program
    ├── config.json ... title and footer
    ├── index.html  ... template
    ├── iphone.html ... iPhone's template
    ├── sidebar.tx  ... side bar template
    ├── doc         ... document directory
    │   └── TOP.txt ... top page
    └── htdocs
        ├── favicon.ico
        ├── robots.txt
        └── static
            ├── css
            │   └── style.css ... style sheet
            └── js
                └── binder.js ... client side program
## Features
1. Pure Markdown ( not extend grammar )
2. HTML5
3. Plack Application
4. Support Ajax Page Loading
5. Support pushState
6. Support no js ( bot, curl )

## See also
- PSGI/Plack: <http://plackperl.org/>
- The Plack wiki: <https://github.com/miyagawa/Plack/wiki>
- The Plack FAQ: <https://github.com/miyagawa/Plack/wiki/Faq>
- Markdown: <http://daringfireball.net/projects/markdown/>
- Markdown Syntax: <http://daringfireball.net/projects/markdown/syntax>

## License
Released under the [MIT license](http://creativecommons.org/licenses/MIT/).

