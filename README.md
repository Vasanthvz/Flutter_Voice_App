# Whisper Flutter App with Translation

A comprehensive application that provides real-time speech-to-text transcription and translation to Indian languages using OpenAI's Whisper model and AI4Bharat's translation model.

## Project Overview

This project consists of two main components:
1. A Python server handling transcription and translation
2. A Flutter client application providing the user interface

## Project Structure

```
whisper_flutter_app/
├── server/                    # Python server
│   ├── main.py               # Main server implementation
│   ├── models/               # Translation models
│   │   └── en-indic/        # English to Indic translation model
│   ├── indicTrans-main/     # Core translation library
│   └── requirements.txt      # Python dependencies
├── lib/                      # Flutter application
│   ├── main.dart            # Main app entry point
│   ├── models/              # Data models
│   ├── screens/             # UI screens
│   └── services/            # API services
├── flutter_backup/          # Backup of Flutter code
├── README.md                # Main documentation
└── README_FLUTTER.md        # Flutter-specific documentation
```

## Server Setup

1. Create a Python virtual environment:
   ```bash
   python -m venv server_env
   source server_env/bin/activate  # On Windows: server_env\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   cd server
   pip install -r requirements.txt
   ```

3. Run the server:
   ```bash
   python main.py
   ```

The server will run on `http://localhost:8001`

## Flutter Setup

See [README_FLUTTER.md](README_FLUTTER.md) for detailed Flutter setup instructions.

## Features

### Server
- Real-time speech-to-text transcription using Whisper
- Multi-language translation using AI4Bharat model
- Offline mode support
- Translation caching
- Optimized model loading

### Flutter App
- Modern Material Design UI
- Real-time speech recognition
- Multi-language translation interface
- Offline mode indicator
- Cross-platform support

## Supported Languages

### Transcription
- English (en)
- Hindi (hi)
- Tamil (ta)
- Malayalam (ml)
- Bengali (bn)
- Marathi (mr)
- Urdu (ur)
- Nepali (ne)
- Sinhala (si)

### Translation
- English ↔ All supported Indian languages
- Hindi ↔ All supported Indian languages
- Tamil ↔ All supported Indian languages
- Malayalam ↔ All supported Indian languages
- Bengali ↔ All supported Indian languages
- Marathi ↔ All supported Indian languages
- Urdu ↔ All supported Indian languages
- Nepali ↔ All supported Indian languages
- Sinhala ↔ All supported Indian languages

## Dependencies

### Server Dependencies
- Python 3.8+
- FastAPI : 0.115.11
- Whisper : 
- Transformers : 4.36.0
- Torch : 2.0.1
- FFmpeg: 
libavutil      59. 39.100 / 59. 39.100
libavcodec     61. 19.101 / 61. 19.101
libavformat    61.  7.100 / 61.  7.100
libavdevice    61.  3.100 / 61.  3.100
libavfilter    10.  4.100 / 10.  4.100
libswscale      8.  3.100 /  8.  3.100
libswresample   5.  3.100 /  5.  3.100
libpostproc    58.  3.100 / 58.  3.100

### Flutter Dependencies
- Flutter SDK: >=3.2.0 <4.0.0
- Dart SDK: >=3.2.0 <4.0.0
- record: ^4.4.4
- path_provider: ^2.1.2
- permission_handler: ^11.2.0
- http: ^1.2.0

## Development

1. Start the Python server first
2. Run the Flutter app
3. Test both transcription and translation features
4. Monitor server logs for any issues

## Testing

### Server Testing
```bash
cd server
python -m pytest
```

### Flutter Testing
```bash
flutter test
```

## Performance Optimization

### Server
- Translation results are cached
- Models are loaded once and reused
- Audio processing is optimized
- Batch translation support

### Flutter
- UI updates are debounced
- Network requests are optimized
- Audio processing is efficient
- State management is optimized

## Error Handling

### Server
- Model loading errors
- Translation errors
- Audio processing errors
- Network errors

### Flutter
- Network connectivity issues
- Permission denials
- Invalid language selections
- Audio recording failures

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.


## run app
cd server && conda activate indictrans_py39 && python main.py

cd server && conda activate indictrans_py39 && python -m uvicorn main:app --reload --port 8001



## Run Emulator
flutter emulators --launch Medium_Phone_API_35

## Run flutter App in Emulator
flutter run -d emulator-5554


10.0.2.2:8001






## Important!
Every dependencies are already installed don't want to reinstall it or change the server code structure and the conda dependencies are already satisfied there is no need of creating again a new environment for conda it can be activated by "conda activate indictrans_py39" it should be activated with the server.

## Perform translation in command prompt
English to hindi
curl -X POST "http://localhost:8001/translate/" \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, how are you doing today?", "source_lang": "eng_Latn", "target_lang": "hin_Deva"}'

