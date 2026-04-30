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
    // The ABDM referenceNumber. Fully available once processing is successfully completed.
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
    // Required fields to map seamlessly to an ABDM CareContext payload later
    abdmContext: {
        isReadyForLink: { type: Boolean, default: false },
        hiType: { type: String, default: 'DiagnosticReport' }, 
        displayString: { type: String }
    },
    warnings: [{
        type: String
    }],
    filePath: {
        type: String // Storing local file path if we need to retrieve it during background processing
    },
    fhirBundle: {
        type: Object // Will store the fully compliant ABDM FHIR Bundle JSON
    },
    uiData: {
        type: Object // UI-optimized structured output { document_type, summary, medications, lab_results, documents }
    }
}, { timestamps: true });

// module.exports = mongoose.model('Record', RecordSchema);

const memoryDb = [];

class MockRecord {
    constructor(data) {
        Object.assign(this, data);
        if (!this.status) this.status = 'pending';
    }

    async save() {
        const existingIdx = memoryDb.findIndex(r => r.jobId === this.jobId);
        if (existingIdx >= 0) {
            memoryDb[existingIdx] = this;
        } else {
            memoryDb.push(this);
        }
        return this;
    }

    static async findOne(query) {
        return memoryDb.find(r => Object.keys(query).every(k => r[k] === query[k])) || null;
    }

    static async findOneAndUpdate(query, update, options) {
        let doc = memoryDb.find(r => Object.keys(query).every(k => r[k] === query[k]));
        if (doc) {
            Object.assign(doc, update);
            return doc;
        }
        return null;
    }
}

module.exports = MockRecord;
