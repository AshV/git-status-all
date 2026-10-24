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

function copyCommand(text, btnElement) {
    navigator.clipboard.writeText(text).then(() => {
        const originalText = btnElement.innerText;
        btnElement.innerText = "Copied!";
        btnElement.classList.add("copied");
        setTimeout(() => {
            btnElement.innerText = originalText;
            btnElement.classList.remove("copied");
        }, 2000);
    }).catch(err => {
        console.error("Failed to copy:", err);
    });
}

