(function(ns, w, d) {

var w = $(w);

ns.MarkdownBinder = initialize;
ns.MarkdownBinder.prototype = {
    expanded: true,
    gone: false,
    path: false,
    basename: false,
    dir: false,
    dirs: [],
    title: '',
    catfile: catfile,
    go: go,
    load: load,
    expand: expand,
    initApplication: initApplication,
    initHeight: initHeight,
    initPagelink: initPagelink,
    initDocument: initDocument,
    initSidebar: initSidebar,
    initHighlight: initHighlight
};

// ブラウザバックで $(d).ready 呼ばれないので w.bind("popstate" とかは initialize でやる
var binder = new MarkdownBinder();

$(d).ready(function() {
    binder.initApplication();
});

function initialize(options){
    var binder = this;

    // history control
    if (history.pushState) {
    // history.pushState('/', '', location.protocol + '//' + location.host + location.pathname);
    // browser go back event
    w.bind("popstate", function (event) {
        console.log(event.originalEvent.state);
        if (event.originalEvent.state) {
            binder.load(event.originalEvent.state);
        }
    });
}
}

function catfile(dir, file){
    if (dir == '/') {
        return dir + file;
    } else {
        return dir + '/' + file;
    }
}

function go(path, callback){
    if (history.pushState) {
        history.pushState(path, '', location.protocol + '//' + location.host + path);
    }
    this.load(path, callback);
}

function load(path, callback){
    var binder = this;
    var url = path;
    if ($.browser.msie) {
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
            if (path == '/') {
                $('title').text(binder.title);
            } else {
                $('title').text(binder.title + url.replace('/', ' - '));
            }
            if (callback) {
                callback();
            }
        },
        error: function(XMLHttpRequest, status, errorThrown){
            $('article section').html(status + ': ' + errorThrown);
            $('article nav').hide();
        }
    });
}

function expand(){
    if (this.expanded) {
        $('aside nav ul ul').hide();
        $('aside nav li.dir').addClass('close');
        $('#expand').addClass('close');
        this.expanded = false;
        this.initHeight();
        this.initHighlight();
    } else {
        $('aside nav ul ul').show();
        $('aside nav li.dir').removeClass('close');
        $('#expand').removeClass('close');
        this.expanded = true;
        this.initHeight();
        this.initHighlight();
    }
}

function initApplication(){
    var binder = this;

    // bind
    $('#expand').bind('click', function(){binder.expand()});
    $('#expand').hover(function(){
        $(this).css('cursor','pointer');
        $(this).addClass('highlight');
    },function(){
        $(this).css('cursor','default');
        $(this).removeClass('highlight');
    });
    $('#expand').show();
    $('#close').bind('click', function(){
        $('header').hide();
        $('#wrapper').css('padding-top', '0');
        binder.initHeight();
    });
    $('#close').hover(function(){
        $(this).css('cursor','pointer');
        $(this).addClass('highlight');
    },function(){
        $(this).css('cursor','default');
        $(this).removeClass('highlight');
    });
    $('#close').show();
    w.bind('resize', initHeight);

    // init
    this.path = location.pathname;
    this.initHeight();
    this.initSidebar();
    this.initPagelink();
    this.initDocument();
    this.title = $('header h1').text();
}

function initHeight(){
    var a_height = w.height()
        - $('aside').offset().top
        - parseInt($('aside').css('paddingTop'), 10)
        - parseInt($('aside').css('paddingBottom'));
    $('aside').height(a_height);
}

function initPagelink(){
    $('article nav').show();
    $('#permalink').attr('href', this.path);
}

function initDocument(html){
    var binder = this;
    if (html) {
        $('article section').html(html);
    }
    $('article section').find('a').each(function(){
        if ($(this).attr('href').match(/^https?:/)) {
            $(this).attr('target', '_blank');
        } else {
            $(this).bind('click', function(){ binder.go($(this).attr('href')); return false;});
        }
    });
    w.scrollTop(0);
}

function initSidebar(){
    var binder = this;
    $('aside li.file a').each(function(){
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
                ul.slideDown('fast', function(){dir.removeClass('close');});
            } else {
                ul.slideUp('fast', function(){dir.addClass('close')});
            }
        }
        return false;
    });
    if ($('aside nav').height() > $('aside').height()) {
        $('aside ul ul').hide();
        $('aside ul li.dir').addClass('close');
        binder.expanded = false;
    }
    this.initHighlight();
}

function initHighlight(){
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
        var re = new RegExp('^' + file + '/');
        var reEncode = new RegExp('^' + fileEncode + '/');
        if (file && (binder.path.match(re) || binder.path.match(reEncode))) {
            dir.removeClass('close');
        }
    });
}

})(this, this, document);
