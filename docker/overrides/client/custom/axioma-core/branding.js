/**
 * Axioma Core Branding
 * Persistent override via docker/overrides
 */
(function () {
    const BRAND_NAME = "Axioma Core";
    const ATTRIBUTION_TEXT = "Gestión inteligente por Axioma";

    console.log("Axioma Core Branding Loaded");

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
     * Does NOT touch the footer. PREPENDS or APPENDS to login form or similar safe area.
     */
    function injectLoginAttribution() {
        const loginContainer = document.querySelector('.login-container');
        if (!loginContainer) return;

        // Check if already injected to avoid duplicates
        if (document.getElementById('axioma-attribution')) return;

        const attribution = document.createElement('div');
        attribution.id = 'axioma-attribution';
        attribution.innerText = ATTRIBUTION_TEXT;
        attribution.style.textAlign = 'center';
        attribution.style.marginTop = '20px';
        attribution.style.fontSize = '0.9em';
        attribution.style.opacity = '0.7';
        attribution.style.fontFamily = 'var(--font-family, sans-serif)';

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
    observer.observe(document.body, { childList: true, subtree: true });

    // Initial run
    document.addEventListener('DOMContentLoaded', () => {
        const isLoginPage = (window.location.hash === '' || window.location.hash === '#login');
        if (isLoginPage) {
            updateTitle();
            injectLoginAttribution();
        }
    });

    // Also listen to backbone router if available eventually, but observer is robust enough for light branding.
})();
