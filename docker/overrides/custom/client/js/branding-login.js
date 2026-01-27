
(function () {
    var PROCESS_NAME = 'Axioma Branding';
    console.log(PROCESS_NAME + ' loaded');

    var legalText = 'Axioma Core utiliza como base un motor CRM open-source de uso empresarial.';

    var run = function () {
        // Only run on login page
        var isLogin = document.body.classList.contains('login-page') ||
            document.body.classList.contains('login') ||
            document.querySelector('.login-container');

        if (!isLogin) return;

        // 1. Tag Body
        document.body.classList.add('axioma-login');

        // 2. Title Override (Aggressive)
        if (document.title.indexOf('EspoCRM') > -1 || document.title === 'Login') {
            document.title = 'Axioma Core';
        }

        // 3. Attribution Injection
        var container = document.querySelector('.login-container');
        if (container && !document.querySelector('.axioma-legal-text')) {
            var div = document.createElement('div');
            div.className = 'axioma-legal-text';
            div.innerText = legalText;

            // Try to append after the form-container
            var form = container.querySelector('.form-container') || container.querySelector('form');
            if (form) {
                form.parentNode.insertBefore(div, form.nextSibling);
            } else {
                container.appendChild(div);
            }
        }

        // 4. Logo / Label Text Replacement (Cleanup)
        // Remove text nodes that say "EspoCRM" near logos if any
        var brandLabels = document.querySelectorAll('.navbar-brand, .logo-container');
        brandLabels.forEach(function (el) {
            if (el.innerText.indexOf('EspoCRM') > -1) {
                el.childNodes.forEach(function (node) {
                    if (node.nodeType === 3 && node.nodeValue.indexOf('EspoCRM') > -1) {
                        node.nodeValue = node.nodeValue.replace('EspoCRM', 'Axioma Core');
                    }
                });
            }
        });
    };

    // Run immediately and on intervals to handle SPA rendering
    run();
    setInterval(run, 100);

})();
