package App::MarkdownDiary;

use strict;
use warnings;
use parent 'DocLife';
use Plack::Util::Accessor qw(tx title footer rss_url viewdir tmpdir max_recents max_disp);
use Calendar::Simple;
use Cwd 'abs_path';
use Data::MessagePack;
use Digest::MD5;
use Encode;
use File::Spec;
use File::Spec::Functions qw(abs2rel catdir);
use HTML::Entities;
use Path::Class;
use Text::Markdown;
use Text::Xslate qw/html_builder/;
use XML::RSS::LibXML;

sub prepare_app {
    my ($self, $env) = @_;
    $self->SUPER::prepare_app($env);
    my $tx = Text::Xslate->new(
        path => [$self->viewdir, './view/diary'],
        module => ['Text::Xslate::Bridge::TT2Like'],
        syntax => 'TTerse',
        function => {
            markdown => html_builder {
                Text::Markdown::markdown(shift);
            },
            summary => sub {
                my ($html) = @_;
                $html = decode_utf8($html);
                $html=~s|.*||;
                $html=~s|<.*?>||mg;
                $html;
            }
        }
    );
    $self->tx($tx);
    unless ($self->tmpdir) {
        my $dir = Digest::MD5::md5_hex($self->root);
        my $tmpdir = catdir(File::Spec->tmpdir(), $dir);
        unless (-d $tmpdir) {
            mkdir $tmpdir, 0700;
        }
        $self->tmpdir($tmpdir);
    }
    $self->max_recents(10) unless $self->max_recents;
    $self->max_disp(100) unless $self->max_disp;
    $self->rebuild;
}

sub toppage {
    my $self = shift;
    $self->page(@_);
}

sub page {
    my ($self, $req, $res) = @_;
    
    if ($req->path eq '/:rebuild') {
        $self->rebuild;
        $res->body('rebuild success.');
        return;
    }
    
    my $mode;
    my $title;
    my $entries = $self->load_entries;
    my @entries;
    my @recents = @$entries;
    @recents = splice @recents, 0, ($self->max_recents - 1) if scalar(@recents) > $self->max_recents;
    if ($req->path eq '/') {
        @entries = ($entries->[0]);
    } elsif ($req->path=~m|^/(\d{4})/$|) {
        $mode = 'year';
        my $year = $1;
        @entries = grep {
            $_->{year} eq $year
        } @$entries;
    } elsif ($req->path=~m|^/(\d{4})/(\d{2})/$|) {
        $mode = 'month';
        my ($year, $month) = ($1, $2);
        @entries = grep {
            $_->{year} eq $year and $_->{month} eq $month
        } @$entries;
    } elsif ($req->path=~m|^/(\d{4})/(\d{2})/(\d{2})/$|) {
        $mode = 'day';
        my ($year, $month, $mday) = ($1, $2, $3);
        @entries = grep {
            $_->{year} eq $year and $_->{month} eq $month and  $_->{mday} eq $mday
        } @$entries;
    } elsif ($req->path=~m|^/category/([^/]+)|) {
        $mode = 'category';
        my $category = $1;
        @entries = grep {
            scalar(grep { $_ eq $category } @{$_->{category}})
        } @$entries;
    } elsif ($req->path=~m|^/(\d{4})/(\d{2})/([^/]+)|) {
        my ($year, $month, $page) = ($1, $2, $3);
        $mode = 'entry';
        @entries = grep {
            $_->{year} eq $year and
            $_->{month} eq $month and
            $_->{page} eq $page
        } @$entries;
        @entries = $entries[0] if scalar(@entries) > 1;
        unless (@entries) {
            $self->not_found($req, $res);
            return;
        }
        $title = $entries[0]->{title};
    } elsif ($req->path eq '/index.rdf') {
        $res->content_type('text/plain; charset=utf-8');
        $res->body($self->rss_file->openr);
        return ;
    }
    
    @entries = splice @entries, 0, ($self->max_disp - 1) if scalar(@entries) > $self->max_disp;
    
    $mode = 'entry' if scalar(@entries) == 1;
    
    my $page = $self->tx->render('wrap.tx', {
        app => $self,
        entries => \@entries,
        mode => $mode,
        title => decode_utf8($title)
    });
    $res->body(encode_utf8($page));
}

sub rebuild {
    my ($self) = @_;
    
    my $entries = $self->find_entries;
    
    # save cache
    $self->store_entries($entries);
    
    my @recents = @$entries;
    @recents = splice(@recents, 0, ($self->max_recents - 1))
        if scalar(@recents) > $self->max_recents;
    
    # save sidebar
    $self->rebuild_sidebar($entries, \@recents);

    # save rss
    $self->rebuild_rss(\@recents);
}

sub url {
    my ($self, $url) = @_;
    $url=~s|^/|| if $self->base_url=~m|/$|;
    $self->base_url . $url;
}

sub find_entries {
    my ($self) = @_;
    
    my $entries = [];
    $self->root->recurse(
        callback => sub {
            my $file = shift;
            if (-f $file and -s $file) {
                push @$entries, $self->file_to_entry($file);
            }
        }
    );
    @$entries = sort { $b->{date} cmp $a->{date} } @$entries;
    $entries;
}

