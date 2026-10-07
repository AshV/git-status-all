function showTab(tabId) {
    // Hide all tab contents
    const contents = document.querySelectorAll('.tab-content');
    contents.forEach(content => {
        content.classList.remove('active');
    });

    // Remove active class from all tabs
    const tabs = document.querySelectorAll('.tab-btn');
    tabs.forEach(tab => {
        tab.classList.remove('active');
    });

    // Show selected tab content and activate tab button
    document.getElementById(tabId).classList.add('active');
    event.currentTarget.classList.add('active');
}
