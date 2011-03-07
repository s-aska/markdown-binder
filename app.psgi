
use strict;
use Digest::MD5;
use Encode;
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use JSON;
use Path::Class;
use Plack::Builder;
use Plack::Request;
use Text::Markdown;
use Text::Xslate;
use Time::HiRes;
use URI::Escape;

my $base_dir     = dirname(__FILE__);
my $doc_dir      = dir($ENV{'MARKDOWN_BINDER_DOC'} || catdir($base_dir, 'doc'))->absolute;
my $cache_dir    = dir($ENV{'MARKDOWN_BINDER_CACHE'} || catdir($base_dir, 'cache'))->absolute;
my $pass_file    = file($ENV{'MARKDOWN_BINDER_PW'} || catfile($base_dir, '.password'));
my $conf_file    = file($ENV{'MARKDOWN_BINDER_PW'} || catfile($base_dir, 'config.json'));
my $top          = $ENV{'MARKDOWN_BINDER_TOP'} || 'TOP';
my $suffix       = '.txt';
my $toppage      = $top . $suffix;
my $upload_dir   = 'htdocs/static/img/upload';

my $default_conf = {
    title => 'no title',
    footer => 'copyright'
};

my $conf = -f $conf_file ? decode_json($conf_file->slurp) : $default_conf;

my @phones = qw/
    iPhone
    iPad
    Android
/;

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
my $rebuild = sub {
    my $cache_clean = shift;
    @files = ();
    if ($cache_clean) {
        $cache_dir->rmtree if -d $cache_dir;
        $cache_dir->mkpath;
    }
    $doc_dir->recurse(
        preorder => 1,
        depthfirst => 1,
        callback => sub {
            my $file = shift;
            my $path = decode('utf8', $file);
            $path=~s|^$doc_dir||;
            return if substr(file($path)->basename, 0, 1) eq '.';
            return unless length $path;
            if (-f $file && $file=~/$suffix$/) {
                $path = file($path);
                my $text = $file->slurp;
                my $html = Text::Markdown->new->markdown($text);
                my $cache_file = file($cache_dir, substr($path, 0, -4) . '.html');
                if (!-f $cache_file) {
                    $cache_file->dir->mkpath unless -d $cache_file->dir;
                    my $fh = $cache_file->openw;
                    $fh->print($html);
                    $fh->close;
                    warn 'create cached ', $path;
                } else {
                    warn 'find cached ', $path;
                }
            } elsif (-d $file) {
                $path = dir($path);
                warn 'find dir ', $path;
            }
            push @files, $path;
        }
    );
};
$rebuild->();

my $password = $pass_file->slurp if -f $pass_file;
my $bad_ip = {};
my $sessions = {};
my $gen_id = sub {
    my $sid_length = 64;
    my $unique = ( [] . rand() );
    my $id = substr( Digest::MD5::md5_hex( Time::HiRes::gettimeofday() . $unique ), 0, $sid_length );
    $sessions->{ $id }++;
    return $id;
};
my $valid_password = sub {
    my $req = shift;
    my $sid = $req->param('sid') || $req->cookies->{sid};
    if (!-f $pass_file) {
        warn 'unset password.';
        return $gen_id->();
    } elsif ($bad_ip->{ $req->address } > 5) {
        warn 'attack ip ' . $req->address;
        return ;
    } elsif (exists $sessions->{ $sid }) {
        warn 'logined';
    } elsif ($password ne crypt($req->param('password'), $password)) {
        warn 'invalid password';
        $bad_ip->{ $req->address }++;
        return ;
    } else {
        warn 'login';
        delete $bad_ip->{ $req->address };
        return $gen_id->();
    }
    return 1;
};

my $res_200 = [ 200, [ 'Content-Type' => 'text/html' ], [ '' ] ];
my $res_403 = [ 403, [ 'Content-Type' => 'text/html' ], [ '403 Forbidden.' ] ];
my $res_404 = [ 404, [ 'Content-Type' => 'text/html' ], [ '404 Not Found.' ] ];
my $res_409 = [ 409, [ 'Content-Type' => 'text/html' ], [ '409 Conflict Exists File or Dir.' ] ];

