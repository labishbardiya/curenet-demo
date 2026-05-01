const axios = require('axios');
const fs = require('fs');
require('dotenv').config();

const GROQ_API_KEY = process.env.GROQ_API_KEY;
const NVIDIA_API_KEY = process.env.NVIDIA_API_KEY;

/**
 * ═══════════════════════════════════════════════════════════════════
 *  Vision LLM Service — Multi-Provider with Automatic Failover
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Priority:
 *    1. Nvidia NIM Vision API (Primary)
 *    2. Groq Vision API (fallback)
 *    3. Hardcoded mock (demo fallback if both APIs fail)
 *
 *  Supports BOTH prescriptions and lab reports.
 */

const VISION_PROMPT = `You are a medical data extraction expert. Analyze this clinical document image carefully.
This could be a PRESCRIPTION or a LAB REPORT. Detect which type it is and extract ALL information.

Return ONLY valid JSON in this exact format:
{
  "patient_name": "full name or 'unclear'",
  "doctor_name": "full name with title or 'unclear'",
  "clinic": "clinic/hospital name or 'unclear'",
  "date": "YYYY-MM-DD format",
  "age": "e.g. 35Y or 'unclear'",
  "diagnosis": "Impression/Diagnosis text (e.g. Hypoglycemia)",
  "chief_complaint": "symptoms (e.g. Giddiness, restlessness)",
  "vitals": {
    "bp": "e.g. 110/70",
    "pulse": "e.g. 60bpm",
    "temperature": "e.g. 98.6F or null",
    "weight": "e.g. 70kg or null"
  },
  "investigations": "any tests advised or 'unclear'",
  "medications": [
    {
      "name": "exact medicine name (e.g. 5% Dextrose)",
      "dosage": "e.g. 1 unit",
      "frequency": "e.g. Stat or 1+0+1",
      "duration": "e.g. 2 weeks",
      "form": "Injection/Tablet/Powder",
      "route": "iv/oral/topical",
      "confidence": 0.9,
      "extraction_method": "vision_llm"
    }
  ],
  "lab_results": [],
  "follow_up": {
    "date": "YYYY-MM-DD or null",
    "advice": ["advice item 1", "advice item 2"]
  }
}

Rules:
- Capture EVERY SINGLE medication, supplement, or medical product mentioned. Look closely at sections starting with 'Adv:', 'Rx:', 'Treatment:', or bullet points.
- If a line contains a dosage or quantity (e.g., 'ORS 2 sachets', 'Protein powder 1 scoop'), it MUST be classified as a Medication in the 'medications' array, NOT as general advice.
- General advice should ONLY be lifestyle instructions (e.g., 'Adequate fluid intake', 'Bed rest').
- For Indian prescriptions, patterns like '1+0+1', '1-0-1', '0-1-0' indicate frequency. Put these EXACTLY as written in 'frequency'.
- If the medicine strength (like 500mg, 10ml) is written next to the name, put it in 'dosage' or keep it in the 'name'. Do NOT put frequency in the dosage field.
- Ensure the spelling of the medications exactly matches the image. Look closely at the handwriting.
- Extract Vitals like BP and Pulse from the 'O/E' (On Examination) section.
- Extract Diagnosis from the 'Imp:' or 'Impression:' section (e.g., 'hypoglycemic'). Do NOT miss this.
- Capture 'c/o' (Complaining of) symptoms into chief_complaint.
- If it's a PRESCRIPTION: populate medications[], leave lab_results as []
- If it's a LAB REPORT: populate lab_results[], leave medications as []
- Identify 'Stat' as a frequency (meaning immediately).
- Distinguish carefully between Medications (things to consume/inject) and Advice.
- Indian prescription frequency: morning+afternoon+night (e.g., 1+0+1)
- Common abbreviations: Tab=Tablet, Cap=Capsule, Syp=Syrup, Inj=Injection, ORS=Oral Rehydration Salts
- Do NOT hallucinate — if truly unreadable, mark as 'unclear'
- Return ONLY the JSON, no markdown formatting. Ensure ALL medications on the page are included.`;


/**
 * PRIMARY: Groq Vision API (Llama 3.2 90B Vision)
 */
async function extractWithGroq(imagePath) {
    if (!GROQ_API_KEY) {
        console.warn('[VisionLLM] Groq API Key missing. Skipping Groq...');
        return null;
    }

    try {
        const imageContent = fs.readFileSync(imagePath).toString('base64');
        const mimeType = imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg';

        console.log('[VisionLLM] Requesting Groq (Llama 4 Scout) extraction...');

        const response = await axios.post(
            'https://api.groq.com/openai/v1/chat/completions',
            {
                model: "meta-llama/llama-4-scout-17b-16e-instruct",
                messages: [
                    {
                        role: "user",
                        content: [
                            { type: "text", text: VISION_PROMPT + "\nIMPORTANT: Return ONLY valid JSON. No conversational filler. No markdown formatting." },
                            { type: "image_url", image_url: { url: `data:${mimeType};base64,${imageContent}` } }
                        ]
                    }
                ],
                max_tokens: 1024,
                temperature: 0.1,
                response_format: { type: "json_object" }
            },
            {
                headers: {
                    "Authorization": `Bearer ${GROQ_API_KEY}`,
                    "Content-Type": "application/json"
                },
                timeout: 60000
            }
        );

        const textResult = response.data?.choices?.[0]?.message?.content;
        if (!textResult) return null;

        const jsonMatch = textResult.match(/\{[\s\S]*\}/);
        const cleanJsonStr = jsonMatch ? jsonMatch[0] : textResult;
        const structuredData = JSON.parse(cleanJsonStr);

        // Tag medications with extraction method
        if (structuredData.medications) {
            structuredData.medications = structuredData.medications.map(med => ({
                ...med,
                confidence: med.confidence || 0.95,
                extraction_method: 'groq_vision'
            }));
        }

        console.log(`[VisionLLM] Groq returned ${structuredData.medications?.length || 0} medication(s), ${structuredData.lab_results?.length || 0} lab result(s)`);

        return {
            ...structuredData,
            source: 'Groq_Vision',
            confidence: 0.95
        };
    } catch (err) {
        console.error('[VisionLLM] Groq API failed:', err.response?.data?.error?.message || err.message);
        return null;
    }
}


