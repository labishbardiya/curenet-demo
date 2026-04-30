const axios = require('axios');
const GROQ_API_KEY = api

async function getModels() {
    try {
        const response = await axios.get('https://api.groq.com/openai/v1/models', {
            headers: { 'Authorization': `Bearer ${GROQ_API_KEY}` }
        });
        const models = response.data.data;
        console.log(models.map(m => m.id).join('\n'));
    } catch (e) {
        console.error(e.message);
    }
}
getModels();
