/**
 * PRODUCTION-GRADE Main Logic for CureNet Doctor Portal
 * Handles QR scanning, manual entry, and E2EE health data decryption.
 */

let doctorKeyPair = null;
let html5QrCode = null;
const host = window.location.hostname || "localhost";
const BACKEND_URL = `http://${host}:3000`;

// Debug Logger
function debugLog(msg, isError = false) {
    const content = document.getElementById('debug-content');
    if (!content) return;
    const line = document.createElement('div');
    line.className = isError ? 'debug-line debug-err' : 'debug-line';
    line.innerText = `[${new Date().toLocaleTimeString()}] ${msg}`;
    content.appendChild(line);
    content.scrollTop = content.scrollHeight;
    console.log(`[DEBUG] ${msg}`);
}

// ─── INITIALIZATION ─────────────────────────────────────────────────────────

window.addEventListener('load', async () => {
    debugLog("System Initializing...");
    
    try {
        // 1. Generate Doctor's session keys
        if (typeof CryptoUtils !== 'undefined') {
            doctorKeyPair = CryptoUtils.generateKeyPair();
            debugLog("X25519 Keys Generated (E2EE Active)");
        } else {
            throw new Error("CryptoUtils not found!");
        }

        // 2. Setup UI Listeners
        attachListeners();
        debugLog("Event Listeners Attached");

        // 3. Check Backend
        checkBackend();

    } catch (e) {
        debugLog(`Initialization Error: ${e.message}`, true);
        showToast("System initialization failed", "error");
    }
});

function attachListeners() {
    const qrInput = document.getElementById('qr-input');
    const btnManual = document.getElementById('btn-manual');
    const closeViewer = document.getElementById('close-viewer');

    if (qrInput) qrInput.addEventListener('change', handleFileUpload);
    if (btnManual) btnManual.addEventListener('click', handleManualEntry);
    if (closeViewer) closeViewer.addEventListener('click', () => {
        document.getElementById('data-viewer').classList.remove('active');
    });

    // Scanner placeholder click
    const placeholder = document.getElementById('scanner-placeholder');
    if (placeholder) {
        placeholder.addEventListener('click', startCamera);
    }
}

async function checkBackend() {
    try {
        const res = await fetch(`${BACKEND_URL}/`);
        const data = await res.json();
        debugLog(`Backend Connected: ${data.msg}`);
    } catch (e) {
        debugLog("Backend Unreachable! Check local IP.", true);
    }
}

// ─── SCANNING LOGIC ──────────────────────────────────────────────────────────

async function startCamera() {
    debugLog("Starting Camera Scanner...");
    try {
        if (!html5QrCode) {
            html5QrCode = new Html5Qrcode("qr-reader");
        }
        
        document.getElementById('scanner-placeholder').style.display = 'none';
        
        const config = { fps: 20, qrbox: { width: 300, height: 300 } };
        await html5QrCode.start({ facingMode: "environment" }, config, (text) => {
            debugLog("Camera Scan Success");
            onScanSuccess(text);
        });
    } catch (err) {
        debugLog(`Camera Error: ${err}`, true);
        showToast("Could not start camera", "error");
        document.getElementById('scanner-placeholder').style.display = 'flex';
    }
}

async function handleFileUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    debugLog(`Processing Upload: ${file.name}`);
    showToast("Scanning Image...");

    if (!html5QrCode) {
        html5QrCode = new Html5Qrcode("qr-reader");
    }

    try {
        const decodedText = await html5QrCode.scanFile(file, true);
        debugLog("File Scan Result Received");
        onScanSuccess(decodedText);
    } catch (err) {
        debugLog(`File Scan Failed: ${err}`, true);
        showToast("Failed to read QR from image", "error");
    }
}

async function handleManualEntry() {
    const input = document.getElementById('manual-token');
    const token = input.value.trim();
    debugLog("Manual Entry Triggered");
    
    if (token) {
        processQrData(token);
        input.value = ""; // Clear for next use
    } else {
        debugLog("Empty Manual Entry", true);
        showToast("Please enter a valid link", "error");
    }
}

function onScanSuccess(decodedText) {
    if (html5QrCode && html5QrCode.isScanning) {
        html5QrCode.stop().catch(() => {});
    }
    document.getElementById('scanner-placeholder').style.display = 'flex';
    processQrData(decodedText);
}

// ─── ABDM WORKFLOW ───────────────────────────────────────────────────────────

