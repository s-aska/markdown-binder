function MarkdownBinder() {
}

MarkdownBinder.prototype = {

    sid: false,
    expanded: true,
    editing: false,
    gone: false,
    mode: false,
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
        binder.initLogin();
    },

    initLogin: function(){
        var binder = this;
        
        // application install
        if (binder.mode == 'install') {
            binder.dialog('please init password', 'password', '', function(value, finalize){
                $.ajax({
                    url: '/',
                    type: 'POST',
                    cache: false,
                    data: { password: '', new_password: value },
                    success: function(sid){
                        binder.initAdmin(sid);
                        finalize();
                    },
                    error: function(){
                        $('#dialogResutMessage').text('invalid password.');
                    }
                });
            });
        }

        // auto login or login dialog
        else if (binder.mode == 'login') {
            if ($.cookie('sid')) {
                binder.autoLogin(function(){binder.dispLoginDialog()});
            } else {
                binder.dispLoginDialog();
            }
        }

        // auto login or public
        else {
            if ($.cookie('sid')) {
                binder.autoLogin();
            }
        }
    },

    // auto login
    autoLogin: function(errorback){
        var binder = this;
        $.ajax({
            url: '/',
            type: 'POST',
            cache: false,
            data: { login_check: 1, sid: $.cookie('sid') },
            success: function(){
                binder.initAdmin($.cookie('sid'));
            },
            error: function(){
                if (errorback) {
                    errorback();
                }
            }
        });
    },

    // init admin page
    initAdmin: function(sid){
        var binder = this;

        // regist memory
        binder.sid = sid;

        // regist cookie
        $.cookie('sid', sid);

        // sidebar admin menu ( dir rename, dir delete )
        binder.initAdminSidebar();

        // show admin side menu
        // $('#adminsidemenu').show();
        // $('#new').bind('click', function(){return false;});
        // $('#sync').bind('click', function(){return false;});

        var sidemenu = $('#sidemenu');
        var siteMenu = $(document.createElement('div'));
        siteMenu.attr('id', 'sitemenu');
        siteMenu.attr('class', 'contextMenu');
        var newpage = $(document.createElement('a'));
        newpage.text('new...');
        newpage.attr('href', '#');
        newpage.bind('click', function(){
            siteMenu.hide();
            binder.dispNewpageDialog();
            return false;
        });        
        var syncpage = $(document.createElement('a'));
        syncpage.text('sync...');
        syncpage.attr('href', '#');
        syncpage.bind('click', function(){
            siteMenu.hide();
            binder.dispSyncDialog();
            return false;
        });
        siteMenu.append(newpage);
        siteMenu.append(syncpage);
        var siteMore = $(document.createElement('a'));
        siteMore.text('more ');
        var allow = $(document.createElement('span'));
        allow.attr('class', 'allow');
        allow.text('▼');
        siteMore.append(allow);
        siteMore.attr('class', 'more');
        siteMore.attr('href', '#');
        siteMore.attr('title', 'site menu');
        siteMore.click(function(){
            siteMenu.show();
            return false;
        });
        siteMenu.hide();
        $('body').append(siteMenu);
        $('body').click(function(){
            siteMenu.hide();
        });
        sidemenu.append(document.createTextNode(' | '));
        sidemenu.append(siteMore);
        siteMenu.css('top', siteMore.offset().top + siteMore.height() + 'px');
        siteMenu.css('left', siteMore.offset().left + 'px');

        // make admin page menu
        var page = $('#page');

        var pagelink = $('#pagelink');
        
        var pagemenu = $(document.createElement('div'));
        pagemenu.attr('id', 'pagemenu');
        pagemenu.attr('class', 'contextMenu');

        var editpage = $(document.createElement('a'));
        editpage.text('edit...');
        editpage.attr('href', '#');
        editpage.bind('click', function(){
            pagemenu.hide();
            if (binder.path != pagemenu.data('file')) {
                binder.go(pagemenu.data('file'), function(){binder.openEditor()});
            } else {
                binder.openEditor();
            }
            return false;
        });

        var copypage = $(document.createElement('a'));
        copypage.text('copy...');
        copypage.attr('href', '#');
        copypage.bind('click', function(){
            binder.dialog('copy page', 'text', pagemenu.data('basename'), function(dir, value, finalize){
                $.ajax({
                    url: pagemenu.data('file'),
                    type: 'POST',
                    cache: false,
                    data: { copy: binder.catfile(dir, value), sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        finalize();
                    },
                    error: function(){
                        $('#dialogResutMessage').text('error.');
                    }
                });
            }, true, pagemenu.data('dir'));
            return false;
        });

        var renamepage = $(document.createElement('a'));
        renamepage.text('rename...');
        renamepage.attr('href', '#');
        renamepage.bind('click', function(){
            binder.dialog('rename page', 'text', pagemenu.data('basename'), function(value, finalize){
                $.ajax({
                    url: pagemenu.data('file'),
                    type: 'POST',
                    cache: false,
                    data: { rename: value, sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        if (pagemenu.data('file') == binder.path) {
                            binder.go(binder.catfile(binder.dir, value));
                        }
                        finalize();
                    },
                    error: function(XMLHttpRequest, status, errorThrown){
                        $('#dialogResutMessage').text(status + ': ' + errorThrown);
                    }
                });
            });
            return false;
        });

        var movepage = $(document.createElement('a'));
        movepage.text('move...');
        movepage.attr('href', '#');
        movepage.bind('click', function(){
            binder.dialog('move page', 'hidden', pagemenu.data('file'), function(dir, value, finalize){
                $.ajax({
                    url: pagemenu.data('file'),
                    type: 'POST',
                    cache: false,
                    data: { move: dir, sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        if (pagemenu.data('file') == binder.path) {
                            binder.go(binder.catfile(dir, binder.basename));
                        }
                        finalize();
                    },
                    error: function(XMLHttpRequest, status, errorThrown){
                        $('#dialogResutMessage').text(status + ': ' + errorThrown);
                    }
                });
            }, true, pagemenu.data('dir'));
            return false;
        });
        
        var deletepage = $(document.createElement('a'));
        deletepage.text('delete...');
        deletepage.attr('href', '#');
        deletepage.bind('click', function(){
            binder.dialog('delete [ ' + pagemenu.data('file') + ' ] now ?', 'hidden', '', function(value, finalize){
                if (pagemenu.data('file') == binder.path) {
                    $('#page').html('deleted this page.');
                    $('#pagelink').hide();
                    binder.initHeight();
                }
                $.ajax({
                    url: pagemenu.data('file'),
                    type: 'POST',
                    cache: false,
                    data: { 'delete': 1, sid: binder.sid },
                    success: function(html){
                        $('dd').each(function(){
                            var dd = $(this);
                            var file = dd.data('file');
                            if (file && pagemenu.data('file') == file) {
                                dd.remove();
                            }
                        });
                        finalize();
                    },
                    error: function(){
                        $('#dialogResutMessage').text('error.');
                    }
                });
            });
            return false;
        });

        pagemenu.append(editpage);
        pagemenu.append(copypage);
        pagemenu.append(renamepage);
        pagemenu.append(movepage);
        pagemenu.append(deletepage);
        pagemenu.hide();
        $('body').append(pagemenu);
        $('body').click(function(){
            pagemenu.hide();
        });

        var more = $(document.createElement('a'));
        more.text('more ');
        var allow = $(document.createElement('span'));
        allow.attr('class', 'allow');
        allow.text('▼');
        more.append(allow);
        more.attr('title', 'page menu');
        more.attr('class', 'more');
        more.attr('href', '#');
        more.click(function(){
            pagemenu.data('file', binder.path);
            pagemenu.data('basename', binder.basename);
            pagemenu.data('dir', binder.dir);
            pagemenu.css('top', more.offset().top + more.height() + 'px');
            pagemenu.css('left', more.offset().left + 'px');
            pagemenu.show();
            return false;
        });

        pagelink.append(document.createTextNode(' | '));
        pagelink.append(more);
        
        var editor = $(document.createElement('textarea'));
        editor.attr('id', 'editor');
        editor.tabby({tabString: '    '});

        var preview = $(document.createElement('div'));
        preview.attr('id', 'preview');

        var loading = $(document.createElement('div'));
        loading.attr('id', 'loading');
        loading.text('loading...');

        var preview_button = $(document.createElement('input'));
        preview_button.attr('id', 'preview_button');
        preview_button.attr('type', 'button');
        preview_button.val('preview');
        preview_button.bind('click', function(){
            if (preview_button.val() == 'preview') {
                loading.text('processing...');
                loading.show();
                editor.hide();
                $.ajax({
                    url: '/',
                    type: 'POST',
                    data: { sid: binder.sid, content: editor.val() },
                    success: function(html){
                        loading.hide();
                        preview.html(html);
                        preview.show();
                        preview_button.val('edit');
                    },
                    error: function(){
                        loading.text('auth error.');
                    }
                });
            } else {
                editor.show();
                preview.hide();
                preview_button.val('preview');
            }
            return false;
        });

        var discard_button = $(document.createElement('input'));
        discard_button.attr('type', 'button');
        discard_button.val('discard');
        discard_button.bind('click', function(){
            editor.hide();
            editmenu.hide();
            preview.hide();
            page.show();
            return false;
        });

        var save_button = $(document.createElement('input'));
        save_button.attr('type', 'button');
        save_button.val('save');
        save_button.bind('click', function(){
            loading.text('saving...');
            loading.show();
            $.ajax({
                url: binder.path,
                type: 'POST',
                data: { save: 1, sid: binder.sid, content: $('#editor').val() },
                success: function(html){
                    page.show();
                    binder.initDocument(html);
                    loading.hide();
                    editor.hide();
                    editmenu.hide();
                    preview.hide();
                },
                error: function(){
                    loading.text('auth error.');
                }
            });
            return false;
        });

        var editmenu = $(document.createElement('div'));
        editmenu.attr('id', 'editmenu');
        editmenu.attr('style', 'margin-bottom: 10px;');
        editmenu.append(document.createTextNode(' '));
        editmenu.append(preview_button);
        editmenu.append(document.createTextNode(' '));
        editmenu.append(discard_button);
        editmenu.append(document.createTextNode(' '));
        editmenu.append(save_button);

        loading.hide();
        editor.hide();

        $('#content').append(editmenu);
        $('#content').append(loading);
        $('#content').append(editor);
        $('#content').append(preview);
        
        // dirMenu
        var dirMenu = $(document.createElement('div'));
        dirMenu.attr('id', 'dirMenu');
        dirMenu.attr('class', 'contextMenu');
        
        var rename = $(document.createElement('a'));
        rename.text('rename...');
        rename.attr('href', '#');
        rename.bind('click', function(e){
            var file = dirMenu.data('file');
            var basename = dirMenu.data('basename');
            binder.dialog('rename dir', 'text', basename, function(value, finalize){
                $.ajax({
                    url: file,
                    type: 'POST',
                    cache: false,
                    data: { rename_dir: value, sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        finalize();
                    },
                    error: function(XMLHttpRequest, status, errorThrown){
                        $('#dialogResutMessage').text(status + ': ' + errorThrown);
                    }
                });
            });
            return false;
        });
        
        var newpage = $(document.createElement('a'));
        newpage.text('new...');
        newpage.attr('href', '#');
        newpage.bind('click', function(e){
            binder.dispNewpageDialog(dirMenu.data('file'));
            return false;
        });
                
        var move = $(document.createElement('a'));
        move.text('move...');
        move.attr('href', '#');
        move.bind('click', function(e){
            var file = dirMenu.data('file');
            binder.dialog('move dir', 'hidden', file, function(dir, value, finalize){
                $.ajax({
                    url: file,
                    type: 'POST',
                    cache: false,
                    data: { move_dir: dir, sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        finalize();
                    },
                    error: function(XMLHttpRequest, status, errorThrown){
                        $('#dialogResutMessage').text(status + ': ' + errorThrown);
                    }
                });
            }, true, dirMenu.data('dir'));
            return false;
        });
        
        var del = $(document.createElement('a'));
        del.text('delete...');
        del.attr('href', '#');
        del.bind('click', function(){
            var file = dirMenu.data('file');
            binder.dialog('delete [ ' + file + ' ] now ?', 'hidden', file, function(value, finalize){
                $.ajax({
                    url: file,
                    type: 'POST',
                    cache: false,
                    data: { delete_dir: 1, sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        finalize();
                    },
                    error: function(XMLHttpRequest, status, errorThrown){
                        $('#dialogResutMessage').text(status + ': ' + errorThrown);
                    }
                });
            });
            return false;
        });
        
        dirMenu.append(newpage);
        dirMenu.append(move);
        dirMenu.append(rename);
        dirMenu.append(del);
        dirMenu.hover(function(){
            $(this).css('cursor','pointer');
        },function(){
            $(this).css('cursor','default');
        });
        dirMenu.hide();
        $('body').append(dirMenu);
        $('body').bind('click', function(){
            dirMenu.hide();
        });
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
        // var date = new Date();
        // var url = location.protocol + '//' + location.host + location.pathname;
        // var encodeUrl = encodeURIComponent(url);
        // var href = 'http://www.facebook.com/plugins/like.php?layout=button_count&show_faces=false&width=80&action=like&colorscheme=light&height=21&href=' + encodeUrl;
        // $('#likebutton').attr('src', href);
        // $('#tweetbutton').data('url', location.protocol + '//' + location.host + location.pathname);
        // $('#tweetcount').attr('src', 'http://platform.twitter.com/widgets.js?' + date.getTime());

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
            if (binder.sid) {
                binder.initAdminSidebar();
            }
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
    },

    initAdminSidebar: function(){
        var binder = this;
        
        binder.dirs = [];
        $('#pages dt span').each(function(){
            var dt = $(this).parent();
            binder.dirs.push(dt);
            
            var menu = $(document.createElement('a'));
            menu.text('▼');
            menu.attr('title', 'directory menu')
            menu.attr('href', '#');
            menu.attr('class', 'allow');
            menu.click(function(){
                var dirMenu = $('#dirMenu');
                dirMenu.data('file', dt.data('file'));
                dirMenu.data('basename', dt.data('basename'));
                dirMenu.data('dir', dt.data('dir'));
                dirMenu.show();
                dirMenu.css('top', menu.offset().top + menu.height() + 'px');
                dirMenu.css('left', menu.offset().left + 'px');
                return false;
            });
            
            dt.append($(document.createTextNode(' ')));
            dt.append(menu);
        });
        
        // 
        $('#pages dd').each(function(){
            var dd = $(this);
            var more = $(document.createElement('a'));
            more.text('▼');
            more.attr('title', 'page menu')
            more.attr('href', '#');
            more.attr('class', 'allow');
            more.click(function(){
                var pageMenu = $('#pagemenu');
                pageMenu.data('file', dd.data('file'));
                pageMenu.data('basename', dd.data('basename'));
                pageMenu.data('dir', dd.data('dir'));
                pageMenu.css('top', more.offset().top + more.height() + 'px');
                pageMenu.css('left', more.offset().left + 'px');
                pageMenu.show();
                return false;
            });
            dd.append($(document.createTextNode(' ')));
            dd.append(more);
        });
        
        // $('#pages').find('dt').each(function(){
        //     var dt = $(this);
        //     var file = dt.data('file');
        //     var rename = $(document.createElement('input'));
        //     rename.val('rename');
        //     rename.attr('type', 'button');
        //     rename.bind('click', function(){
        //         binder.dialog('rename dir', 'text', file, function(value, finalize){
        //             $.ajax({
        //                 url: file,
        //                 type: 'POST',
        //                 cache: false,
        //                 data: { rename_dir: value, sid: binder.sid },
        //                 success: function(html){
        //                     binder.initSidebar(html);
        //                     finalize();
        //                 },
        //                 error: function(XMLHttpRequest, status, errorThrown){
        //                     $('#dialogResutMessage').text(status + ': ' + errorThrown);
        //                 }
        //             });
        //         });
        //         return false;
        //     });
        //     var del = $(document.createElement('input'));
        //     del.val('delete');
        //     del.attr('type', 'button');
        //     del.bind('click', function(){
        //         binder.dialog('delete dir now ?', 'hidden', file, function(value, finalize){
        //             $.ajax({
        //                 url: file,
        //                 type: 'POST',
        //                 cache: false,
        //                 data: { delete_dir: 1, sid: binder.sid },
        //                 success: function(html){
        //                     binder.initSidebar(html);
        //                     finalize();
        //                 },
        //                 error: function(XMLHttpRequest, status, errorThrown){
        //                     $('#dialogResutMessage').text(status + ': ' + errorThrown);
        //                 }
        //             });
        //         });
        //         return false;
        //     });
        //     var menu = $(document.createElement('span'));
        //     menu.css('position', 'absolute');
        //     menu.css('top', '4px');
        //     menu.css('zIndex', '99990');
        //     menu.append(rename);
        //     menu.append(document.createElement('br'));
        //     menu.append(del);
        //     menu.hide();
        //     var edit = $(document.createElement('input'));
        //     edit.val('▼');
        //     edit.attr('type', 'button');
        //     edit.bind('click', function(){
        //         var display = menu.css('display');
        //         if (display == '' || display == 'none') {
        //             menu.css('display', 'inline')
        //         } else {
        //             menu.hide();
        //         }
        //     });
        //     dt.css('position', 'relative');
        //     dt.append(edit);
        //     dt.append(menu);
        // });
    },

    openEditor: function(){
        var binder = this;
        var page = $('#page');
        var editor = $('#editor');
        var loading = $('#loading');
        var width = page.width();
        var height = page.height();
        if (height < 400) { height = 400 };
        page.hide();
        $('#editmenu').show();
        loading.show();
        loading.text('loading...');
        $.ajax({
            url: binder.source(),
            cache: false,
            success: function(html){
                loading.hide();
                editor.text(html);
                editor.width(width);
                editor.height(height);
                editor.show();
                $('#preview_button').val('preview');
                binder.editing = true;
            }
        });
    },

    closeEditor: function(){
        var binder = this;
        if (binder.editing) {
            $('#page').show();
            $('#editmenu').hide();
            $('#editor').hide();
            $('#loading').hide();
            $('#preview').hide();
            binder.editing = false;
        }
    },

    // admin function
    dispLoginDialog: function(){
        var binder = this;
        binder.dialog('please input password', 'password', '', function(value, finalize){
            $.ajax({
                url: '/',
                type: 'POST',
                cache: false,
                data: { login_check: 1, password: value },
                success: function(sid){
                    binder.initAdmin(sid);
                    finalize();
                },
                error: function(){
                    $('#dialogResutMessage').text('invalid password.');
                }
            });
        });
    },

    dispNewpageDialog: function(dir){
        var binder = this;
        var url;
        if (dir) {
            url = dir;
        } else {
            url = binder.path.replace(/\/[^\/]*$/, '');
        }
        binder.dialog('new page ( hoge ) or new dir ( foo/ )', 'text', '', function(dir, value, finalize){
            $.ajax({
                url: binder.catfile(dir, value),
                type: 'POST',
                cache: false,
                data: { create: 1, sid: binder.sid },
                success: function(html){
                    binder.initSidebar(html);
                    finalize();
                },
                error: function(XMLHttpRequest, status, errorThrown){
                    $('#dialogResutMessage').text(status + ': ' + errorThrown);
                }
            });
        }, true, url);
    },

    dispSyncDialog: function(){
        var binder = this;
        binder.dialog('sync now ?', 'hidden', '', function(value, finalize){
            $.ajax({
                url: '/',
                type: 'POST',
                cache: false,
                data: { rebuild: 1, sid: binder.sid },
                success: function(html){
                    binder.initSidebar(html);
                    finalize();
                },
                error: function(){
                    $('#dialogResutMessage').text('error.');
                }
            });
        });
    },
    
    dialog: function(messageText, inputType, inputValue, callback, selectDir, selectValue){
        var binder = this;
        var overlay = $(document.createElement('div'));
        overlay.attr('class', 'dialogOverlay');
        overlay.height($(document).height());

        var dialog = $(document.createElement('div'));
        dialog.attr('id', 'dialog');
        dialog.attr('class', 'dialog');

        var finalize = function(){
            overlay.remove();
            dialog.remove();
        };

        var message = $(document.createElement('div'));
        message.attr('class', 'dialogMessage');
        message.text(messageText);
        dialog.append(message);

        var select;
        if (selectDir) {
            var selectArea = $(document.createElement('div'));
            dialog.append(selectArea);

            var label = $(document.createElement('span'));
            label.text('dir: ');
            select = $(document.createElement('select'));
            var option = $(document.createElement('option'));
            option.attr('value', '/');
            option.text('/');
            select.append(option);
            jQuery.each(binder.dirs, function(){
                var dt = $(this);
                var option = $(document.createElement('option'));
                option.attr('value', dt.data('file'));
                option.text(dt.data('file'));
                select.append(option);
            });
            selectArea.append(label);
            selectArea.append(select);
            
            if (selectValue) {
                select.val(selectValue);
            }
        }

        var inputArea = $(document.createElement('div'));
        dialog.append(inputArea);

        var input = $(document.createElement('input'));
        input.attr('type', inputType);
        input.val(inputValue);
        if (inputType == 'text') {
            var label = $(document.createElement('span'));
            label.text('name: ');
            inputArea.append(label);
        }
        inputArea.append(input);

        var buttons = $(document.createElement('div'));
        dialog.append(buttons);
        
        var ok = $(document.createElement('input'));
        ok.attr('type', 'button');
        ok.attr('value', 'OK');
        ok.bind('click', function(){
            if (selectDir) {
                callback(select.val(), input.val(), finalize);
            } else {
                callback(input.val(), finalize);
            }
        });
        buttons.append(ok);
        
        var cancel = $(document.createElement('input'));
        cancel.attr('type', 'button');
        cancel.attr('value', 'CANCEL');
        cancel.bind('click', function(){
            finalize();
        });
        buttons.append(cancel);

        var result = $(document.createElement('div'));
        result.attr('id', 'dialogResutMessage');
        result.attr('class', 'dialogResutMessage');
        dialog.append(result);

        var body = $('body');
        if (jQuery.browser.msie) {
            overlay.css('opacity', '.4')
        }
        body.append(overlay);
        body.append(dialog);

        dialog.css('margin-top', ((dialog.height() / 2 * -1) + $(document).scrollTop()) + 'px');
        dialog.css('margin-left', (dialog.width() / 2 * -1) + 'px');

        if (selectDir) {
            select.focus();
        } else if (inputType == 'hidden') {
            ok.focus();
        } else {
            input.focus();
        }
        input.keypress(function (e) {
            if (e.keyCode == 13) {
                ok.click();
            }
        });
    }
}
