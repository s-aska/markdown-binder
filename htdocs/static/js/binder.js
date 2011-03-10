function MarkdownBinder() {
}

MarkdownBinder.prototype = {

    expanded: true,
    gone: false,
    path: false,
    basename: false,
    dir: false,
    dirs: [],

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
        if (this.editing) {
            this.closeEditor();
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
                if (callback) {
                    callback();
                }
            },
            error: function(XMLHttpRequest, status, errorThrown){
                $('#page').html(status + ': ' + errorThrown);
                $('#pagelink').hide();
            }
        });
    },

    expand: function(){
        var binder = this;
        if (binder.expanded) {
            $('#sidebar dl dl').each(function(){
                $(this).hide();
            });
            binder.expanded = false;
        } else {
            $('#sidebar dl dl').each(function(){
                $(this).show();
            });
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

        // init 
        binder.path = location.pathname;
        binder.initSidebar();
        binder.initPagelink();
        binder.initDocument();
        binder.initHeight();
    },

    initHeight: function(){
        $('#page').removeAttr('style');
        $('#sidebar').removeAttr('style');
        var sidebar_height = $('#sidebar').height();
        var document_height = $('#page').height();
        if (sidebar_height > document_height) {
            $('#page').height(sidebar_height);
        } else {
            $('#sidebar').height(document_height);
        }
    },

    initPagelink: function() {
        var binder = this;
        $('#pagelink').show();
        var permalink = $('#permalink');
        permalink.attr('href', binder.path);
        var source = $('#source');
        source.attr('href', binder.source());
    },

    initDocument: function(html){
        var binder = this;
        if (html) {
            $('#page').html(html);
            binder.initHeight();
        }
        $('#page').find('a').each(function(){
            if ($(this).attr('href').match(/^https?:/)) {
                $(this).attr('target', '_blank');
            } else {
                $(this).bind('click', function(){ binder.go($(this).attr('href')); return false;});
            }
        });
    },

    initSidebar: function(html){
        var binder = this;
        if (html) {
            $('#pages').html(html);
            binder.initHeight();
        }
        $('#pages').find('a').each(function(){
            var a = $(this);
            a.bind('click', function(){
                binder.go(a.data('file'));
                return false;
            });
        });
        $('#pages dt span').hover(function(){
            $(this).css('cursor','pointer');
        },function(){
            $(this).css('cursor','default');
        });
        
        $('#pages dt span').click(function(){
            var dt = $(this).parent();
            var ele = dt.next();
            if (ele.length > 0 && ele.get(0).tagName.toLowerCase() == 'dl') {
                var display = ele.css('display');
                if (display == "" || display == "none") {
                    ele.slideDown('fast');
                } else {
                    ele.slideUp('fast');
                }
            }
            return false;
        });
        /*
        $('#sidebar dl dl').each(function(){
            $(this).hide();
        });
        $('#sidebar dd').each(function(){
            var dd = $(this);
            var file = dd.data('file');
            if (file && location.pathname == file) {
                dd.parents('dl').each(function(){
                    $(this).show();
                });
            }
        });
        */
    }
}
