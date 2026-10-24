/**
 * git status -all — Interactive Website Scripts
 */

// Platform Switcher
function switchPlatform(platformId, btn) {
    // Update tab buttons
    const buttons = document.querySelectorAll('.platform-tab-btn');
    buttons.forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');

    // Update panels
    const panels = document.querySelectorAll('.platform-panel');
    panels.forEach(p => p.classList.remove('active'));

    const targetPanel = document.getElementById(platformId);
    if (targetPanel) {
        targetPanel.classList.add('active');
    }
}

// Copy to Clipboard with Feedback
function copyCommand(text, btnElement) {
    if (!text || !btnElement) return;

    navigator.clipboard.writeText(text).then(() => {
        const originalContent = btnElement.innerHTML;
        btnElement.innerHTML = `
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
            Copied!
        `;
        btnElement.classList.add('copied');

        setTimeout(() => {
            btnElement.innerHTML = originalContent;
            btnElement.classList.remove('copied');
        }, 2200);
    }).catch(err => {
        console.error('Failed to copy to clipboard:', err);
    });
}

// Interactive Terminal Filter (All vs Dirty Only)
const terminalData = {
    all: `  <span class="t-cyan">╔══════════════════════════════════════════════════╗</span>
  <span class="t-cyan">║</span><span class="t-white">    git status --all v2.0.1  ·  Status Report    </span><span class="t-cyan">║</span>
  <span class="t-cyan">╚══════════════════════════════════════════════════╝</span>

  <span class="t-gray">Scanning:</span> D:\\Projects

  <span class="t-cyan">Repository          Branch        Mod    Unt   Push   Pull  Stash  Status</span>
  <span class="t-gray">──────────────────────────────────────────────────────────────────────────────────────────</span>
  my-web-app          <span class="t-yellow">main</span>            <span class="t-red">  3</span>    <span class="t-yellow">  1</span>    <span class="t-magenta">  2</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>  <span class="t-red">● Uncommitted, Unpushed</span>
  api-server          <span class="t-yellow">feature/auth</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-magenta">  5</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>  <span class="t-magenta">▲ Unpushed</span>
  docs-site           <span class="t-green">main</span>            <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-yellow">  1</span>  <span class="t-yellow">◌ Stash only</span>
  utils-lib           <span class="t-green">main</span>            <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>  <span class="t-green">✓ clean</span>

  <span class="t-gray">─────────────────────────────────────────</span>
  <span class="t-white">Total: 4</span>  │  <span class="t-red">Dirty: 3</span>  │  <span class="t-green">Clean: 1</span>  │  <span class="t-cyan">Time: 1.4s</span>

  <span class="t-gray">git status --all v2.0.1 · Built with ❤️ by AshV</span>`,

    dirty: `  <span class="t-cyan">╔══════════════════════════════════════════════════╗</span>
  <span class="t-cyan">║</span><span class="t-white">    git status --all v2.0.1  ·  Status Report    </span><span class="t-cyan">║</span>
  <span class="t-cyan">╚══════════════════════════════════════════════════╝</span>

  <span class="t-gray">Scanning:</span> D:\\Projects <span class="t-yellow">(Dirty only)</span>

  <span class="t-cyan">Repository          Branch        Mod    Unt   Push   Pull  Stash  Status</span>
  <span class="t-gray">──────────────────────────────────────────────────────────────────────────────────────────</span>
  my-web-app          <span class="t-yellow">main</span>            <span class="t-red">  3</span>    <span class="t-yellow">  1</span>    <span class="t-magenta">  2</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>  <span class="t-red">● Uncommitted, Unpushed</span>
  api-server          <span class="t-yellow">feature/auth</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-magenta">  5</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>  <span class="t-magenta">▲ Unpushed</span>
  docs-site           <span class="t-green">main</span>            <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-gray">  ·</span>    <span class="t-yellow">  1</span>  <span class="t-yellow">◌ Stash only</span>

  <span class="t-gray">─────────────────────────────────────────</span>
  <span class="t-white">Total: 3 (Filtered)</span>  │  <span class="t-red">Dirty: 3</span>  │  <span class="t-cyan">Time: 1.1s</span>

  <span class="t-gray">git status --all v2.0.1 · Built with ❤️ by AshV</span>`
};

function setTerminalFilter(mode, btn) {
    const termBody = document.getElementById('terminal-content');
    if (!termBody || !terminalData[mode]) return;

    termBody.innerHTML = `<pre>${terminalData[mode]}</pre>`;

    const btns = document.querySelectorAll('.term-filter-btn');
    btns.forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');
}
