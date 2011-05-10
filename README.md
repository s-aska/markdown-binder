# App::MarkdownBinder

App::MarkdownBinder is Ajax Markdown Viewer written in Perl, to run under Plack.

- document: <http://pad.demo.7kai.org/note/>
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
<http://www.screenr.com/embed/yDo>

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