async function processQrData(input) {
    debugLog(`Parsing QR Data: ${input.substring(0, 30)}...`);
    try {
        let tokenB64 = "";
        let patientPubKeyB64 = "";

        // Parse: curenet://consent?v=3&token=<token>&pub=<patient_pub_key>
        if (input.startsWith('curenet://')) {
            const urlObj = new URL(input.replace('curenet://', 'http://localhost/'));
            tokenB64 = urlObj.searchParams.get('token');
            patientPubKeyB64 = urlObj.searchParams.get('pub');
        } else {
            // Fallback for raw query strings
            const params = new URLSearchParams(input.includes('?') ? input.split('?')[1] : input);
            tokenB64 = params.get('token');
            patientPubKeyB64 = params.get('pub');
        }

        if (!tokenB64 || !patientPubKeyB64) {
            throw new Error("Invalid QR: This is not a valid CureNet Access QR. Please scan a CureNet QR code.");
        }

        // Sanitize for production (remove screenshot noise)
        tokenB64 = tokenB64.trim().replace(/\s/g, '');
        patientPubKeyB64 = patientPubKeyB64.trim().replace(/\s/g, '');

        // Decode token
        let token;
        try {
            const sanitized = tokenB64.replace(/-/g, '+').replace(/_/g, '/');
            token = JSON.parse(atob(sanitized));
        } catch (e) {
            throw new Error("Corrupted Data: Could not decode secure token.");
        }
        
        if (!token.abha || !token.sid) {
            throw new Error("Invalid Token: Missing identity or session data.");
        }

        debugLog(`Valid Token for ABHA: ${token.abha}`);
        initiateRequest(token.abha, patientPubKeyB64, token.sid);

    } catch (e) {
        debugLog(`SCAN ERROR: ${e.message}`, true);
        showToast(e.message, "error");
    }
}

async function initiateRequest(abha, patientPubKeyB64, sessionId) {
    debugLog(`Initiating Backend Request for ${abha}...`);
    
    if (!doctorKeyPair) {
        debugLog("Warning: Keypair missing. Regenerating...", true);
        doctorKeyPair = CryptoUtils.generateKeyPair();
    }

    try {
        const response = await fetch(`${BACKEND_URL}/api/consent/init`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                abha,
                sessionId,
                patientPubKey: patientPubKeyB64,
                doctorPubKey: CryptoUtils.toBase64(doctorKeyPair.publicKey),
                doctorName: "Dr. Suresh Kumar (ABDM HIU)",
                doctorId: "REG_100192"
            })
        });

        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || "Backend returned failure status.");
        }

        const reqId = data.request.requestId;
        
        debugLog(`Request Created: ${reqId}. Polling for patient...`);
        updateRequestUI(abha, reqId, patientPubKeyB64);
        
        startPolling(abha, reqId, patientPubKeyB64);
    } catch (e) {
        debugLog(`Backend Error: ${e.message}`, true);
        showToast(e.message || "Backend connection failed", "error");
    }
}

function updateRequestUI(abha, reqId, patientPubKeyB64) {
    const list = document.getElementById('request-list');
    const empty = list.querySelector('.empty-state');
    if (empty) empty.remove();

    const item = document.createElement('div');
    item.className = 'request-item';
    item.id = `item-${reqId}`;
    item.innerHTML = `
        <div class="req-patient-info">
            <h4>${abha}</h4>
            <p>ID: ${reqId}</p>
        </div>
        <div class="req-status">
            <span class="status-tag status-pending" id="status-${reqId}">Waiting...</span>
        </div>
        <button class="btn btn-primary btn-sm" id="btn-${reqId}" style="display:none">View Data</button>
    `;
    list.prepend(item);
    document.getElementById('active-count').innerText = list.children.length;
}

function startPolling(abha, reqId, pubKey) {
    let hasAccess = false;
    const interval = setInterval(async () => {
        try {
            const res = await fetch(`${BACKEND_URL}/api/consent/status/${abha}/${reqId}`);
            const data = await res.json();
            
            if (data.status === 'GRANTED' && !hasAccess) {
                debugLog(`Patient Approved ${reqId}!`);
                hasAccess = true;
                onApproval(abha, reqId, pubKey, data.encryptedBundle);
                // Continue polling to detect revocation
            } else if (data.status === 'REVOKED') {
                debugLog(`Consent REVOKED by Patient for ${reqId}`, true);
                clearInterval(interval);
                onRevocation(reqId);
            } else if (data.status === 'DENIED' && !hasAccess) {
                debugLog(`Patient Denied ${reqId}`, true);
                clearInterval(interval);
                onDenial(reqId);
            }
        } catch (e) {
            console.warn("Polling retry...");
        }
    }, 2000);
}