sub file_to_entry {
    my ($self, $file) = @_;
    
    my ($year, $month, $mday, $hour, $page)
        = $file->basename=~m|(\d{4})(\d{2})(\d{2})(\d{2})\.(.*)\.md|;
    my $date    = sprintf '%04d/%02d/%02d %02d:00', $year, $month, $mday, $hour;
    my $iso     = sprintf '%04d-%02d-%02dT%02d:00:00+0900', $year, $month, $mday, $hour;
    my $url     = sprintf '/%04d/%02d/%s/', $year, $month, $page;
    my $abs_url = sprintf '%s%s', $self->rss_url, $url;
    my $title;
    my $fh = $file->openr;
    chomp( $title = <$fh> );
    $fh->close;
    $title = decode_utf8($title);
    $title=~s|^#\s*||;
    my @category =
        grep { $_ ne '.' and $_=~/[^\d]/ }
        split '/', abs2rel($file->dir, $self->root);
    +{
        year     => $year,
        month    => $month,
        mday     => $mday,
        date     => $date,
        iso      => $iso,
        page     => $page,
        url      => $url,
        abs_url  => $abs_url,
        file     => $file->stringify,
        md       => "$month/$mday",
        title    => $title,
        category => \@category
    };
}

sub rebuild_sidebar {
    my ($self, $entries, $recents) = @_;
    
    my $entry_hash = {};
    my $month_hash = {};
    my $day_hash = {};
    my $category_hash = {};
    for my $entry ( @$entries ) {
        $entry_hash->{ $entry->{page} } = $entry;
        $month_hash->{ $entry->{year} . $entry->{month} } ||= {
            year  => $entry->{year},
            month => $entry->{month},
            name  => $entry->{year} . '/' . $entry->{month},
            url   => '/' . $entry->{year} . '/' . $entry->{month} . '/'
        };
        $month_hash->{ $entry->{year} . $entry->{month} }->{count}++;
        $day_hash->{ $entry->{year} . $entry->{month} . $entry->{mday} }++;
        for (@{ $entry->{category} }) {
            $category_hash->{$_} ||= {
                name => $_,
                url  => "/category/$_/"
            };
            $category_hash->{$_}->{count}++;
        }
    }
    my @categories = sort { $a->{name} cmp $b->{name} } values %$category_hash;
    my @months = sort { $a->{name} cmp $b->{name} } values %$month_hash;
    my $cur_month = (localtime)[4] + 1;
    my $cur_year = (localtime)[5] + 1900;
    my @this_calender = calendar();
    my $conv = sub {
        my ($y, $m, $d) = @_;
        return unless $d;
        my $ymd = sprintf '%04d%02d%02d', $y, $m, $d;
        my $url = sprintf '/%04d/%02d/%02d/', $y, $m, $d;
        +{
            day => $d,
            has_entry => $day_hash->{$ymd},
            url => $url
        };
    };
    for my $week (@this_calender) {
        @$week = map { $conv->($cur_year, $cur_month, $_) } @$week;
    }
    my ($last_year, $last_month) = ($cur_year, $cur_month);
    $last_month--;
    $last_year-- if $last_month == 0;
    $last_month = 12 if $last_month == 0;
    my @last_calender = calendar($last_month, $last_year);
    for my $week (@last_calender) {
        @$week = map { $conv->($last_year, $last_month, $_) } @$week;
    }
    my $sidebar = $self->tx->render('sidebar.tx', {
        app           => $self,
        entries       => \@$entries,
        recents       => $recents,
        categories    => \@categories,
        months        => \@months,
        this_calendar => \@this_calender,
        last_calendar => \@last_calender
    });
    $self->store($self->sidebar_file, encode_utf8($sidebar));
}

sub rebuild_rss {
    my ($self, $recents) = @_;
    
    my $last_entry = $recents->[0];
    my $rss = XML::RSS::LibXML->new(
      version       => '1.0',
      encode_output => 0,
    );
    $rss->add_module(
      prefix => 'content',
      uri => 'http://purl.org/rss/1.0/modules/content/',
    );
    $rss->channel(
      title => $self->title,
      link  => $self->rss_url,
      dc => {
        date => $last_entry->{iso}
      }
    );
    for my $entry (@$recents) {
        my $title = $entry->{title};
        decode_entities($title);
        my $text = $self->load($entry->{file});
        my $description = decode_utf8(Text::Markdown->new->markdown($text));
        $description = decode_entities($description);
        $rss->add_item(
          link        => $entry->{abs_url},
          title       => encode_utf8($title),
          description => encode_utf8($description),
          dc => {
            date => $entry->{iso},
          },
          content => {
            encoded => encode_utf8($description)
          }
        );
    }
    $self->store($self->rss_file, $rss->as_string);
}

sub store_entries {
    my ($self, $entries) = @_;
    my $packed = Data::MessagePack->pack($entries);
    $self->store($self->cache_file, $packed);
}

sub load_entries {
    my ($self) = @_;
    my $data = $self->load($self->cache_file);
    Data::MessagePack->unpack($data);
}

sub load_sidebar {
    decode_utf8(shift->sidebar_file->slurp)
}

sub load {
    my ($self, $file) = @_;
    my $fh;
    open $fh, $file;
    my $data = join '', <$fh>;
    close $fh;
    return $data;
}

sub store {
    my ($self, $file, $data) = @_;
    my $tmp_file = $file . '.tmp';
    my $fh;
    open $fh, '>', $tmp_file;
    print $fh $data;
    close $fh;
    rename $tmp_file, $file;
}

sub cache_file {
    file(shift->tmpdir, 'cache')
}

sub sidebar_file {
    file(shift->tmpdir, 'sidebar')
}

sub rss_file {
    file(shift->tmpdir, 'rss')
}

=head1 NAME

App::MarkdownDiary

=head1 SYNOPSIS

    use strict;
    use App::MarkdownDiary;

    App::MarkdownDiary->new(
        suffix => '.md',
        root => './blog',
    );

=head1 INSTALL

    cpanm Calendar::Simple Data::MessagePack HTML::Entities Text::Xslate XML::RSS::LibXML

=cut

1;
