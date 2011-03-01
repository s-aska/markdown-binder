function MarkdownBinder() {
}

MarkdownBinder.prototype = {

    sid: false,
    expanded: true,
    gone: false,
    mode: false,
    path: false,
    editing: false,

    // util
    source: function() {
        if (this.path == '/') {
            return '/TOP.txt';
        } else {
            return this.path + '.txt';
        }
    },

    // navigation
    go: function(path){
        if (history.pushState) {
            history.pushState(path, '', location.protocol + '//' + location.host + path);
        }
        this.load(path);
        if (this.editing) {
            this.closeEditor();
        }
    },

    load: function(path){
        var binder = this;
        var url = path;
        if (url == '/') {
            url = url + 'TOP';
        }
        if (jQuery.browser.msie) {
            url = encodeURI(url);
        }
        $.ajax({
            url: url + '.html',
            success: function(html){
                binder.gone = true;
                binder.initDocument(html);
                binder.path = path;
                binder.initPagemenu();
            },
            error: function(XMLHttpRequest, status, errorThrown){
                $('#document').html(status + ': ' + errorThrown);
                $('#pagemenu').hide();
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
        $('#new').bind('click', function(){binder.dispNewpageDialog();return false;});
        $('#rebuild').bind('click', function(){binder.dispRebuildDialog();return false;});

        // init 
        binder.path = location.pathname;
        binder.initSidebar();
        binder.initPagemenu();
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
        $('#adminsidemenu').show();

        // make admin page menu
        var doc = $('#document');

        var pagemenu = $('#pagemenu');

        var editpage = $(document.createElement('a'));
        editpage.attr('href', '#');
        editpage.text('edit');
        editpage.bind('click', function(){binder.openEditor(); return false;});

        var copypage = $(document.createElement('a'));
        copypage.attr('href', '#');
        copypage.text('copy');
        copypage.bind('click', function(){
            binder.dialog('copy page', 'text', binder.path, function(value, finalize){
                $.ajax({
                    url: binder.path,
                    type: 'POST',
                    cache: false,
                    data: { copy: value, sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        finalize();
                    },
                    error: function(){
                        $('#dialogResutMessage').text('error.');
                    }
                });
            });
            return false;
        });

        var renamepage = $(document.createElement('a'));
        renamepage.attr('href', '#');
        renamepage.text('rename');
        renamepage.bind('click', function(){
            binder.dialog('rename page', 'text', binder.path, function(value, finalize){
                $.ajax({
                    url: binder.path,
                    type: 'POST',
                    cache: false,
                    data: { rename: value, sid: binder.sid },
                    success: function(html){
                        binder.initSidebar(html);
                        binder.go(value);
                        finalize();
                    },
                    error: function(XMLHttpRequest, status, errorThrown){
                        $('#dialogResutMessage').text(status + ': ' + errorThrown);
                    }
                });
            });
            return false;
        });

        var deletepage = $(document.createElement('a'));
        deletepage.attr('href', '#');
        deletepage.text('delete');
        deletepage.bind('click', function(){
            binder.dialog('delete this page now ?', 'hidden', '', function(value, finalize){
                $('#document').html('deleted this page.');
                $('#pagemenu').hide();
                binder.initHeight();
                $.ajax({
                    url: binder.path,
                    type: 'POST',
                    cache: false,
                    data: { 'delete': 1, sid: binder.sid },
                    success: function(html){
                        $('dd').each(function(){
                            var dd = $(this);
                            var file = dd.data('file');
                            if (file && binder.path == file) {
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

        var adminmenu = $(document.createElement('div'));
        adminmenu.attr('id', 'adminmenu');
        adminmenu.append(editpage);
        adminmenu.append(document.createTextNode(' | '));
        adminmenu.append(copypage);
        adminmenu.append(document.createTextNode(' | '));
        adminmenu.append(renamepage);
        adminmenu.append(document.createTextNode(' | '));
        adminmenu.append(deletepage);
        pagemenu.append(adminmenu);

        var editor = $(document.createElement('textarea'));
        editor.attr('id', 'editor');

        var preview = $(document.createElement('div'));
        preview.attr('id', 'preview');

        var loading = $(document.createElement('div'));
        loading.attr('id', 'loading');
        loading.text('loading...');

        var edit_button = $(document.createElement('a'));
        edit_button.attr('href', '#');
        edit_button.text('edit');
        edit_button.bind('click', function(){
            editor.show();
            preview.hide();
            return false;
        });

        var preview_button = $(document.createElement('a'));
        preview_button.attr('href', '#');
        preview_button.text('preview');
        preview_button.bind('click', function(){
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
                },
                error: function(){
                    loading.text('auth error.');
                }
            });
            return false;
        });

        var discard_button = $(document.createElement('a'));
        discard_button.attr('href', '#');
        discard_button.text('discard');
        discard_button.bind('click', function(){
            editor.hide();
            editmenu.hide();
            preview.hide();
            doc.show();
            adminmenu.show();
            return false;
        });

        var save_button = $(document.createElement('a'));
        save_button.attr('href', '#');
        save_button.text('save');
        save_button.bind('click', function(){
            loading.text('saving...');
            loading.show();
            $.ajax({
                url: binder.path,
                type: 'POST',
                data: { save: 1, sid: binder.sid, content: $('#editor').val() },
                success: function(html){
                    doc.show();
                    binder.initDocument(html);
                    adminmenu.show();
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
        editmenu.append(edit_button);
        editmenu.append(document.createTextNode(' | '));
        editmenu.append(preview_button);
        editmenu.append(document.createTextNode(' | '));
        editmenu.append(discard_button);
        editmenu.append(document.createTextNode(' | '));
        editmenu.append(save_button);

        loading.hide();
        editor.hide();

        $('#content').append(editmenu);
        $('#content').append(loading);
        $('#content').append(editor);
        $('#content').append(preview);
    },

    initHeight: function(){
        $('#document').removeAttr('style');
        $('#sidebar').removeAttr('style');
        var sidebar_height = $('#sidebar').height();
        var document_height = $('#document').height();
        if (sidebar_height > document_height) {
            $('#document').height(sidebar_height);
        } else {
            $('#sidebar').height(document_height);
        }
    },

    initPagemenu: function() {
        var binder = this;
        $('#pagemenu').show();
        var permalink = $('#permalink');
        permalink.attr('href', binder.path);
        var source = $('#source');
        source.attr('href', binder.source());
    },

    initDocument: function(html){
        var binder = this;
        if (html) {
            $('#document').html(html);
            binder.initHeight();
        }
        $('#document').find('a').each(function(){
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
                ele.slideToggle('fast');
            }
            if (binder.sid) {
                dt.find('a').each(function(){
                    $(this).slideToggle('fast');
                });
            }
        });
    },

    initAdminSidebar: function(){
        var binder = this;
        $('#pages').find('dt').each(function(){
            var dt = $(this);
            var file = dt.data('file');
            var rename = $(document.createElement('a'));
            rename.text('rename');
            rename.attr('href', '#');
            rename.bind('click', function(){
                binder.dialog('rename dir', 'text', file, function(value, finalize){
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
            rename.hide();
            var del = $(document.createElement('a'));
            del.text('delete');
            del.attr('href', '#');
            del.bind('click', function(){
                binder.dialog('delete dir now ?', 'hidden', file, function(value, finalize){
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
            del.hide();
            dt.append(document.createTextNode(' '));
            dt.append(rename);
            dt.append(document.createTextNode(' '));
            dt.append(del);
        });
    },

    openEditor: function(){
        var binder = this;
        var doc = $('#document');
        var editor = $('#editor');
        var loading = $('#loading');
        var width = doc.width();
        var height = doc.height();
        if (height < 400) { height = 400 };
        doc.hide();
        $('#adminmenu').hide();
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
                binder.editing = true;
            }
        });
    },

    closeEditor: function(){
        var binder = this;
        if (binder.editing) {
            $('#document').show();
            $('#adminmenu').show();
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

    dispNewpageDialog: function(){
        var binder = this;
        var url = binder.path;
        url = url.replace(/[^\/]*$/, '');
        binder.dialog('new page', 'text', url, function(value, finalize){
            $.ajax({
                url: value,
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
        });
    },

    dispRebuildDialog: function(){
        var binder = this;
        binder.dialog('rebuild now ?', 'hidden', '', function(value, finalize){
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
    
    dialog: function(messageText, inputType, inputValue, callback){

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

        var inputArea = $(document.createElement('div'));
        dialog.append(inputArea);

        var input = $(document.createElement('input'));
        input.attr('type', inputType);
        input.val(inputValue);
        inputArea.append(input);

        var buttons = $(document.createElement('div'));
        dialog.append(buttons);
        
        var ok = $(document.createElement('input'));
        ok.attr('type', 'button');
        ok.attr('value', 'OK');
        ok.bind('click', function(){
            callback(input.val(), finalize);
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

        if (inputType == 'hidden') {
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
