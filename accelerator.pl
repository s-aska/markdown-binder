#!/usr/bin/env perl

# http://pad.demo.7kai.org/note/howto/5.HighPerformance
# 
# eg.
#     perl accelerator.pl -r ./doc -c /home/aska/.cache
# 

use strict;
use Cwd 'abs_path';
use Encode;
use File::Basename;
use File::Spec::Functions qw(abs2rel catdir catfile);
use Filesys::Notify::Simple;
use Path::Class;
use Text::Markdown;
use Getopt::Std;

my %opts;
getopts('Dt:s:r:c:', \%opts);

my $base_dir   = dirname(__FILE__);
my $doc_dir    = dir(abs_path($opts{r}));
my $cache_dir  = dir(abs_path($opts{c}));
my $pid        = file($cache_dir, 'accelerator.pid');
my $suffix     = $opts{s} || '.md';
my $top        = $opts{t} || 'TOP';

if ($opts{D}) {
    my ($mode) = shift;
    if ($mode eq 'start') {
        print "start accelerator standalone.\n";
        require Proc::Daemon;
        Proc::Daemon::Init();
        my $fh = $pid->openw;
        print $fh $$;
        close $fh;
    } elsif ($mode eq 'stop') {
        my $pid_ = $pid->slurp;
        print "stop accelerator.\n";
        kill, 15, $pid_;
        $pid->remove;
        exit(0);
    } else {
        die 'unknown option ' . $mode;
    }
}

my @files;
my $create_cache = sub {
    my $source = shift;
    my $rel_path = decode('utf8', abs2rel($source, $doc_dir));
    $rel_path = '' if $rel_path eq ($top . $suffix);
    my $cache = file($cache_dir, substr($rel_path, 0, -1 * (length $suffix)) . '.html');
    my $cache_tmp = file($cache . '.tmp');
    return if -f $cache and $cache->stat->mtime >= $source->stat->mtime;
    $cache->dir->mkpath unless -d $cache->dir;
    my $text = $source->slurp;
    my $html = Text::Markdown->new->markdown($text);
    $html=~s|>\n{2,}<|>\n<|g;
    $html=~s|\n$||;
    my $create = not -f $cache;
    my $fh = $cache_tmp->openw;
    $fh->print($html);
    $fh->close;
    rename($cache_tmp, $cache);
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
            return if -f $path and $path!~m|\Q$suffix\E$|;
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
            return if $rel_path !~m|\Q$suffix\E$|;
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