function onApproval(abha, reqId, pubKey, encryptedBundle) {
    const status = document.getElementById('status-' + reqId);
    status.className = 'status-tag status-granted';
    status.innerText = 'GRANTED';
    
    const btn = document.getElementById('btn-' + reqId);
    btn.style.display = 'block';
    btn.onclick = () => viewData(abha, pubKey, reqId, encryptedBundle);
    
    showToast("Access Granted!", "success");
}

function onRevocation(reqId) {
    const status = document.getElementById('status-' + reqId);
    if (status) {
        status.className = 'status-tag';
        status.style.background = '#000000';
        status.style.color = '#FFFFFF';
        status.innerText = 'REVOKED';
    }
    
    // 1. Wipe UI
    const viewer = document.getElementById('data-viewer');
    const wasActive = viewer.classList.contains('active');
    viewer.classList.remove('active');
    document.getElementById('medical-summary').innerHTML = ""; // Wipe content
    
    if (wasActive) {
        // Show a persistent critical alert if they were looking at data
        showRevocationModal(reqId);
    }
    
    // 2. Wipe memory
    window.lastDecryptedData = null; // Ensure no lingering objects
    
    const btn = document.getElementById('btn-' + reqId);
    if (btn) btn.style.display = 'none';
    
    debugLog(`CRITICAL: ACCESS REVOKED. All session data wiped for ${reqId}`, true);
    showToast("Access Lost: Patient Revoked Consent", "error");
    
    setTimeout(() => {
        const item = document.getElementById(`item-${reqId}`);
        if (item) item.style.opacity = '0.5';
    }, 2000);
}

function onDenial(reqId) {
    const status = document.getElementById('status-' + reqId);
    status.className = 'status-tag';
    status.style.background = '#FDE8E8';
    status.style.color = 'var(--danger)';
    status.innerText = 'DENIED';
    showToast("Access Denied", "error");
}

// ─── DECRYPTION & VIEWING ────────────────────────────────────────────────────

