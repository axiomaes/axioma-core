define('client/modules/axioma-core/views/login', ['views/login'], function (Dep) {

    return Dep.extend({

        setup: function () {
            Dep.prototype.setup.call(this);
            // Override the footer flag to prevent rendering
            this.hasFooter = false;
        },

        afterRender: function () {
            Dep.prototype.afterRender.call(this);

            // 1. Force Document Title
            document.title = 'Axioma Core';

            // 2. Inject Legal Attribution (Spanish)
            // Using standard jQuery append, safer than raw DOM hacks
            this.$el.find('.login-container form').after(
                '<div class="axioma-login-attribution" style="margin-top: 16px; font-size: 12px; color: #9aa0a6; opacity: 0.65; text-align: center; line-height: 1.4;">' +
                'Axioma Core utiliza como base un motor CRM open-source de uso empresarial, adaptado y extendido para ofrecer una solución propia orientada a la gestión avanzada de clientes y procesos.' +
                '</div>'
            );

            // 3. Ensure Footer is hidden (Double safety)
            var footer = document.querySelector('#footer, .footer, .global-footer');
            if (footer) footer.style.display = 'none';
        }
    });

});
