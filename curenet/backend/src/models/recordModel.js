const mongoose = require('mongoose');

const RecordSchema = new mongoose.Schema({
    jobId: {
        type: String,
        required: true,
        index: true
    },
    status: {
        type: String,
        enum: ['pending', 'processing', 'completed', 'failed'],
        default: 'pending'
    },
    recordId: {
        type: String
    },
    raw_text: {
        type: String
    },
    clean_text: {
        type: String
    },
    confidence_score: {
        type: Number
    },
    abdmContext: {
        isReadyForLink: { type: Boolean, default: false },
        hiType: { type: String, default: 'DiagnosticReport' }, 
        displayString: { type: String }
    },
    warnings: [{
        type: String
    }],
    filePath: {
        type: String
    },
    fhirBundle: {
        type: Object
    },
    uiData: {
        type: Object
    }
}, { timestamps: true });

module.exports = mongoose.model('Record', RecordSchema);
