function MarkdownBinder() {
}

MarkdownBinder.prototype = {

    expanded: false,
    gone: false,
    path: false,
    basename: false,
    dir: false,
    dirs: [],
    title: '',

    // util
    source: function() {
        if (this.path == '/') {
            return '/TOP.txt';
        } else {
            return this.path + '.txt';
        }
    },

    catfile: function(dir, file){
        if (dir == '/') {
            return dir + file;
        } else {
            return dir + '/' + file;
        }
    },

    // navigation
    go: function(path, callback){
        if (history.pushState) {
            history.pushState(path, '', location.protocol + '//' + location.host + path);
        }
        this.load(path, callback);
    },

    load: function(path, callback){
        var binder = this;
        var url = path;
        if (url == '/') {
            url = url + 'TOP';
        }
        if (jQuery.browser.msie) {
            url = encodeURI(url);
        }
        var match = path.match(/^(.*)\/([^\/]*)$/);
        $.ajax({
            url: url + '.html',
            cache: false,
            success: function(html){
                binder.gone = true;
                binder.initDocument(html);
                binder.path = path;
                binder.dir = match[1];
                binder.basename = match[2];
                binder.initPagelink();
                binder.initHighlight();
                $('title').text(binder.title + path.replace('/', ' - '));
                if (callback) {
                    callback();
                }
            },
            error: function(XMLHttpRequest, status, errorThrown){
                $('article section').html(status + ': ' + errorThrown);
                $('article nav').hide();
            }
        });
    },

    expand: function(){
        var binder = this;
        if (binder.expanded) {
            $('aside nav ul ul').hide();
            $('aside nav li.dir').addClass('close');
            $('#expand').addClass('close');
            binder.expanded = false;
        } else {
            $('aside nav ul ul').show();
            $('aside nav li.dir').removeClass('close');
            $('#expand').removeClass('close');
            binder.expanded = true;
            binder.initHeight();
        }
    },

    // initXXX
    initApplication: function(){
        var binder = this;

        // history control
        if (history.pushState) {
            history.pushState('/', '', location.protocol + '//' + location.host + location.pathname);
            // browser go back event
            window.addEventListener('popstate', function (event) {
                if (binder.gone) {
                    binder.load(event.state);
                }
            });
        }

        // bind
        $('#expand').bind('click', function(){binder.expand();return false;});
        $('#expand').hover(function(){
            $(this).css('cursor','pointer');
            $(this).addClass('highlight');
        },function(){
            $(this).css('cursor','default');
            $(this).removeClass('highlight');
        });

        // init 
        binder.path = location.pathname;
        binder.initSidebar();
        binder.initPagelink();
        binder.initDocument();
        binder.initHeight();
        binder.title = $('header h1').text();
    },

    initHeight: function(){
        $('article').removeAttr('style');
        $('aside').removeAttr('style');
        var sidebar_height = $('aside').height();
        var document_height = $('article').height();
        if (sidebar_height > document_height) {
            $('article').height(sidebar_height);
        } else {
            $('aside').height(document_height);
        }
    },

    initPagelink: function() {
        var binder = this;
        $('article nav').show();
        $('#permalink').attr('href', binder.path);
        $('#source').attr('href', binder.source());
    },

    initDocument: function(html){
        var binder = this;
        if (html) {
            $('article section').html(html);
            binder.initHeight();
        }
        $('article section').find('a').each(function(){
            if ($(this).attr('href').match(/^https?:/)) {
                $(this).attr('target', '_blank');
            } else {
                $(this).bind('click', function(){ binder.go($(this).attr('href')); return false;});
            }
        });
    },

    initSidebar: function(){
        var binder = this;
        $('aside').find('a').each(function(){
            var a = $(this);
            a.bind('click', function(){
                binder.go(a.attr('href'));
                return false;
            });
        });
        $('aside li.dir').hover(function(){
            $(this).css('cursor','pointer');
            $(this).addClass('highlight');
        },function(){
            $(this).css('cursor','default');
            $(this).removeClass('highlight');
        });
        
        $('aside li.dir').click(function(){
            var dir = $(this);
            var ul = dir.children();
            if (ul.length > 0 && ul.get(0).tagName.toLowerCase() == 'ul') {
                var display = ul.css('display');
                if (display == "" || display == "none") {
                    ul.slideDown('fast', function(){dir.removeClass('close');binder.initHeight();});
                } else {
                    ul.slideUp('fast', function(){dir.addClass('close')});
                }
            }
            return false;
        });
        $('aside ul ul').hide();
        binder.initHighlight();
    },
    
    initHighlight: function(){
        var binder = this;
        $('aside nav li a').each(function(){
            var li = $(this).parent();
            var a = $(this);
            var file = a.attr('href');
            if (file && (binder.path == file || binder.path == encodeURI(file))) {
                a.addClass('highlight');
                li.parents('ul').show();
            } else {
                a.removeClass('highlight');
            }
        });
        $('aside nav li.dir').each(function(){
            var dir = $(this);
            var file = dir.data('file');
            var fileEncode = encodeURI(file);
            var re = new RegExp('^' + file);
            var reEncode = new RegExp('^' + fileEncode);
            if (file && (binder.path.match(re) || binder.path.match(reEncode))) {
                dir.removeClass('close');
            }
        });
        binder.initHeight();
    }
}
