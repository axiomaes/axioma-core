define('views/login', ['views/login'], function (Dep) {

    return Dep.extend({

        setup: function () {
            Dep.prototype.setup.call(this);
        },

        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            var text = this.translate('axiomaAttribution', 'Global') || 'Gestión inteligente por Axioma';

            // Search for existing attribution to ensure idempotency
            if (this.$el.find('.axioma-attribution').length) {
                return;
            }

            // Create the attribution element
            var $attribution = $('<div>')
                .addClass('axioma-attribution text-muted text-center')
                .css({
                    'margin-top': '20px',
                    'font-size': '12px',
                    'opacity': '0.7'
                })
                .text(text);

            // Attempt to inject intelligently
            var $container = this.$el.find('.login-container');
            if ($container.length) {
                var $form = $container.find('form');
                if ($form.length) {
                    $form.after($attribution);
                } else {
                    $container.append($attribution);
                }
            } else {
                this.$el.append($attribution);
            }
        }
    });
});
