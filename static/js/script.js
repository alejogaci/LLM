let currentModel = 'llama3.2';
let isStreaming = false;

// Auto-resize textarea
const messageInput = document.getElementById('messageInput');
messageInput.addEventListener('input', function() {
    this.style.height = 'auto';
    this.style.height = (this.scrollHeight) + 'px';
});

// Handle Enter key
function handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
    }
}

// Send message
async function sendMessage() {
    const message = messageInput.value.trim();
    if (!message || isStreaming) return;
    
    // Hide welcome screen
    const welcomeScreen = document.querySelector('.welcome-screen');
    if (welcomeScreen) {
        welcomeScreen.style.animation = 'fadeOut 0.3s ease-out';
        setTimeout(() => welcomeScreen.remove(), 300);
    }
    
    // Add user message
    addMessage(message, 'user');
    messageInput.value = '';
    messageInput.style.height = 'auto';
    
    // Add AI typing indicator
    const aiMessageDiv = addMessage('', 'ai', true);
    
    isStreaming = true;
    updateSendButton(true);
    
    try {
        const response = await fetch('/api/chat', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ message: message })
        });
        
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let aiResponse = '';
        
        // Remove typing indicator
        const typingIndicator = aiMessageDiv.querySelector('.typing-indicator');
        if (typingIndicator) {
            typingIndicator.remove();
        }
        
        // Create content div for streaming text
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        aiMessageDiv.appendChild(contentDiv);
        
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            const chunk = decoder.decode(value);
            const lines = chunk.split('\n');
            
            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    try {
                        const data = JSON.parse(line.slice(6));
                        
                        // Handle GuardTrail blocked message
                        if (data.blocked && data.guardtrail) {
                            contentDiv.innerHTML = `
                                <div style="color: var(--trend-red); 
                                            background: rgba(220, 38, 38, 0.1); 
                                            padding: 15px; 
                                            border-radius: 8px; 
                                            border-left: 4px solid var(--trend-red);">
                                    ${formatMessage(data.message)}
                                </div>
                            `;
                            break;
                        }
                        
                        if (data.error) {
                            contentDiv.innerHTML = `<span style="color: var(--trend-red-light);">Error: ${data.error}</span>`;
                            break;
                        }
                        
                        if (data.token) {
                            aiResponse += data.token;
                            contentDiv.innerHTML = formatMessage(aiResponse);
                            scrollToBottom();
                        }
                        
                        if (data.done) {
                            break;
                        }
                    } catch (e) {
                        console.error('Error parsing JSON:', e);
                    }
                }
            }
        }
        
    } catch (error) {
        console.error('Error:', error);
        const contentDiv = aiMessageDiv.querySelector('.message-content') || 
                          aiMessageDiv.appendChild(document.createElement('div'));
        contentDiv.className = 'message-content';
        contentDiv.innerHTML = `<span style="color: var(--trend-red-light);">Error: ${error.message}</span>`;
    } finally {
        isStreaming = false;
        updateSendButton(false);
    }
}

