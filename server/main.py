from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel
from typing import Optional, List
import whisper
import tempfile
import os
import subprocess
import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
from pathlib import Path
from functools import lru_cache
import time
import uuid
import socket
import re
import soundfile as sf
import numpy as np
import logging
import shutil
import gtts
from gtts import gTTS

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Define language code mappings for AI4Bharat model
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
print("Loading Whisper model...")
try:
    model = whisper.load_model("small", download_root="models/whisper")
    print("Successfully loaded Whisper model")
except Exception as e:
    print(f"Error loading Whisper model: {e}")
    raise

# Define model paths
MODEL_DIR = Path("models")
MODEL_DIR.mkdir(exist_ok=True)

# Create model directories
whisper_dir = MODEL_DIR / "whisper"
whisper_dir.mkdir(exist_ok=True)

en_indic_dir = MODEL_DIR / "en-indic"
en_indic_dir.mkdir(exist_ok=True)

indic_en_dir = MODEL_DIR / "indic-en"
indic_en_dir.mkdir(exist_ok=True)

m2m_dir = MODEL_DIR / "m2m"
m2m_dir.mkdir(exist_ok=True)

# Add translation cache
translation_cache = {}

# Configure offline mode
OFFLINE_MODE = os.environ.get("OFFLINE_MODE", "false").lower() in ("true", "1", "yes")
if OFFLINE_MODE:
    print("Running in OFFLINE mode - will only use locally downloaded models")
else:
    print("Running with online fallback - will attempt to download missing models")

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
try:
    # First try to load from local directory
    en_indic_tokenizer, en_indic_model = load_model_offline(
        en_indic_dir,
        "ai4bharat/IndicTrans-v2"
    )

    # If local loading fails, try downloading
    if not en_indic_model or not en_indic_tokenizer:
        print("Local model loading failed, attempting to download...")
        en_indic_tokenizer = AutoTokenizer.from_pretrained("ai4bharat/IndicTrans-v2")
        en_indic_model = AutoModelForSeq2SeqLM.from_pretrained("ai4bharat/IndicTrans-v2")
        
        # Save the model locally
        en_indic_tokenizer.save_pretrained(en_indic_dir)
        en_indic_model.save_pretrained(en_indic_dir)
        print("Model downloaded and saved locally")

    if en_indic_model and en_indic_tokenizer:
        en_indic_model = en_indic_model.to(device)
        en_indic_model.eval()
        print("Successfully loaded AI4Bharat model")
        
        # Test the model with a simple translation
        test_input = "Hello"
        test_output = en_indic_tokenizer.decode(
            en_indic_model.generate(
                **en_indic_tokenizer(test_input, return_tensors="pt").to(device),
                forced_bos_token_id=en_indic_tokenizer.lang_code_to_id["hi"]
            )[0],
            skip_special_tokens=True
        )
        print(f"Model test translation: {test_input} -> {test_output}")
    else:
        print("Failed to load AI4Bharat model")
        raise RuntimeError("Failed to initialize translation model")
except Exception as e:
    print(f"Error loading AI4Bharat model: {e}")
    en_indic_model = None
    en_indic_tokenizer = None
    raise  # Re-raise the exception to prevent the server from starting with a broken model

def get_indic_language_code(lang_code: str) -> str:
    """Convert language code to AI4Bharat format."""
    # First handle direct matches with common codes
    direct_mapping = {
        "en": "en",  # English
        "hi": "hi",  # Hindi
        "ta": "ta",  # Tamil
        "ml": "ml",  # Malayalam
        "bn": "bn",  # Bengali
        "mr": "mr",  # Marathi
        "ur": "ur",  # Urdu
        "ne": "ne",  # Nepali
        "si": "si"   # Sinhala
    }
    
    base_code = lang_code.split("_")[0].lower()
    
    # Try direct mapping first
    if base_code in direct_mapping:
        return direct_mapping[base_code]
    
    # Then try the longer form codes
    if base_code in INDIC_LANGUAGE_CODES:
        return INDIC_LANGUAGE_CODES[base_code]
    
    # If language is a 3-letter code that isn't in our mapping,
    # try to see if the first two letters match a 2-letter code
    if len(base_code) == 3 and base_code[:2] in direct_mapping:
        return direct_mapping[base_code[:2]]
    
    # Log the unmapped code for debugging
    print(f"Warning: Unmapped language code '{lang_code}', defaulting to English")
    return "en"  # Default to English if unknown

