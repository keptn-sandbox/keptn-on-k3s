(function (b) {
    var a;
    b.message = {
        createEntryLeavePage: "You have attempted to leave this page. If you leave without clicking the Save or Publish buttons, your entry will be lost. Are you sure you want to exit this page?",
        dashboardInviteSuccess: "Your friends will be invited via email to join. Feel free to invite more friends by clicking &ldquo;invite more friends&rdquo;!",
        dashboardInviteFailure: "You can try sending again by clicking on the &ldquo;invite more friends&rdquo; link below, or try again later."
    };
    b.labels = {
        save: "Save",
        cancel: "Cancel",
        edit: "Edit",
        close: "Close"
    };
    b.empty = function (c) {
        return b(c).length === 0
    };
    b.defined = function (c) {
        return typeof(c) !== "undefined"
    };
    b.getLoginValidationOptions = function () {
        var c = {
            submitHandler: function (d) {
                MainGlobal.disableLoginButtons();
                d.submit()
            },
            invalidHandler: function (e, d) {
                var f = d.numberOfInvalids();
                if (f > 1) {
                    d.showErrors({
                        j_username: "Please enter a valid email address and password.",
                        j_password: "Please enter a valid email address and password."
                    })
                }
            },
            errorElement: "span",
            onkeyup: false,
            onclick: false,
            groups: {
                credentials: "j_username j_password"
            },
            errorPlacement: function (d, e) {
                if (e.attr("name") == "j_username" || e.attr("name") == "j_password") {
                    d.insertAfter(b(e).parents("ul").find("input[name=j_password]"))
                } else {
                    d.insertAfter(e)
                }
            },
            rules: {
                j_username: {
                    required: true,
                    email: true
                },
                j_password: {
                    required: true,
                    rangelength: [1, 1000]
                }
            },
            messages: {
                j_username: {
                    required: "Please enter your email address.",
                    email: "Your email must be of format name@email.com"
                },
                j_password: {
                    required: "Please enter your password.",
                    rangelength: "Your password must be at least 6 characters long."
                }
            },
            showErrors: function (d, e) {
                this.defaultShowErrors();
                if (e.length > 1) {
                    b(".globalHeader li.open .headerDropdown li span.error").eq(0).html("Please enter your email address and password.");
                    b(".globalHeader li.open .headerDropdown li span.error").filter(function (f) {
                        return f > 0
                    }).remove()
                }
            }
        };
        return c
    };
    b.getForgotPwValidationOptions = function () {
        var c = {
            submitHandler: function (d) {
                MainGlobal.disableLoginButtons();
                d.submit()
            },
            errorElement: "span",
            rules: {
                forgotEmail: {
                    required: true,
                    email: true
                }
            },
            messages: {
                forgotEmail: {
                    required: "Please enter your email address.",
                    email: "Your email must be of format name@email.com"
                }
            }
        };
        return c
    };
    b.getCookie = function (h) {
        var d = document.cookie;
        var g = d.indexOf(h + "=");
        if (g !== -1) {
            var f = g + h.length + 1;
            var c = d.indexOf(";", f);
            if (c === -1) {
                c = d.length
            }
            var e = d.substring(f, c);
            e = decodeURIComponent(e)
        }
        return e
    };
    b.setCookie = function (h, g, c) {
        var f = c || -1;
        var e = new Date();
        e.setTime(e.getTime() + (1000 * 60 * 60 * 24 * f));
        var d = h.toString();
        d = d + "=";
        d = d + encodeURIComponent(g).toString();
        d = d + "; path=/";
        if (f !== -1) {
            d = d + "; expires=";
            d = d + e.toGMTString()
        }
        document.cookie = d
    };
})(jQuery);
if (!$.browser.msie || ($.browser.mozilla && parseFloat($.browser.version) < 1.9)) {
    $.event.remove(window, "unload")
};