Tamil to malayalam:
curl -X POST "http://localhost:8001/translate/" \
  -H "Content-Type: application/json" \
  -d '{"text": "வணக்கம், நீங்கள் எப்படி இருக்கிறீர்கள்?", "source_lang": "tam_Taml", "target_lang": "mal_Mlym"}'

English to bengali:
curl -X POST "http://localhost:8001/translate/" \
  -H "Content-Type: application/json" \
  -d '{"text": "The weather is nice today.", "source_lang": "eng_Latn", "target_lang": "ben_Beng"}'

Marathi to English:
curl -X POST "http://localhost:8001/translate/" \
  -H "Content-Type: application/json" \
  -d '{"text": "आज हवामान छान आहे.", "source_lang": "mar_Deva", "target_lang": "eng_Latn"}'

English to Multiple langauges:
curl -X POST "http://localhost:8001/translate_batch/" \
  -H "Content-Type: application/json" \
  -d '{"texts": ["Hello", "Thank you", "Goodbye"], "source_lang": "eng_Latn", "target_lang": "hin_Deva"}'

English to Tamil(Long para)
curl -X POST "http://localhost:8001/translate/" \
  -H "Content-Type: application/json" \
  -d '{"text": "Machine translation is the task where the goal is to convert text from one language to another automatically. It is an important task in Natural Language Processing.", "source_lang": "eng_Latn", "target_lang": "tam_Taml"}'


English to Hindi:
curl -X POST "http://localhost:8001/translate/" \
  -H "Content-Type: application/json" \
  -d '{"text": "Flutter is an open source framework by Google for building beautiful, natively compiled, multi-platform applications from a single codebase.", "source_lang": "eng_Latn", "target_lang": "hin_Deva"}'


Urdu to English:
curl -X POST "http://localhost:8001/translate/" \
  -H "Content-Type: application/json" \
  -d '{"text": "آپ کیسے ہیں؟", "source_lang": "urd_Arab", "target_lang": "eng_Latn"}'



#Text to speech with translation content
curl -X POST "http://localhost:8001/translate/" -H "Content-Type: application/json" \
  -d '{"text": "Welcome to multilingual assistant", "source_lang": "eng_Latn", "target_lang": "hin_Deva"}' | \
  jq -r '.translated_text' | \
  xargs -I {} curl -X POST "http://localhost:8001/tts/" -H "Content-Type: application/json" \
  -d '{"text": "{}", "language": "hi", "slow": false}' --output translated_speech.mp3



## Backup main.py code
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import whisper
import tempfile
import os
import subprocess
import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
from pathlib import Path
from functools import lru_cache
import time

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load Whisper model
model = whisper.load_model("small")

# Define model paths
MODEL_DIR = Path("models")
MODEL_DIR.mkdir(exist_ok=True)

en_indic_dir = MODEL_DIR / "en-indic"

# Add translation cache
translation_cache = {}

# Add offline mode detection
def is_offline():
    """Always return True to force offline mode for testing"""
    return True

# Modify model loading section
print("Checking internet connection...")
OFFLINE_MODE = is_offline()
print(f"Running in {'OFFLINE' if OFFLINE_MODE else 'ONLINE'} mode")

# Update model loading to be more robust in offline mode
def load_model_offline(model_dir: Path, model_name: str):
    """Load model from local directory only in offline mode"""
    if model_dir.exists():
        try:
            print(f"Loading model from local directory: {model_dir}")
            tokenizer = AutoTokenizer.from_pretrained(str(model_dir), local_files_only=True)
            model = AutoModelForSeq2SeqLM.from_pretrained(str(model_dir), local_files_only=True)
            print(f"Successfully loaded model from {model_dir}")
            return tokenizer, model
        except Exception as e:
            print(f"Error loading local model from {model_dir}: {e}")
            return None, None
    else:
        print(f"Model directory {model_dir} does not exist")
        return None, None

# Model configurations
models = {
    "en-indic": {
        "name": "ai4bharat/IndicTrans-v2",  # Using AI4Bharat model for all translations
        "local_dir": en_indic_dir
    }
}

print("\nLoading translation models...")
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

# Initialize model variables
en_indic_model = None
en_indic_tokenizer = None

# Load AI4Bharat model
print("Loading AI4Bharat model...")
en_indic_tokenizer, en_indic_model = load_model_offline(
    en_indic_dir,
    "ai4bharat/IndicTrans-v2"
)

if en_indic_model:
    en_indic_model = en_indic_model.to(device)
    en_indic_model.eval()
    print("Successfully loaded AI4Bharat model")
else:
    print("Failed to load AI4Bharat model")

# Language code mappings for AI4Bharat model
INDIC_LANGUAGE_CODES = {
    "hin": "hi",  # Hindi
    "tam": "ta",  # Tamil
    "mal": "ml",  # Malayalam
    "ben": "bn",  # Bengali
    "mar": "mr",  # Marathi
    "urd": "ur",  # Urdu
    "nep": "ne",  # Nepali
    "sin": "si",  # Sinhala
    "eng": "en"   # English
}