/**
 * FALLBACK: Nvidia NIM Vision API (Llama 3.2 90B Vision)
 */
async function extractWithNvidia(imagePath) {
    if (!NVIDIA_API_KEY || NVIDIA_API_KEY === 'YOUR_NVIDIA_API_KEY_HERE') {
        console.warn('[VisionLLM] Nvidia API Key missing. Skipping Nvidia...');
        return null;
    }

    try {
        const imageContent = fs.readFileSync(imagePath).toString('base64');
        const mimeType = imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg';

        console.log('[VisionLLM] Requesting Nvidia NIM (Llama 3.2 90B Vision) extraction...');

        const response = await axios.post(
            'https://integrate.api.nvidia.com/v1/chat/completions',
            {
                model: "meta/llama-3.2-90b-vision-instruct",
                response_format: { type: "json_object" },
                messages: [
                    {
                        role: "user",
                        content: [
                            { type: "text", text: VISION_PROMPT + "\nIMPORTANT: Return ONLY valid JSON. No conversational filler. No markdown formatting." },
                            { type: "image_url", image_url: { url: `data:${mimeType};base64,${imageContent}` } }
                        ]
                    }
                ],
                max_tokens: 1024,
                temperature: 0.1
            },
            {
                headers: {
                    "Authorization": `Bearer ${NVIDIA_API_KEY}`,
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                },
                timeout: 120000
            }
        );

        const textResult = response.data?.choices?.[0]?.message?.content;
        if (!textResult) return null;

        const jsonMatch = textResult.match(/\{[\s\S]*\}/);
        const cleanJsonStr = jsonMatch ? jsonMatch[0] : textResult;
        const structuredData = JSON.parse(cleanJsonStr);

        if (structuredData.medications) {
            structuredData.medications = structuredData.medications.map(med => ({
                ...med,
                confidence: med.confidence || 0.95,
                extraction_method: 'nvidia_vision'
            }));
        }

        console.log(`[VisionLLM] Nvidia NIM returned ${structuredData.medications?.length || 0} medication(s), ${structuredData.lab_results?.length || 0} lab result(s)`);

        return {
            ...structuredData,
            source: 'VisionLLM',
            confidence: 0.95
        };
    } catch (err) {
        console.error('[VisionLLM] Nvidia API failed:', err.response?.data || err.message);
        return null;
    }
}


/**
 * LAST RESORT: Mock data for demo purposes
 */
function getMockData() {
    console.warn('[VisionLLM] All APIs failed. Returning mock data for demo...');
    return {
        patient_name: "Vivek S.",
        doctor_name: "Dr. (unclear signature)",
        date: "2022-12-22",
        clinic: "Adichunchanagiri Institute of Medical Sciences Hospital & Research Centre",
        chief_complaint: "c/o giddiness, restlessness. Imp: hypoglycemic (RBS - 50mg/dL). O/E BP - 110/70, PR - 60bpm",
        investigations: "",
        medications: [
            {
                name: "5% Dextrose",
                dosage: "1 unit",
                frequency: "stat",
                duration: "stat",
                route: "iv",
                form: "Injection",
                confidence: 0.95,
                extraction_method: "mock_demo"
            },
            {
                name: "ORS",
                dosage: "2 sachets",
                frequency: "as directed",
                duration: "as directed",
                route: "oral",
                form: "Powder",
                confidence: 0.95,
                extraction_method: "mock_demo"
            }
        ],
        lab_results: [],
        follow_up: {
            date: null,
            advice: [
                "Adequate fluid intake"
            ]
        },
        source: 'VisionLLM_Mock',
        confidence: 0.95
    };
}


/**
 * Main entry point — tries Groq → Nvidia → Mock
 */
exports.extractWithVisionLlm = async (imagePath) => {
    // 1. Try Groq Vision (Primary - free tier, fast)
    const groqResult = await extractWithGroq(imagePath);
    if (groqResult) return groqResult;

    // 2. Try Nvidia NIM Vision (fallback - high accuracy)
    const nvidiaResult = await extractWithNvidia(imagePath);
    if (nvidiaResult) return nvidiaResult;

    // 3. Mock fallback (demo)
    return getMockData();
};