my $check_path = sub {
    return 1 if grep($_ eq '..', split('/', shift));
    return ;
};

my $render = sub {
    my ($req, $path, $params) = @_;
    my $tx = Text::Xslate->new(
        path   => './',
        module => ['Text::Xslate::Bridge::TT2Like'],
        syntax => 'TTerse'
    );
    my $content = $tx->render($path, $params);
    my $res = $req->new_response(200);
    $res->content_type('text/html; charset=UTF-8');
    $res->body(encode('utf8', $content));
    return $res->finalize;
};

my $render_sidebar = sub {
    $render->(shift, 'sidebar.tx', { files => \@files });
};

my $app = sub {
    my $req = Plack::Request->new(shift);
    
    # check path
    return $res_403 if $check_path->($req->path);

    my $file = $req->path;
       $file.= $top if $file eq '/';
    
    my $cache_file = file($cache_dir, $file . '.html');
    my $text_file = file($doc_dir, $file . '.txt');
    
    if ($req->method eq 'POST') {
        
        my $login = $valid_password->($req);
        if (!$login) {
            return $res_403;
        }
        
        # upload file
        elsif (my $upload_file = $req->upload('file')) {
            my $basename = $upload_file->basename;
            my $dest = file($upload_dir, $basename);
            File::Copy::move($upload_file->path, $dest);
            chmod 0644, $dest;
            return [ 200, [ 'Content-Type' => 'text/plain' ], [ uri_escape($basename) ] ];
        }
        
        # change password
        elsif (my $new_password = $req->param('new_password')) {
            my $fh = $pass_file->openw;
            my @salts = ( "A".."Z", "a".."z", "0".."9", ".", "/" );
            my $salt = $salts[int(rand(64))] . $salts[int(rand(64))];
            $password = crypt($new_password, $salt);
            $fh->print($password);
            $fh->close;
            chmod 0600, $pass_file;
            return [ 200, [ 'Content-Type' => 'text/html' ], [ $login ] ];
        }
        
        # login
        elsif ($req->param('login_check')) {
            return [ 200, [ 'Content-Type' => 'text/html' ], [ $login ] ];
        }
        
        # rebuild
        elsif ($req->param('rebuild')) {
            $rebuild->(1);
            return $render_sidebar->($req);
        }
        
        # new page
        elsif ($req->param('create')) {
            if (-f $text_file) {
                return $res_403;
            }
            $text_file->dir->mkpath unless -d $text_file->dir;
            unless (length file($file)->basename) {
                warn $file;
                warn file($file)->basename;
                $rebuild->();
                return $render_sidebar->($req);
            }
            my $text = '# ' . file($file)->basename;
            my $fh = $text_file->openw;
            $fh->print($text);
            $fh->close;
            $cache_file->dir->mkpath unless -d $cache_file->dir;
            my $cache = $cache_file->openw;
            my $html = Text::Markdown->new->markdown($text);
            $cache->print($html);
            $cache->close;
            $rebuild->();
            return $render_sidebar->($req);
        }
        
        # copy page
        elsif (my $dest = $req->param('copy')) {
            return $res_403 if $check_path->($dest);
            my $dest_file = file($doc_dir, $dest . '.txt');
            return $res_409 if -f $dest_file;
            $dest_file->dir->mkpath unless -d $dest_file->dir;
            my $dest_fh = $dest_file->openw;
            $dest_fh->print($text_file->slurp);
            $dest_fh->close;
            $rebuild->();
            return $render_sidebar->($req);
        }
        
        # rename page
        elsif (my $dest = $req->param('rename')) {
            return $res_403 if $check_path->($dest);
            my $dest_file = file($doc_dir, file($file)->dir, $dest . '.txt');
            return $res_409 if -f $dest_file;
            $dest_file->dir->mkpath unless -d $dest_file->dir;
            rename($text_file, $dest_file);
            $cache_file->remove;
            $rebuild->();
            return $render_sidebar->($req);
        }
        
        # move page
        elsif (my $dest = $req->param('move')) {
            return $res_403 if $check_path->($dest);
            my $dest_file = file($doc_dir, $dest, file($file)->basename . '.txt');
            return $res_409 if -f $dest_file;
            $dest_file->dir->mkpath unless -d $dest_file->dir;
            rename($text_file, $dest_file);
            $cache_file->remove;
            $rebuild->();
            return $render_sidebar->($req);
        }
        
        # delete page
        elsif ($req->param('delete')) {
            if (-f $text_file) {
                $text_file->remove;
                $cache_file->remove;
                return $res_200;
            } else {
                return $res_404;
            }
        }
        
        # move dir
        elsif (my $dest = $req->param('move_dir')) {
            return $res_403 if $check_path->($dest);
            $dest = dir($dest, file($file)->basename);
            my $src_dir = dir($doc_dir, $file);
            my $dest_dir = dir($doc_dir, $dest);
            my $cache_dest_dir = dir($cache_dir, $dest);
            return $res_409 if $dest_dir=~/^$src_dir/;
            return $res_409 if -d $dest_dir;
            $dest_dir->parent->mkpath unless -d $dest_dir->parent;
            if (-d $src_dir) {
                rename($src_dir, $dest_dir);
                rename($cache_file, $cache_dest_dir);
                $rebuild->();
                return $render_sidebar->($req);
            } else {
                return $res_404;
            }
        }
        
        # rename dir
        elsif (my $dest = $req->param('rename_dir')) {
            return $res_403 if $check_path->($dest);
            $dest = dir(file($file)->dir, $dest);
            my $src_dir = dir($doc_dir, $file);
            my $dest_dir = dir($doc_dir, $dest);
            my $cache_dest_dir = dir($cache_dir, $dest);
            return $res_409 if -d $dest_dir;
            $dest_dir->parent->mkpath unless -d $dest_dir->parent;
            if (-d $src_dir) {
                rename($src_dir, $dest_dir);
                rename($cache_file, $cache_dest_dir);
                $rebuild->();
                return $render_sidebar->($req);
            } else {
                return $res_404;
            }
        }
        
        # delete dir
        elsif ($req->param('delete_dir')) {
            my $dir = dir($doc_dir, $file);
            my $cache_dir = dir($cache_dir, $file);
            if (-d $dir) {
                $dir->rmtree;
                $cache_dir->rmtree;
                $rebuild->();
                return $render_sidebar->($req);
            } else {
                return $res_404;
            }
        }
        
        # save or preview
        else {
            my $html = Text::Markdown->new->markdown($req->param('content'));
            if ($req->param('save')) {
                my $fh = $text_file->openw;
                $fh->print($req->param('content'));
                $fh->close;
                my $cache_fh = $cache_file->openw;
                $cache_fh->print($html);
                $cache_fh->close;
            }
            return [ 200, [ 'Content-Type' => 'text/html' ], [ $html ] ];
        }
    }
    
    if ($req->param('sidebar')) {
        return $render_sidebar->($req);
    }
    
    if (!-f $cache_file) {
        return $res_404;
    }
    
    my $is_pc = scalar(grep { $req->user_agent=~/$_/ } @phones) ? 0 : 1;
    warn $is_pc;
    my $html = $cache_file->slurp;
    
    return
        $render->($req, 'index.html', {
            conf    => $conf,
            is_pc   => $is_pc,
            logined => exists($sessions->{ $req->cookies->{sid} }),
            files   => \@files,
            content => $html,
            path    => $req->path,
            login   => $req->param('login') || 0,
            install => not length $password
        });
};

builder {
    enable 'Static',
        path => qr!^/static|^(/favicon.ico|/robots.txt)$!, root => './htdocs/';
    enable 'Static',
        path => qr!\.html$!, root => $cache_dir;
    enable 'Static',
        path => qr!\.txt$!, root => $doc_dir;
#    enable 'XForwardedFor',
#        trust => [qw(127.0.0.1/8)];
    $app;
};