async function viewData(abha, patientPubKeyB64, reqId, encryptedBundle) {
    debugLog(`Starting Decryption for ${reqId}...`);
    showToast("Decrypting secure bundle...");
    
    try {
        if (!encryptedBundle || !encryptedBundle.entries || encryptedBundle.entries.length === 0) {
            throw new Error("No encrypted bundle received from backend.");
        }

        // 1. Derive ECDH Shared Secret
        // Use the actual key provided in the bundle (ABDM M3 spec), fallback to QR key
        let activePatientPubKey = patientPubKeyB64;
        if (encryptedBundle.keyMaterial && encryptedBundle.keyMaterial.dhPublicKey) {
            activePatientPubKey = encryptedBundle.keyMaterial.dhPublicKey.keyValue;
            debugLog("Using dynamic data-transfer key from bundle.");
        }

        const patientPubKey = CryptoUtils.fromBase64(activePatientPubKey);
        const rawSharedSecret = CryptoUtils.deriveSharedSecret(doctorKeyPair.privateKey, patientPubKey);

        // 2. Derive Session Key using HKDF (Matching Flutter side)
        const sessionKey = await CryptoUtils.deriveSessionKey(rawSharedSecret);

        // 3. Extract the actual payload from the ABDM-compliant envelope
        const contentB64 = encryptedBundle.entries[0].content;
        const nonceB64 = encryptedBundle.keyMaterial.nonce;

        // 4. Decrypt using the session key
        const decrypted = await CryptoUtils.decryptData(
            contentB64, 
            sessionKey, 
            nonceB64
        );
        
        debugLog("Decryption Success. Rendering...");
        renderData(JSON.parse(decrypted));
        document.getElementById('data-viewer').classList.add('active');

    } catch (e) {
        debugLog(`Security Error: ${e.message}`, true);
        showToast("Decryption failed!", "error");
    }
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function renderData(data) {
    const p = data.patient || {};
    const c = data.clinical || {};
    const e = data.emergency || {};
    
    // Set header
    const name = p.name || 'Unknown Patient';
    document.getElementById('viewer-name').innerText = name;
    document.getElementById('viewer-abha').innerText = "ABHA: " + (p.abhaAddress || p.abhaNumber || 'N/A');
    document.getElementById('viewer-avatar').innerText = name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
    document.getElementById('print-date').innerText = new Date().toLocaleDateString('en-IN', { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    
    // Store for printing
    window.lastDecryptedData = data;

    const summary = document.getElementById('medical-summary');
    
    // ─── PATIENT PROFILE ────────────────────────────────────
    let profileHTML = `
        <div class="summary-card">
            <h4><i class="fa-solid fa-user"></i> Patient Profile</h4>
            <div class="summary-item">Name <span>${p.name || 'N/A'}</span></div>
            <div class="summary-item">Age <span>${p.age || 'N/A'}</span></div>
            <div class="summary-item">Gender <span>${p.gender || 'N/A'}</span></div>
            <div class="summary-item">Blood Group <span style="color:var(--danger);font-weight:700">${p.bloodGroup || 'N/A'}</span></div>
            <div class="summary-item">Address <span>${p.address || 'N/A'}</span></div>
        </div>
    `;

    // ─── CRITICAL ALERTS ────────────────────────────────────
    const allergiesHTML = (c.allergies || []).map(a => `<span class="allergy-pill"><i class="fa-solid fa-triangle-exclamation" style="font-size:10px;margin-right:4px"></i>${a}</span>`).join('');
    const conditionsHTML = (c.conditions || []).map(cond => `<span class="condition-pill">${cond}</span>`).join('');
    
    let alertsHTML = `
        <div class="summary-card">
            <h4><i class="fa-solid fa-triangle-exclamation"></i> Critical Alerts</h4>
            <div style="margin-bottom:12px">
                <div style="font-size:11px;font-weight:700;color:var(--danger);margin-bottom:6px;text-transform:uppercase">Allergies</div>
                <div>${allergiesHTML || '<span style="color:var(--text-muted);font-size:13px">None reported</span>'}</div>
            </div>
            <div>
                <div style="font-size:11px;font-weight:700;color:var(--warning);margin-bottom:6px;text-transform:uppercase">Conditions</div>
                <div>${conditionsHTML || '<span style="color:var(--text-muted);font-size:13px">None reported</span>'}</div>
            </div>
        </div>
    `;

    // ─── MEDICATIONS ────────────────────────────────────────
    let medsHTML = '';
    const meds = c.activeMedications || [];
    if (meds.length > 0) {
        medsHTML = meds.map(m => {
            if (typeof m === 'object') {
                return `<div class="med-row">
                    <div>
                        <div class="med-name">${m.name || 'Unknown'}</div>
                        <div class="med-detail">${m.frequency || m.freq || ''} ${m['for'] ? '· For ' + m['for'] : ''}</div>
                    </div>
                    <div class="med-dosage">${m.dosage || ''}</div>
                </div>`;
            }
            return `<div class="med-row"><div class="med-name">${m}</div></div>`;
        }).join('');
    } else {
        medsHTML = '<span style="color:var(--text-muted);font-size:13px">No active medications</span>';
    }

    let medsCardHTML = `
        <div class="summary-card">
            <h4><i class="fa-solid fa-pills"></i> Active Medications</h4>
            ${medsHTML}
        </div>
    `;

    // ─── VITALS ─────────────────────────────────────────────
    let vitalsHTML = '';
    const vitals = c.latestVitals || {};
    const vitalKeys = Object.keys(vitals);
    if (vitalKeys.length > 0) {
        vitalsHTML = vitalKeys.map(key => {
            let icon = 'fa-heart-pulse';
            if (key.toLowerCase().includes('glucose') || key.toLowerCase().includes('hba1c')) icon = 'fa-droplet';
            if (key.toLowerCase().includes('cholesterol') || key.toLowerCase().includes('ldl') || key.toLowerCase().includes('hdl')) icon = 'fa-vial';
            if (key.toLowerCase().includes('bmi') || key.toLowerCase().includes('weight') || key.toLowerCase().includes('height')) icon = 'fa-weight-scale';
            if (key.toLowerCase().includes('tsh')) icon = 'fa-flask';
            return `<div class="summary-item"><span style="color:var(--text-main);font-weight:600"><i class="fa-solid ${icon}" style="color:var(--primary);margin-right:6px;font-size:11px"></i>${key}</span> <span>${vitals[key]}</span></div>`;
        }).join('');
    } else {
        vitalsHTML = '<span style="color:var(--text-muted);font-size:13px">No vitals available</span>';
    }

    let vitalsCardHTML = `
        <div class="summary-card">
            <h4><i class="fa-solid fa-heart-pulse"></i> Latest Vitals</h4>
            ${vitalsHTML}
        </div>
    `;

    // ─── MEDICAL HISTORY (TIMELINE) ─────────────────────────
    let historyHTML = '';
    const history = c.medicalHistory || [];
    if (history.length > 0) {
        historyHTML = history.map(h => {
            const cat = h.category || 'Reports';
            return `<div class="history-item">
                <div class="history-date">${h.date || ''}</div>
                <div style="flex:1">
                    <div class="history-event">${h.event || ''}</div>
                    <div class="history-doctor">${h.doctor || ''}</div>
                </div>
                <span class="history-badge ${cat}">${cat}</span>
            </div>`;
        }).join('');
    }

    let historyCardHTML = history.length > 0 ? `
        <div class="summary-card full-width">
            <h4><i class="fa-solid fa-clock-rotate-left"></i> Medical History</h4>
            ${historyHTML}
        </div>
    ` : '';

    // ─── EMERGENCY ──────────────────────────────────────────
    let emergencyHTML = '';
    if (e.contact || e.insurance) {
        emergencyHTML = `
            <div class="summary-card full-width">
                <h4><i class="fa-solid fa-phone"></i> Emergency Information</h4>
                ${e.contact ? `<div class="summary-item">Emergency Contact <span>${e.contact}</span></div>` : ''}
                ${e.insurance ? `<div class="summary-item">Insurance ID <span style="font-family:'JetBrains Mono',monospace;font-size:12px">${e.insurance}</span></div>` : ''}
            </div>
        `;
    }

    // Assemble the full dashboard
    summary.innerHTML = profileHTML + alertsHTML + medsCardHTML + vitalsCardHTML + historyCardHTML + emergencyHTML;

    // ─── WIRE PRINT BUTTON ──────────────────────────────────
    const printBtn = document.getElementById('btn-print');
    if (printBtn) {
        printBtn.onclick = () => {
            window.print();
        };
    }

    // ─── WIRE CLOSE SESSION ─────────────────────────────────
    const revokeBtn = document.getElementById('revoke-btn');
    if (revokeBtn) {
        revokeBtn.onclick = () => {
            document.getElementById('data-viewer').classList.remove('active');
            document.getElementById('medical-summary').innerHTML = '';
            window.lastDecryptedData = null;
            if (window._expiryInterval) clearInterval(window._expiryInterval);
            debugLog("Session closed by doctor. Data wiped.");
            showToast("Session closed", "info");
        };
    }

    // ─── START 30-MIN EXPIRY TIMER ──────────────────────────
    let remaining = 30 * 60; // 30 minutes in seconds
    if (window._expiryInterval) clearInterval(window._expiryInterval);
    
    const timerEl = document.getElementById('expiry-timer');
    window._expiryInterval = setInterval(() => {
        remaining--;
        const mins = Math.floor(remaining / 60).toString().padStart(2, '0');
        const secs = (remaining % 60).toString().padStart(2, '0');
        if (timerEl) timerEl.innerText = `${mins}:${secs}`;
        
        if (remaining <= 0) {
            clearInterval(window._expiryInterval);
            document.getElementById('data-viewer').classList.remove('active');
            document.getElementById('medical-summary').innerHTML = '';
            window.lastDecryptedData = null;
            debugLog("Session expired. All data auto-wiped per ABDM guidelines.", true);
            showToast("Session expired — data wiped", "error");
        }
    }, 1000);
}

function showRevocationModal(reqId) {
    const modal = document.createElement('div');
    modal.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.92);z-index:9999;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#FF4B4B;text-align:center;padding:40px;backdrop-filter:blur(12px)';
    modal.innerHTML = `
        <i class="fas fa-shield-alt" style="font-size:72px;margin-bottom:24px"></i>
        <h1 style="font-size:28px;font-weight:900;margin-bottom:12px">SESSION TERMINATED</h1>
        <p style="font-size:16px;color:#FFFFFF;max-width:480px;margin-bottom:32px;line-height:1.6">
            Patient has revoked access to their health records. All data has been purged from this session in accordance with ABDM Privacy Guidelines.
        </p>
        <button onclick="location.reload()" style="background:#FF4B4B;color:white;border:none;padding:14px 32px;border-radius:12px;font-weight:800;cursor:pointer;font-size:14px;font-family:'Outfit',sans-serif">
            RETURN TO DASHBOARD
        </button>
    `;
    document.body.appendChild(modal);
}

function showToast(msg, type = "info") {
    const toast = document.getElementById('toast');
    if (!toast) return;
    toast.innerText = msg;
    toast.style.background = type === "error" ? "var(--danger)" : type === "success" ? "var(--success)" : "var(--dark)";
    toast.classList.add('active');
    setTimeout(() => toast.classList.remove('active'), 3000);
}

