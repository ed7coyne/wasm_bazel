// Test JavaScript file
console.log('Static webserver test script loaded!');

const TestApp = {
    name: 'Static Webserver',
    version: '1.0.0',
    
    init: function() {
        console.log(`${this.name} v${this.version} initialized`);
        this.createTestElements();
    },
    
    createTestElements: function() {
        const testArea = document.getElementById('test-area');
        if (testArea) {
            testArea.innerHTML = `
                <div class="test-box success">
                    <h3>✅ JavaScript Loaded Successfully</h3>
                    <p>This confirms that JavaScript files are being served correctly with the proper MIME type.</p>
                    <p>Current time: ${new Date().toLocaleString()}</p>
                </div>
            `;
        }
    },
    
    // Utility function
    formatData: function(data) {
        return JSON.stringify(data, null, 2);
    }
};

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    TestApp.init();
});

// Export for testing
if (typeof module !== 'undefined' && module.exports) {
    module.exports = TestApp;
}