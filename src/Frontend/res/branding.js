
// Axioma Core - Login Branding Script
(function () {
    console.log('Axioma Core Branding Loaded');

    // 1. Title Override & Attribution Injection
    // We use an interval to catch the login container as it renders
    var checkInterval = setInterval(function () {
        
        // A. Title Override (Login Page)
        if (document.body.classList.contains('login-page') || document.body.classList.contains('login')) {
            if (document.title !== 'Axioma Core') {
                document.title = 'Axioma Core';
            }
        }

        // B. Attribution Injection
        var container = document.querySelector('.login-container');
        if (container) {
            // Check if already injected to avoid duplicates
            if (!container.querySelector('.axioma-login-attribution')) {
                var attribution = document.createElement('div');
                attribution.className = 'axioma-login-attribution';
                attribution.innerHTML = 'Axioma Core utiliza como base un motor CRM open-source de uso empresarial, ampliado y adaptado para ofrecer una plataforma de gestión unificada.';
                
                // Append relative to form or at bottom of container
                var form = container.querySelector('form');
                if (form) {
                    form.parentNode.insertBefore(attribution, form.nextSibling);
                } else {
                    container.appendChild(attribution);
                }
            }
        }
    }, 200);

    // Stop checking after 30 seconds to save resources (optional, but good practice)
    setTimeout(function() {
        // We don't clear interval because SPAs might re-render login. 
        // But we could throttle it. For now, constant check is safest for login.
    }, 30000);

})();
