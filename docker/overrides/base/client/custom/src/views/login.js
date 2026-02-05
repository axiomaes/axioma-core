define('custom:views/login', ['views/login'], function (Dep) {
    return Dep.extend({
        afterRender: function () {
            Dep.prototype.afterRender.call(this);
            this.hardenLoginBranding();
        },

        hardenLoginBranding: function () {
            // Force Logo
            var path = 'client/custom/img/logo.svg';
            var $logo = this.$el.find('.logo-container img');
            if ($logo.length) {
                $logo.attr('src', path);
            }

            // Remove branding text if present
            this.$el.find('.footer').hide();
        }
    });
});

// Enforce Override
define('views/login', ['custom:views/login'], function (Custom) {
    return Custom;
});
