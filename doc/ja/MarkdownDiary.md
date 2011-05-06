# App::MarkdownDiary

App::MarkdownDiaryはApp::MarkdownBinderから派生して作られた簡易blogです。

どんな見た目になるかは作者の[blog](http://blog.7kai.org/)を参照下さい。

Markdown形式のテキストファイルのみで構成、WebUIなし、DBなし、拡張文法なし。

この割り切りによって移植性の高いblogとして完成されています。

DISQUS, zenback 等外部サービスを利用すればコメント管理を内蔵する必要もありません。

Xslateのfilterでmarkdownを変換している箇所を書き換えれば他のフォーマットを利用する事も出来ます。

    # app.psgi
    use strict;
    use App::MarkdownDiary;

    my $app = App::MarkdownDiary->new(
        root => $ENV{'HOME'}.'/Dropbox/blog',
        suffix => '.md',
        base_url => '/',
        title => 'Your Site Name',
        footer => '&copy; Your Copyright',
        rss_url => 'http://example.com',
        viewdir => './path/to/custom_template'
    );

## 更新方法

rootに指定したディレクトリ配下にファイルを置きます。

    touch 2011042023.demo.md

ファイル名は YYYYMMDDHH.PAGE-NAME.md です、拡張子はsuffixで指定が可能ですが、日付は必ず必要です。

この日付が更新日時として認識されます、カレンダーやアーカイブ、RSSの日付もこれを元にしています。

次に、記事をカテゴリーに属させる方法です。

カテゴリーを作るにはrootに指定したディレクトリ配下にディレクトリを作ります。

    mkdir category1

カテゴリーに記事を属させるには、記事をそのカテゴリー配下に移動させます。

    mv 2011042023.demo.md category1

複数のカテゴリーに属させるには、以下のようにします。

    mkdir category1/category2
    mv 2011042023.demo.md category1/category2

あまりお勧めはしません。

## 更新の反映

更新を反映するには、**/:rebuild** にアクセスするか、プロセスを再起動します。

ローカルで記事を編集しても何かアクション起こすまでリモートに反映させない事ができます。

## カスタマイズ

example/view/diary/ 配下のファイルを直接更新するのが手っ取り早いですが、Xslateのpathにより優先順位の高いパスを設定するオプションがあります。

    my $blog_app = App::MarkdownDiary->new(
        #
        # other option
        #
        viewdir => './view/my_diary'
    );

    cp -pr view/diary view/my_diary

### テンプレートの構成

- head.tx         ... headエレメント内に展開されます、cssやscriptを配置します
- page_foot.tx    ... 各記事のfooterです、DISQUS/Tweet/Facebook Like等配置します
- sidebar.tx      ... サイドバーです
- sidebar_head.tx ... サイドバーの上部に展開されます、プロフィール等を配置します
- wrap.tx         ... 全体のラッパーです
