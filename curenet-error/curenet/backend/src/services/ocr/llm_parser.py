import json
import sys
import os
from transformers import pipeline
import torch

# Configuration
MODEL_ID = "TinyLlama/TinyLlama-1.1B-Chat-v1.0" # Lightweight and fast local alternative
# MODEL_ID = "meta-llama/Meta-Llama-3-8B-Instruct" # Use this if resources allow

print(f"[LLMParser] Loading model {MODEL_ID}...")
try:
    # Use 4-bit quantization if possible for Llama-3, otherwise standard for TinyLlama
    pipe = pipeline(
        "text-generation", 
        model=MODEL_ID, 
        torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
        device_map="auto" if torch.cuda.is_available() else "cpu"
    )
except Exception as e:
    print(json.dumps({"error": f"Failed to load LLM: {str(e)}"}))
    sys.exit(1)

def parse_text(raw_text):
    prompt = f"""<|system|>
You are a medical data assistant. Convert the following OCR text from a prescription into a structured JSON format.
Focus on extracting: patient_name, doctor_name, date, and a list of medications with (name, dosage, frequency, duration).
If information is missing, use 'unclear'.
Output ONLY valid JSON.
<|user|>
OCR Text:
{raw_text}
<|assistant|>
"""
    
    outputs = pipe(prompt, max_new_tokens=512, do_sample=True, temperature=0.1, top_k=50, top_p=0.95)
    full_text = outputs[0]["generated_text"]
    
    # Extract JSON part
    try:
        json_start = full_text.find("{", full_text.find("<|assistant|>"))
        json_end = full_text.rfind("}") + 1
        json_str = full_text[json_start:json_end]
        return json.loads(json_str)
    except Exception as e:
        return {"error": "Failed to parse JSON from LLM output", "raw": full_text}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No text provided"}))
        sys.exit(1)
        
    raw_input = sys.argv[1]
    
    try:
        result = parse_text(raw_input)
        print("---RESULT_START---")
        print(json.dumps(result))
        print("---RESULT_END---")
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
