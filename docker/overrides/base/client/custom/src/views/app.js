define('views/app', ['views/app'], function (Dep) {

    return Dep.extend({

        updatePageTitle: function () {
            // Call parent method first to set standard title
            Dep.prototype.updatePageTitle.call(this);

            var title = document.title;
            // Fetch branding from Config or I18n
            var appName = this.getConfig().get('applicationName') ||
                this.translate('applicationName', 'Global') ||
                'Axioma Core';

            // 1. Handle "EspoCRM" or "Login" default titles
            if (title === 'EspoCRM' || title === 'Login') {
                document.title = appName;
                return;
            }

            // 2. Append Branding if not already present
            if (title && title.indexOf(appName) === -1) {
                document.title = title + ' | ' + appName;
            }
        }
    });
});
