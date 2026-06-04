function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastMsg = document.getElementById('toast-message');
    
    toastMsg.textContent = message;
    toast.className = `toast ${type}`;
    
    setTimeout(() => {
        toast.classList.add('hidden');
    }, 3000);
}

document.addEventListener('DOMContentLoaded', () => {
    // Setup Database Button
    const setupBtn = document.getElementById('btn-setup');
    if (setupBtn) {
        setupBtn.addEventListener('click', async () => {
            const statusDiv = document.getElementById('setup-status');
            setupBtn.disabled = true;
            setupBtn.textContent = 'Initializing...';
            
            try {
                const res = await fetch('/setup', { method: 'POST' });
                const data = await res.json();
                
                if (data.success) {
                    showToast(data.message, 'success');
                    statusDiv.innerHTML = `<span class="success">✓ Database initialized successfully</span>`;
                } else {
                    showToast('Failed to initialize database', 'error');
                    statusDiv.innerHTML = `<span style="color: var(--error)">Error: ${data.message}</span>`;
                }
            } catch (err) {
                showToast('Network error occurred', 'error');
            } finally {
                setupBtn.disabled = false;
                setupBtn.textContent = 'Initialize Database';
                statusDiv.classList.remove('hidden');
            }
        });
    }
});
