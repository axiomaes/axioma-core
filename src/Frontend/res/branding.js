/**
 * Axioma Core Branding
 * Module-based (src/Frontend/res/branding.js)
 */
(function () {
    const BRAND_NAME = "Axioma Core";
    const ATTRIBUTION_TEXT = "Gestión inteligente por Axioma";

    console.log("Axioma Core Branding Loaded (Module)");

    /**
     * Updates the document title on the login page.
     */
    function updateTitle() {
        if (Backbone.history.fragment === '' || Backbone.history.fragment === 'login') {
            if (document.title !== BRAND_NAME) {
                document.title = BRAND_NAME;
            }
        }
    }

    /**
     * Injects neutral attribution on the login page.
     * Appends to .login-container with class .axioma-login-attribution
     */
    function injectLoginAttribution() {
        const loginContainer = document.querySelector('.login-container');
        if (!loginContainer) return;

        // Check if already injected to avoid duplicates
        if (document.querySelector('.axioma-login-attribution')) return;

        const attribution = document.createElement('div');
        attribution.className = 'axioma-login-attribution';
        attribution.innerText = ATTRIBUTION_TEXT;

        // Append below the login form
        loginContainer.appendChild(attribution);
    }

    /**
     * Observe DOM changes to handle SPA navigation re-rendering
     */
    const observer = new MutationObserver((mutations) => {
        const isLoginPage = (Backbone.history.fragment === '' || Backbone.history.fragment === 'login');

        if (isLoginPage) {
            updateTitle();
            injectLoginAttribution();
        }
    });

    // Start observing body for SPA changes
    const targetNode = document.body || document.documentElement;
    observer.observe(targetNode, { childList: true, subtree: true });

    // Initial run
    document.addEventListener('DOMContentLoaded', () => {
        const isLoginPage = (window.location.hash === '' || window.location.hash === '#login');
        if (isLoginPage) {
            updateTitle();
            injectLoginAttribution();
        }
    });
})();