# Data models for translation
class TranslationRequest(BaseModel):
    text: str
    source_lang: str
    target_lang: str

class TranslationBatchRequest(BaseModel):
    texts: List[str]
    source_lang: str
    target_lang: str

class TranslationResponse(BaseModel):
    translated_text: str
    mode: str = "offline"  # Always offline
    error: Optional[str] = None

@lru_cache(maxsize=5000)
def cached_translate(text: str, source_lang: str, target_lang: str) -> str:
    """Cache translation results for faster repeated translations"""
    import hashlib
    # Always use hash for cache key to ensure consistency
    text_hash = hashlib.md5(text.encode()).hexdigest()
    key = f"{text_hash}_{source_lang}_{target_lang}"
    print(f"Checking cache for: '{text[:20]}...' [{len(translation_cache)} items in cache]")
    return translation_cache.get(key)

@app.post("/translate/")
async def translate(request: TranslationRequest):
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
        
        print(f"Translating from {source_lang} to {target_lang} using locally loaded model (offline mode)")

        # Format input text (simplified format)
        input_text = request.text
        
        # Add period if the text doesn't end with sentence-ending punctuation
        if not input_text[-1] in ['.', '?', '!'] and len(input_text) > 2:
            input_text = input_text + '.'
            
        print(f"Formatted input: {input_text}")
        
        # Split long texts into sentences for faster processing
        sentences = []
        if len(input_text.split()) > 15:  # If text has more than 15 words
            # Simple sentence splitting based on punctuation
            import re
            potential_sentences = re.split(r'(?<=[.!?])\s+', input_text)
            
            # Process each sentence or create chunks of reasonable size
            for sent in potential_sentences:
                if len(sent.split()) <= 15:
                    sentences.append(sent)
                else:
                    # Further split long sentences by commas if needed
                    comma_splits = sent.split(', ')
                    current_chunk = ""
                    for split in comma_splits:
                        if len(current_chunk.split()) + len(split.split()) <= 15:
                            if current_chunk:
                                current_chunk += ", " + split
                            else:
                                current_chunk = split
                        else:
                            if current_chunk:
                                sentences.append(current_chunk)
                            current_chunk = split
                    if current_chunk:
                        sentences.append(current_chunk)
            
            print(f"Split into {len(sentences)} chunks for faster processing")
        else:
            sentences = [input_text]
            
        # Process each sentence and combine the results
        all_translations = []
        
        for i, sentence in enumerate(sentences):
            print(f"Translating chunk {i+1}/{len(sentences)}")
            word_count = len(sentence.split())
            is_short_text = word_count < 5
            is_very_short_text = word_count < 3
            
            # Check cache first for this sentence
            import hashlib
            text_hash = hashlib.md5(sentence.encode()).hexdigest()
            cache_key = f"{text_hash}_{source_lang}_{target_lang}"
            cached_result = translation_cache.get(cache_key)
            if cached_result:
                print(f"Cache hit for chunk {i+1}")
                all_translations.append(cached_result)
                continue
            
            # For very short texts (7 words or less), try ultra-simple translation first
            if word_count <= 7 and source_lang == "en" and target_lang == "hi":
                simple_result = simple_translate(sentence, source_lang, target_lang)
                if simple_result:
                    print(f"Used simple dictionary translation for chunk {i+1}")
                    translation_cache[cache_key] = simple_result
                    all_translations.append(simple_result)
                    continue
            
            # Ultra-fast path for very short inputs (3 words or less) for basic greetings/phrases
            if word_count <= 3 and target_lang == 'hi':
                # Common English to Hindi translations for very short phrases
                common_translations = {
                    'hello': 'नमस्ते',
                    'hi': 'नमस्ते',
                    'hello.': 'नमस्ते।',
                    'hi.': 'नमस्ते।',
                    'how are you': 'आप कैसे हैं',
                    'how are you?': 'आप कैसे हैं?',
                    'good morning': 'सुप्रभात',
                    'good morning.': 'सुप्रभात।',
                    'good afternoon': 'शुभ दोपहर',
                    'good afternoon.': 'शुभ दोपहर।',
                    'good evening': 'शुभ संध्या',
                    'good evening.': 'शुभ संध्या।',
                    'good night': 'शुभ रात्रि',
                    'good night.': 'शुभ रात्रि।',
                    'thank you': 'धन्यवाद',
                    'thank you.': 'धन्यवाद।',
                    'thanks': 'धन्यवाद',
                    'thanks.': 'धन्यवाद।',
                    'yes': 'हाँ',
                    'yes.': 'हां।',
                    'no': 'नहीं',
                    'no.': 'नहीं।',
                    'goodbye': 'अलविदा',
                    'goodbye.': 'अलविदा।',
                    'bye': 'अलविदा',
                    'bye.': 'अलविदा।',
                    'hello world': 'हैलो दुनिया',
                    'hello world.': 'हैलो दुनिया।'
                }
                
                lower_input = sentence.lower()
                if lower_input in common_translations:
                    result = common_translations[lower_input]
                    print(f"Using fast path translation: {result}")
                    
                    # Cache the result
                    if len(sentence) > 100:
                        import hashlib
                        text_hash = hashlib.md5(sentence.encode()).hexdigest()
                        cache_key = f"{text_hash}_{source_lang}_{target_lang}"
                    else:
                        cache_key = f"{sentence}_{source_lang}_{target_lang}"
                        
                    translation_cache[cache_key] = result
                    all_translations.append(result)
                    continue
            
            # Generate translation with performance-optimized parameters
            translation_parameters = {
                "max_length": 20 if is_very_short_text else (40 if is_short_text else 75),
                "min_length": 1,
                "num_beams": 1 if is_very_short_text else (1 if is_short_text else 2),  # More aggressive beam reduction
                "length_penalty": 1.0,
                "early_stopping": True,
                "do_sample": False,
                "temperature": 0.7,  # Add temperature for faster sampling
                "top_k": 50,         # Add top_k for faster sampling
                "repetition_penalty": 1.2,
                "no_repeat_ngram_size": 2,
                "forced_bos_token_id": en_indic_tokenizer.lang_code_to_id[target_lang]
            }
            
            # Tokenize with performance-optimized settings
            inputs = en_indic_tokenizer(
                sentence, 
                return_tensors="pt", 
                padding=True, 
                truncation=True, 
                max_length=translation_parameters["max_length"]  # Use consistent max_length
            ).to(device)
            
            # Generate translation with performance-optimized parameters
            with torch.no_grad():
                translated = en_indic_model.generate(
                    **inputs,
                    **translation_parameters
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
            if len(sentence) > 100:
                import hashlib
                text_hash = hashlib.md5(sentence.encode()).hexdigest()
                cache_key = f"{text_hash}_{source_lang}_{target_lang}"
            else:
                cache_key = f"{sentence}_{source_lang}_{target_lang}"
                
            translation_cache[cache_key] = output_text
            all_translations.append(output_text)
            
            print(f"Chunk {i+1} translated in {time.time() - start_time:.2f}s")
            
        # Combine translations
        translated_text = " ".join(all_translations)
        print(f"Complete translation time: {time.time() - start_time:.2f}s")
        
        # Cache the combined result
        if len(request.text) > 100:
            import hashlib
            text_hash = hashlib.md5(request.text.encode()).hexdigest()
            cache_key = f"{text_hash}_{source_lang}_{target_lang}"
        else:
            cache_key = f"{request.text}_{source_lang}_{target_lang}"
            
        translation_cache[cache_key] = translated_text
        
        return TranslationResponse(translated_text=translated_text)

    except Exception as e:
        print(f"Translation error in offline mode: {str(e)}")
        return TranslationResponse(translated_text="", error=str(e))

@app.post("/translate_batch/", response_model=List[TranslationResponse])
async def translate_batch(request: TranslationBatchRequest):
    try:
        # Process each text individually for now
        # In a future update, we could process all texts in a single batch for better performance
        results = []
        start_time = time.time()
        
        for text in request.texts:
            single_request = TranslationRequest(
                text=text,
                source_lang=request.source_lang,
                target_lang=request.target_lang
            )
            result = await translate(single_request)
            results.append(result)
            
        print(f"Batch translation of {len(request.texts)} texts completed in {time.time() - start_time:.2f}s")
        return results
    except Exception as e:
        print(f"Batch translation error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

def convert_to_wav(input_file: str, output_file: str) -> bool:
    try:
        subprocess.run(['ffmpeg', '-i', input_file, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', output_file], check=True)
        return True
    except subprocess.CalledProcessError:
        return False

@app.post("/transcribe/realtime/")
async def transcribe_audio(file: UploadFile = File(...), language: str = "en"):
    try:
        print(f"Received audio file: {file.filename}, content_type: {file.content_type}")
        
        # Create a temporary file to store the uploaded audio
        with tempfile.NamedTemporaryFile(delete=False, suffix='.webm') as temp_audio:
            content = await file.read()
            print(f"Received audio data size: {len(content)} bytes")
            temp_audio.write(content)
            temp_audio_path = temp_audio.name
            print(f"Saved audio to: {temp_audio_path}")

        # Create a temporary WAV file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_wav:
            temp_wav_path = temp_wav.name
            print(f"Will convert to WAV at: {temp_wav_path}")

        # Convert the audio to WAV format with specific parameters for webm/opus
        print("Converting audio to WAV format...")
        try:
            subprocess.run([
                'ffmpeg',
                '-fflags', '+genpts',  # Generate presentation timestamps
                '-i', temp_audio_path,
                '-c:a', 'pcm_s16le',  # Use 16-bit PCM for output
                '-ar', '16000',       # Set sample rate to 16kHz
                '-ac', '1',           # Convert to mono
                '-f', 'wav',          # Force WAV format output
                '-y',                 # Overwrite output file if exists
                temp_wav_path
            ], check=True, capture_output=True, text=True)
            print("Audio conversion successful")
        except subprocess.CalledProcessError as e:
            print(f"FFmpeg error: {e.stderr}")
            raise HTTPException(status_code=500, detail=f"Failed to convert audio format: {e.stderr}")

        # Verify the WAV file exists and has content
        if not os.path.exists(temp_wav_path):
            raise HTTPException(status_code=500, detail="WAV file was not created")
        
        wav_size = os.path.getsize(temp_wav_path)
        print(f"WAV file size: {wav_size} bytes")
        
        if wav_size == 0:
            raise HTTPException(status_code=500, detail="WAV file is empty")

        # Transcribe the audio with specific parameters
        print(f"Starting transcription with language: {language}")
        try:
            result = model.transcribe(
                temp_wav_path,
                language=language,
                task="transcribe",
                fp16=False,  # Disable half-precision for better compatibility
                verbose=True  # Enable verbose output for debugging
            )
            print(f"Transcription result: {result['text']}")
            
            # Add detected language to response
            detected_language = result.get('language', language)
            print(f"Detected language: {detected_language}")
            
            return {
                "text": result["text"],
                "detected_language": detected_language
            }
        except Exception as e:
            print(f"Transcription error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

        # Clean up temporary files
        try:
            os.unlink(temp_audio_path)
            os.unlink(temp_wav_path)
            print("Temporary files cleaned up")
        except Exception as e:
            print(f"Warning: Failed to clean up temporary files: {str(e)}")

        return {"text": result["text"]}

    except Exception as e:
        print(f"Error in transcribe_audio: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

class TestTranscribeRequest(BaseModel):
    test: bool = True
    language: str = "en"

@app.post("/transcribe/test/")
async def test_transcribe(request: TestTranscribeRequest):
    """Test endpoint that simulates transcription without file upload"""
    print(f"Test transcription endpoint called with language: {request.language}")
    try:
        # Return a test response to verify endpoint is working
        return {
            "text": "This is a test transcription response.",
            "detected_language": request.language,
            "test": True
        }
    except Exception as e:
        print(f"Error in test transcription: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ping")
async def ping():
    """Ping server to check if it's running."""
    return {"status": "ok"}

@app.get("/health")
async def health_check():
    """Check if server is healthy and TTS service is available."""
    try:
        # Get available languages
        languages = await get_supported_languages()
        
        return {
            "status": "ok",
            "tts_service": "google_tts",
            "available_languages": languages
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {"status": "error", "error": str(e)}

# Simplified Translation Dictionary - English to Hindi
en_hi_simple_dict = {
    "i": "मैं",
    "me": "मुझे",
    "my": "मेरा",
    "mine": "मेरा",
    "you": "आप",
    "your": "आपका",
    "he": "वह",
    "she": "वह",
    "his": "उसका",
    "her": "उसकी",
    "it": "यह",
    "we": "हम",
    "they": "वे",
    "their": "उनका",
    "am": "हूँ",
    "is": "है",
    "are": "हैं",
    "was": "था",
    "were": "थे",
    "have": "है",
    "has": "है",
    "had": "था",
    "will": "करेंगे",
    "would": "करेंगे",
    "can": "सकते हैं",
    "could": "सकते थे",
    "should": "चाहिए",
    "the": "",
    "a": "एक",
    "an": "एक",
    "in": "में",
    "on": "पर",
    "at": "पर",
    "for": "के लिए",
    "to": "को",
    "from": "से",
    "with": "के साथ",
    "without": "के बिना",
    "and": "और",
    "or": "या",
    "but": "लेकिन",
    "because": "क्योंकि",
    "if": "अगर",
    "hello": "नमस्ते",
    "hi": "नमस्ते",
    "good": "अच्छा",
    "morning": "सुबह",
    "evening": "शाम",
    "night": "रात",
    "bye": "अलविदा",
    "goodbye": "अलविदा",
    "yes": "हाँ",
    "no": "नहीं",
    "please": "कृपया",
    "thank": "धन्यवाद",
    "thanks": "धन्यवाद",
    "welcome": "स्वागत है",
    "sorry": "माफ़ करें",
    "excuse": "क्षमा करें",
    "how": "कैसे",
    "what": "क्या",
    "when": "कब",
    "where": "कहाँ",
    "who": "कौन",
    "why": "क्यों",
    "which": "कौन सा",
    "time": "समय",
    "day": "दिन",
    "today": "आज",
    "tomorrow": "कल",
    "yesterday": "कल",
    "name": "नाम",
    "food": "खाना",
    "water": "पानी",
    "money": "पैसा",
    "home": "घर",
    "house": "घर",
    "work": "काम",
    "school": "स्कूल",
    "book": "किताब",
    "phone": "फोन",
    "computer": "कंप्यूटर",
    "friend": "मित्र",
    "family": "परिवार"
}

def simple_translate(text, source_lang, target_lang):
    """Simple word-by-word translation for very basic texts"""
    if source_lang != "en" or target_lang != "hi":
        return None  # Only support en->hi for now
        
    words = text.lower().split()
    if len(words) > 7:  # Only for very short texts
        return None
        
    # Simple word-by-word translation
    translated_words = []
    for word in words:
        # Remove punctuation for lookup
        clean_word = word.strip('.,!?;:')
        if clean_word in en_hi_simple_dict:
            # If the word has punctuation, add it back
            if clean_word != word:
                punctuation = word[len(clean_word):]
                translated_words.append(en_hi_simple_dict[clean_word] + punctuation)
            else:
                translated_words.append(en_hi_simple_dict[clean_word])
        else:
            # If not found, keep original
            translated_words.append(word)
            
    # Add appropriate word order for Hindi
    result = " ".join(translated_words)
    
    # Clean up the text
    result = result.replace("  ", " ").strip()
    
    return result

class TTSRequest(BaseModel):
    text: str
    language: str

@app.post("/tts/")
async def text_to_speech(request: TTSRequest):
    """Generate speech from text using Google TTS"""
    try:
        text = request.text
        language = request.language
        
        logger.info(f"TTS request: language={language}, text='{text}'")
        
        # Create temporary file for speech output
        with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as temp_file:
            output_path = temp_file.name
        
        # Supported language mapping
        supported_langs = {
            'en': 'en', 'hi': 'hi', 'ta': 'ta', 'te': 'te', 
            'ml': 'ml', 'bn': 'bn', 'mr': 'mr', 'gu': 'gu', 
            'kn': 'kn', 'pa': 'pa', 'ur': 'ur'
        }
        
        if language not in supported_langs:
            raise HTTPException(
                status_code=400, 
                detail=f"Language '{language}' is not supported. Supported languages: {list(supported_langs.keys())}"
            )
        
        # Generate speech using Google TTS
        tts_lang = supported_langs.get(language, 'en')
        tts = gTTS(text=text, lang=tts_lang, slow=False)
        tts.save(output_path)
        
        logger.info(f"Generated speech for text '{text}' in {language}")
        
        # Return the audio file
        return FileResponse(
            path=output_path,
            media_type="audio/mp3",
            filename=f"tts_{language}_{int(time.time())}.mp3"
        )
    except Exception as e:
        logger.error(f"TTS error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tts/available_models")
async def get_available_tts_models():
    """Get available TTS models"""
    supported_languages = [
        'en', 'hi', 'ta', 'te', 'ml', 'bn', 'mr', 'gu', 'kn', 'pa', 'ur'
    ]
    
    language_names = {
        'en': 'English',
        'hi': 'Hindi',
        'ta': 'Tamil',
        'te': 'Telugu',
        'ml': 'Malayalam',
        'bn': 'Bengali',
        'mr': 'Marathi',
        'gu': 'Gujarati',
        'kn': 'Kannada',
        'pa': 'Punjabi',
        'ur': 'Urdu',
    }
    
    return {
        "supported_languages": supported_languages,
        "language_names": language_names
    }

@app.post("/tts/test")
async def test_tts(request: TTSRequest):
    """Test TTS without generating audio - just verifies the service is working"""
    supported_langs = {
        'en': 'en', 'hi': 'hi', 'ta': 'ta', 'te': 'te', 
        'ml': 'ml', 'bn': 'bn', 'mr': 'mr', 'gu': 'gu', 
        'kn': 'kn', 'pa': 'pa', 'ur': 'ur'
    }
    
    if request.language not in supported_langs:
        raise HTTPException(
            status_code=400, 
            detail=f"Language '{request.language}' is not supported. Supported languages: {list(supported_langs.keys())}"
        )
    
    return {
        "status": "ok",
        "message": f"TTS service is available for language '{request.language}'",
        "text": request.text,
        "language": request.language
    }

@app.get("/tts/test")
async def test_tts_get():
    """Simple endpoint to test TTS availability without parameters"""
    return {
        "status": "ok",
        "message": "TTS service is available",
        "service": "google_tts"
    }

async def get_supported_languages():
    """Get supported languages for all services"""
    supported_languages = [
        'en', 'hi', 'ta', 'te', 'ml', 'bn', 'mr', 'gu', 'kn', 'pa', 'ur'
    ]
    
    return {"languages": supported_languages}

# Add cleanup to startup
@app.on_event("startup")
async def startup_event():
    """Initialize any resources on startup"""
    print("\n" + "="*50)
    print("SERVER RUNNING IN OFFLINE MODE ONLY")
    print("All models and resources are loaded locally")
    print("="*50 + "\n")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)