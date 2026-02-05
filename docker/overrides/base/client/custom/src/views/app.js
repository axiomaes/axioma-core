define('custom:views/app', ['views/app'], function (Dep) {
    return Dep.extend({
        afterRender: function () {
            Dep.prototype.afterRender.call(this);
            this.hardenBranding();
        },

        hardenBranding: function () {
            // Force Logo
            var path = 'client/custom/img/logo.svg';
            var $logo = this.$el.find('.navbar-header .navbar-brand img');
            if ($logo.length) {
                $logo.attr('src', path);
            }

            // Force Title
            var $title = this.$el.find('.navbar-header .navbar-brand');
            // Check if text node exists or we need to replace it. 
            // Often logo is inside brand.
            // We want to ensure 'Axioma Core' is the title if visible.
            document.title = 'Axioma Core';
        }
    });
});

// Enforce Override by hijacking the Module ID
define('views/app', ['custom:views/app'], function (Custom) {
    return Custom;
});
