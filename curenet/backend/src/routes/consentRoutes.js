const express = require('express');
const router = express.Router();

// In-memory store for active consent requests (Simulating HIE-CM)
// Key: patientAbha, Value: array of requests
const consentRequests = new Map();

/**
 * 1. Doctor (HIU) initiates a consent request after scanning QR
 * POST /api/consent/init
 */
router.post('/init', (req, res) => {
    const { abha, doctorName, doctorId, sessionId, patientPubKey, doctorPubKey } = req.body;
    
    if (!abha || !sessionId) {
        return res.status(400).json({ error: 'Missing ABHA or Session ID' });
    }

    const request = {
        requestId: 'REQ-' + Math.random().toString(36).substr(2, 9).toUpperCase(),
        abha,
        doctorName: doctorName || 'Dr. Suresh Kumar',
        doctorId: doctorId || 'REG1001',
        sessionId,
        patientPubKey,
        doctorPubKey,
        timestamp: new Date().toISOString(),
        status: 'PENDING'
    };

    if (!consentRequests.has(abha)) {
        consentRequests.set(abha, []);
    }
    consentRequests.get(abha).push(request);

    console.log(`[Consent] Request initiated for ${abha} by ${request.doctorName}`);
    res.json({ success: true, request });
});

/**
 * 2. Patient App polls for new requests
 * GET /api/consent/poll/:abha
 */
router.get('/poll/:abha', (req, res) => {
    const { abha } = req.params;
    const allRequests = consentRequests.get(abha) || [];
    
    // Only return PENDING requests that haven't been answered yet
    const pendingRequests = allRequests.filter(r => r.status === 'PENDING');
    
    res.json({ requests: pendingRequests });
});

/**
 * 3. Patient App responds to a request (Approve/Deny)
 * POST /api/consent/respond
 */
router.post('/respond', (req, res) => {
    const { abha, requestId, status, encryptedBundle } = req.body;
    
    const allRequests = consentRequests.get(abha);
    if (!allRequests) return res.status(404).json({ error: 'No requests found' });

    const reqIndex = allRequests.findIndex(r => r.requestId === requestId);
    if (reqIndex === -1) return res.status(404).json({ error: 'Request not found' });

    allRequests[reqIndex].status = status; // GRANTED or DENIED
    if (encryptedBundle) {
        allRequests[reqIndex].encryptedBundle = encryptedBundle;
    }
    console.log(`[Consent] Patient ${abha} responded ${status} to ${requestId}`);
    
    res.json({ success: true });
});

/**
 * 4. Doctor App polls for approval status
 * GET /api/consent/status/:abha/:requestId
 */
router.get('/status/:abha/:requestId', (req, res) => {
    const { abha, requestId } = req.params;
    const allRequests = consentRequests.get(abha) || [];
    const request = allRequests.find(r => r.requestId === requestId);
    
    if (!request) return res.status(404).json({ error: 'Request not found' });
    
    res.json({ 
        status: request.status,
        encryptedBundle: request.encryptedBundle
    });
});

module.exports = router;
