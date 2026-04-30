const { extractWithVisionLlm } = require('./src/services/ocr/visionLlmService');
const path = require('path');

async function test() {
    console.log("Testing Groq Vision API...");
    const imagePath = path.join(__dirname, 'uploads', '1777403976694-613120065.jpg');
    try {
        const result = await extractWithVisionLlm(imagePath);
        console.log("RESULT:", JSON.stringify(result, null, 2));
    } catch (e) {
        console.error("FAILED:", e);
    }
}

test();