// Add message to chat
function addMessage(content, sender, isTyping = false) {
    const messagesContainer = document.getElementById('messagesContainer');
    
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${sender}-message`;
    
    const headerDiv = document.createElement('div');
    headerDiv.className = 'message-header';
    
    const avatarDiv = document.createElement('div');
    avatarDiv.className = 'message-avatar';
    avatarDiv.textContent = sender === 'user' ? 'U' : 'AI';
    
    const nameSpan = document.createElement('span');
    nameSpan.className = 'message-name';
    nameSpan.textContent = sender === 'user' ? 'Tú' : 'Trend AI';
    
    const timeSpan = document.createElement('span');
    timeSpan.className = 'message-time';
    timeSpan.textContent = getCurrentTime();
    
    headerDiv.appendChild(avatarDiv);
    headerDiv.appendChild(nameSpan);
    headerDiv.appendChild(timeSpan);
    messageDiv.appendChild(headerDiv);
    
    if (isTyping) {
        const typingDiv = document.createElement('div');
        typingDiv.className = 'typing-indicator';
        typingDiv.innerHTML = '<span class="typing-dot"></span><span class="typing-dot"></span><span class="typing-dot"></span>';
        messageDiv.appendChild(typingDiv);
    } else {
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        contentDiv.innerHTML = formatMessage(content);
        messageDiv.appendChild(contentDiv);
    }
    
    messagesContainer.appendChild(messageDiv);
    scrollToBottom();
    
    return messageDiv;
}

// Format message content
function formatMessage(text) {
    // Basic markdown-like formatting
    let formatted = text
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/`(.*?)`/g, '<code>$1</code>')
        .replace(/\n/g, '<br>');
    
    return formatted;
}

// Get current time
function getCurrentTime() {
    const now = new Date();
    return now.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
}

// Scroll to bottom
function scrollToBottom() {
    const messagesContainer = document.getElementById('messagesContainer');
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

// Update send button state
function updateSendButton(disabled) {
    const sendBtn = document.getElementById('sendBtn');
    sendBtn.disabled = disabled;
}

// Send suggestion
function sendSuggestion(text) {
    messageInput.value = text;
    sendMessage();
}

// New chat
function newChat() {
    const messagesContainer = document.getElementById('messagesContainer');
    messagesContainer.innerHTML = `
        <div class="welcome-screen">
            <div class="welcome-icon">
                <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="50" cy="50" r="45" fill="url(#welcomeGradient)" opacity="0.1"/>
                    <path d="M50 20L25 35L50 50L75 35L50 20Z" fill="url(#welcomeGradient2)"/>
                    <path d="M25 65L50 80L75 65" stroke="url(#welcomeGradient3)" stroke-width="3" stroke-linecap="round"/>
                    <path d="M25 50L50 65L75 50" stroke="url(#welcomeGradient4)" stroke-width="3" stroke-linecap="round"/>
                    <defs>
                        <linearGradient id="welcomeGradient" x1="5" y1="5" x2="95" y2="95">
                            <stop offset="0%" stop-color="#D32F2F"/>
                            <stop offset="100%" stop-color="#FF5252"/>
                        </linearGradient>
                        <linearGradient id="welcomeGradient2" x1="25" y1="20" x2="75" y2="50">
                            <stop offset="0%" stop-color="#D32F2F"/>
                            <stop offset="100%" stop-color="#FF5252"/>
                        </linearGradient>
                        <linearGradient id="welcomeGradient3" x1="25" y1="65" x2="75" y2="80">
                            <stop offset="0%" stop-color="#D32F2F"/>
                            <stop offset="100%" stop-color="#FF5252"/>
                        </linearGradient>
                        <linearGradient id="welcomeGradient4" x1="25" y1="50" x2="75" y2="65">
                            <stop offset="0%" stop-color="#D32F2F"/>
                            <stop offset="100%" stop-color="#FF5252"/>
                        </linearGradient>
                    </defs>
                </svg>
            </div>
            <h2>Bienvenido a Trend Micro AI</h2>
            <p>Tu asistente inteligente impulsado por IA de código abierto</p>
            <div class="suggestion-cards">
                <div class="suggestion-card" onclick="sendSuggestion('Explícame sobre seguridad en la nube')">
                    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M13 2L3 14H12L11 22L21 10H12L13 2Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <span>Seguridad en la nube</span>
                </div>
                <div class="suggestion-card" onclick="sendSuggestion('¿Cuáles son las mejores prácticas de ciberseguridad?')">
                    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 22C12 22 20 18 20 12V5L12 2L4 5V12C4 18 12 22 12 22Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <span>Mejores prácticas</span>
                </div>
                <div class="suggestion-card" onclick="sendSuggestion('¿Qué es el phishing y cómo prevenirlo?')">
                    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2ZM11 17H13V15H11V17ZM13 13H11V7H13V13Z" fill="currentColor"/>
                    </svg>
                    <span>Prevenir phishing</span>
                </div>
                <div class="suggestion-card" onclick="sendSuggestion('Dame consejos sobre protección de datos personales')">
                    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M19 11H5C3.89543 11 3 11.8954 3 13V20C3 21.1046 3.89543 22 5 22H19C20.1046 22 21 21.1046 21 20V13C21 11.8954 20.1046 11 19 11Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        <path d="M7 11V7C7 5.67392 7.52678 4.40215 8.46447 3.46447C9.40215 2.52678 10.6739 2 12 2C13.3261 2 14.5979 2.52678 15.5355 3.46447C16.4732 4.40215 17 5.67392 17 7V11" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                    <span>Protección de datos</span>
                </div>
            </div>
        </div>
    `;
}

// Change model
function changeModel() {
    const modelSelect = document.getElementById('modelSelect');
    currentModel = modelSelect.value;
    document.getElementById('currentModel').textContent = modelSelect.options[modelSelect.selectedIndex].text;
    
    // Show notification
    showNotification(`Modelo cambiado a ${modelSelect.options[modelSelect.selectedIndex].text}`);
}

// Show notification
function showNotification(message) {
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: linear-gradient(135deg, var(--trend-red), var(--trend-red-dark));
        color: white;
        padding: 16px 24px;
        border-radius: 8px;
        box-shadow: var(--shadow-lg);
        z-index: 1000;
        animation: slideInRight 0.3s ease-out;
    `;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOutRight 0.3s ease-out';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// Add CSS animations for notifications
const style = document.createElement('style');
style.textContent = `
    @keyframes slideInRight {
        from {
            transform: translateX(400px);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOutRight {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(400px);
            opacity: 0;
        }
    }
    
    @keyframes fadeOut {
        from {
            opacity: 1;
            transform: scale(1);
        }
        to {
            opacity: 0;
            transform: scale(0.95);
        }
    }
`;
document.head.appendChild(style);

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    messageInput.focus();
});
