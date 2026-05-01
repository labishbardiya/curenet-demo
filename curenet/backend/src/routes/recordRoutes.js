const express = require('express');
const router = express.Router();
const Record = require('../models/recordModel');

/**
 * @route GET /api/records/all
 * @desc Fetch all clinical records (completed jobs) for RAG context and UI display.
 */
router.get('/all', async (req, res) => {
    try {
        const records = await Record.find({ status: 'completed' }).sort({ createdAt: -1 });
        res.status(200).json({
            status: 'success',
            results: records.length,
            data: records
        });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch records: ' + err.message });
    }
});

module.exports = router;