def get_indic_language_code(lang_code: str) -> str:
    """Convert language code to AI4Bharat format."""
    base_code = lang_code.split("_")[0].lower()
    if base_code in INDIC_LANGUAGE_CODES:
        return INDIC_LANGUAGE_CODES[base_code]
    return "en"  # Default to English if unknown

# Data models for translation
class TranslationRequest(BaseModel):
    text: str
    source_lang: str
    target_lang: str

class TranslationResponse(BaseModel):
    translated_text: str
    error: Optional[str] = None

@lru_cache(maxsize=1000)
def cached_translate(text: str, source_lang: str, target_lang: str) -> str:
    """Cache translation results for faster repeated translations"""
    cache_key = f"{text}_{source_lang}_{target_lang}"
    if cache_key in translation_cache:
        return translation_cache[cache_key]
    return None

@app.post("/translate/")
async def translate_text(request: TranslationRequest):
    try:
        if not en_indic_model or not en_indic_tokenizer:
            raise HTTPException(status_code=500, detail="Translation model not available. Please ensure models are downloaded for offline use.")

        start_time = time.time()
        print(f"Input text: {request.text}")
        
        # Check cache first
        cached_result = cached_translate(request.text, request.source_lang, request.target_lang)
        if cached_result:
            print(f"Cache hit! Translation time: {time.time() - start_time:.2f}s")
            return TranslationResponse(translated_text=cached_result)

        source_lang = get_indic_language_code(request.source_lang)
        target_lang = get_indic_language_code(request.target_lang)
        
        print(f"Translating from {source_lang} to {target_lang} in {'offline' if OFFLINE_MODE else 'online'} mode")

        # Format input text (simplified format)
        input_text = request.text
        # Add period if the text doesn't end with sentence-ending punctuation
        if not input_text[-1] in ['.', '?', '!']:
            input_text = input_text + '.'
        print(f"Formatted input: {input_text}")
        
        # Tokenize with optimized settings
        inputs = en_indic_tokenizer(
            input_text, 
            return_tensors="pt", 
            padding=True, 
            truncation=True, 
            max_length=512
        ).to(device)
        
        # Generate translation with improved parameters
        with torch.no_grad():
            translated = en_indic_model.generate(
                **inputs,
                max_length=512,
                min_length=10,  # Add minimum length to ensure complete translations
                num_beams=5,
                length_penalty=1.5,  # Increased from 1.2 to encourage longer translations
                early_stopping=False,  # Changed to False to ensure complete translations
                do_sample=False,
                repetition_penalty=1.2,
                forced_bos_token_id=en_indic_tokenizer.lang_code_to_id[target_lang]
            )

        # Decode the translation
        output_text = en_indic_tokenizer.decode(translated[0], skip_special_tokens=True)
        print(f"Raw translation: {output_text}")
        
        # Clean up the output text
        output_text = output_text.replace(f">>{target_lang}<<", "").strip()
        output_text = output_text.replace(">> GG<", "").strip()
        output_text = output_text.replace('"', '').strip()
        output_text = output_text.replace("'", "").strip()
        output_text = output_text.replace(source_lang, "").strip()
        output_text = output_text.replace(target_lang, "").strip()
        
        # Cache the result
        translation_cache[f"{request.text}_{request.source_lang}_{request.target_lang}"] = output_text
        
        print(f"Translation completed in {time.time() - start_time:.2f}s (offline mode: {OFFLINE_MODE})")
        return TranslationResponse(translated_text=output_text)

    except Exception as e:
        print(f"Translation error in {'offline' if OFFLINE_MODE else 'online'} mode: {str(e)}")
        return TranslationResponse(translated_text="", error=str(e))

def convert_to_wav(input_file: str, output_file: str) -> bool:
    try:
        subprocess.run(['ffmpeg', '-i', input_file, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', output_file], check=True)
        return True
    except subprocess.CalledProcessError:
        return False

@app.post("/transcribe/realtime/")
async def transcribe_audio(file: UploadFile = File(...), language: str = "en"):
    try:
        # Create a temporary file to store the uploaded audio
        with tempfile.NamedTemporaryFile(delete=False, suffix='.webm') as temp_audio:
            temp_audio.write(await file.read())
            temp_audio_path = temp_audio.name

        # Create a temporary WAV file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_wav:
            temp_wav_path = temp_wav.name

        # Convert the audio to WAV format
        if not convert_to_wav(temp_audio_path, temp_wav_path):
            raise HTTPException(status_code=500, detail="Failed to convert audio format")

        # Transcribe the audio
        result = model.transcribe(temp_wav_path, language=language)

        # Clean up temporary files
        os.unlink(temp_audio_path)
        os.unlink(temp_wav_path)

        return {"text": result["text"]}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001) 










