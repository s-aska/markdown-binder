
use strict;
use Cwd 'abs_path';
use Encode;
use File::Basename;
use File::Spec::Functions qw(abs2rel catdir catfile);
use Filesys::Notify::Simple;
use Path::Class;
use Text::Markdown;
use Text::Xslate;

my $base_dir   = dirname(__FILE__);
my $doc_dir    = dir(abs_path($ENV{'MARKDOWN_BINDER_DOC'} || catdir($base_dir, 'doc')));
my $cache_dir  = dir(abs_path($ENV{'MARKDOWN_BINDER_CACHE'} || catdir($base_dir, 'cache')));
my $watch_pid  = file(abs_path(catfile($base_dir, 'watch.pid')));
my $tx_dir     = abs_path(catdir($base_dir, 'view'));
my $top        = 'TOP';
my $suffix     = '.md';
my $toppage    = $top . $suffix;
my $suffix_ptn = quotemeta $suffix;

if ($ENV{'MARKDOWN_BINDER_REQUIRE'}) {
    print "start watcher with plack.\n";
} else {
    my ($mode) = shift;
    if ($mode eq 'start') {
        print "start watcher standalone.\n";
        require Proc::Daemon;
        Proc::Daemon::Init();
        my $fh = $watch_pid->openw;
        print $fh $$;
        close $fh;
    } elsif ($mode eq 'stop') {
        my $pid = $watch_pid->slurp;
        print "stop watcher.\n";
        system('kill', $pid);
        $watch_pid->remove;
        exit(0);
    } else {
        die 'unknown option ' . $mode;
    }
}

my $tx = Text::Xslate->new(
    path   => [$tx_dir, $cache_dir],
    module => ['Text::Xslate::Bridge::TT2Like'],
    syntax => 'TTerse'
);

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
