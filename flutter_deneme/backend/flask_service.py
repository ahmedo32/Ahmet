"""
flask_service.py

This Flask service uses Zemberek (a Java-based Turkish NLP library) and Google Gemini OCR.
JPype requires its support JAR (`org.jpype.jar`). This code will search for that JAR:
  1. In the local `backend/` folder
  2. In the venv's `site-packages/jpype/_jars/`
  3. In the venv's `site-packages/` root
Place your `zemberek-full.jar` in the `backend/` folder alongside this script.
"""
from dotenv import load_dotenv
import os
import base64
import site
from flask import Flask, request, jsonify
"""
flask_service.py

This Flask service uses Zemberek (a Java-based Turkish NLP library) and Google Gemini OCR.
"""
from dotenv import load_dotenv
import os
import base64
import sys
from flask import Flask, request, jsonify
from google import genai
from google.genai import types

# Load environment variables first
load_dotenv()
api_key = os.getenv("GENAI_API_KEY")
if not api_key:
    raise RuntimeError("GENAI_API_KEY not set in environment")

# Initialize Gemini client
client = genai.Client(api_key=api_key)

# JPype setup - import and configure before starting JVM
try:
    import jpype
    import jpype.imports
    from jpype.types import *
except ImportError:
    print("JPype1 not installed. Install with: pip install JPype1")
    sys.exit(1)

# Base directory (where this script lives)
base_dir = os.path.dirname(os.path.abspath(__file__))

# Locate Zemberek JAR file
zemberek_jar = os.path.join(base_dir, "zemberek-full.jar")
if not os.path.isfile(zemberek_jar):
    raise FileNotFoundError(f"Missing Zemberek JAR: {zemberek_jar}")

# JVM Configuration
def setup_jvm():
    """Setup JVM with proper configuration"""
    if jpype.isJVMStarted():
        return
    
    # JVM arguments for better performance and memory management
    jvm_args = [
        '-Djava.class.path=' + zemberek_jar,
        '-Xmx2g',  # Maximum heap size
        '-Xms512m',  # Initial heap size
        '-Dfile.encoding=UTF-8',  # Ensure UTF-8 encoding for Turkish text
    ]
    
    try:
        # Get default JVM path
        jvm_path = jpype.getDefaultJVMPath()
        print(f"Starting JVM at: {jvm_path}")
        print(f"Zemberek JAR: {zemberek_jar}")
        
        # Start JVM
        jpype.startJVM(jvm_path, *jvm_args)
        print("JVM started successfully")
        
    except Exception as e:
        print(f"Failed to start JVM: {e}")
        raise

# Initialize JVM and Zemberek
setup_jvm()

# Import Java classes after JVM is started
try:
    # Import Zemberek classes
    TurkishMorphology = jpype.JClass('zemberek.morphology.TurkishMorphology')
    
    # Try different spell checker classes that might be available
    try:
        # Try the newer API
        TurkishSpellChecker = jpype.JClass('zemberek.normalization.TurkishSpellChecker')
        print("Found TurkishSpellChecker class")
    except:
        try:
            # Try alternative spell checker
            TurkishSpellChecker = jpype.JClass('zemberek.spelling.TurkishSpellChecker')
            print("Found alternative TurkishSpellChecker class")
        except:
            print("No spell checker class found, will use morphology only")
            TurkishSpellChecker = None
    
    # Initialize Zemberek components
    print("Initializing Zemberek...")
    morphology = TurkishMorphology.createWithDefaults()
    print("TurkishMorphology initialized successfully")
    
    # Try to initialize spell checker with different methods
    spell_checker = None
    if TurkishSpellChecker:
        try:
            # Try different constructor methods
            spell_checker = TurkishSpellChecker(morphology)
            print("Spell checker initialized with morphology parameter")
        except:
            try:
                spell_checker = TurkishSpellChecker()
                print("Spell checker initialized with default constructor")
            except Exception as e:
                print(f"Could not initialize spell checker: {e}")
                spell_checker = None
    
    print("Zemberek initialization completed")
    
except Exception as e:
    print(f"Failed to initialize Zemberek: {e}")
    print("Make sure zemberek-full.jar is in the backend/ folder")
    raise

app = Flask(__name__)

def correct_turkish(text: str) -> str:
    """
    Use Zemberek to spell-check and correct Turkish text
    """
    if not text or not text.strip():
        return text
    
    try:
        # Split text into words
        words = text.split()
        corrected_words = []
        
        for word in words:
            # Clean the word (remove punctuation for checking)
            clean_word = ''.join(c for c in word if c.isalpha())
            
            if not clean_word:
                corrected_words.append(word)
                continue
            
            # Check if word is correct using morphology
            analysis = morphology.analyze(clean_word)
            
            if not analysis.isEmpty():
                # Word is recognized, keep original (with punctuation)
                corrected_words.append(word)
            else:
                # Word not recognized, try to correct it if spell checker is available
                if spell_checker:
                    try:
                        # Try different spell checker methods
                        suggestions = None
                        
                        # Try various method names that might exist
                        for method_name in ['suggestForWord', 'suggest', 'getSuggestions']:
                            if hasattr(spell_checker, method_name):
                                method = getattr(spell_checker, method_name)
                                suggestions = method(clean_word)
                                break
                        
                        if suggestions and not suggestions.isEmpty():
                            # Get the best suggestion
                            best_suggestion = str(suggestions.get(0))
                            # Replace the clean word part but keep punctuation
                            corrected_word = word.replace(clean_word, best_suggestion)
                            corrected_words.append(corrected_word)
                        else:
                            # No suggestions, keep original
                            corrected_words.append(word)
                    except Exception as e:
                        print(f"Spell check error for word '{clean_word}': {e}")
                        corrected_words.append(word)
                else:
                    # No spell checker available, keep original
                    corrected_words.append(word)
        
        return ' '.join(corrected_words)
        
    except Exception as e:
        print(f"Error in Turkish correction: {e}")
        return text  # Return original text if correction fails

def basic_turkish_correction(text: str) -> str:
    """
    Fallback Turkish correction without spell checker
    """
    import re
    
    if not text or not text.strip():
        return text
    
    # Common Turkish character corrections
    corrections = {
        # Fix common OCR mistakes for Turkish characters
        'i̇': 'i',  # Fix dotted i issues
        'İ': 'İ',  # Capital i with dot
        'ı': 'ı',  # Dotless i
        
        # Common word corrections
        r'\bve\b': 've',
        r'\bbir\b': 'bir', 
        r'\bbu\b': 'bu',
        r'\biçin\b': 'için',
        r'\bolan\b': 'olan',
        r'\bsonra\b': 'sonra',
        r'\bdaha\b': 'daha',
        r'\bgibi\b': 'gibi',
        r'\bile\b': 'ile',
        
        # Fix common OCR character mistakes
        r'rn(?=\s)': 'm',
        r'cl(?=\s)': 'd',
    }
    
    corrected = text
    for pattern, replacement in corrections.items():
        if r'\b' in pattern:
            corrected = re.sub(pattern, replacement, corrected, flags=re.IGNORECASE)
        else:
            corrected = re.sub(pattern, replacement, corrected)
    
    return corrected.strip()

@app.route("/ocr", methods=["POST"])
def ocr():
    try:
        # Decode incoming JSON payload
        payload = request.get_json(force=True)
        img_b64 = payload.get("image", "")
        
        if not img_b64:
            return jsonify({"error": "No image data provided"}), 400
        
        # Decode base64 image
        img_bytes = base64.b64decode(img_b64)

        # Call Gemini to extract text from image
        response = client.models.generate_content(
            model="gemini-2.0-flash-exp",
            contents=[
                types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"),
                """Extract all the handwritten and printed text from this image. 
                This text is likely in Turkish, so pay attention to Turkish characters like ı, ğ, ü, ş, ö, ç.
                Focus on accuracy and preserve the original layout as much as possible."""
            ]
        )
        
        raw_text = response.text if response.text else ""
        
        # Try Zemberek correction first, fallback to basic correction
        try:
            corrected_text = correct_turkish(raw_text)
        except Exception as e:
            print(f"Zemberek correction failed, using basic correction: {e}")
            corrected_text = basic_turkish_correction(raw_text)
        
        return jsonify({
            "text": corrected_text,
            "raw_text": raw_text,
            "correction_method": "zemberek" if spell_checker else "basic"
        })
        
    except Exception as e:
        print(f"OCR error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "ok",
        "jvm_started": jpype.isJVMStarted(),
        "morphology_available": 'morphology' in globals(),
        "spell_checker_available": spell_checker is not None,
        "zemberek_jar": zemberek_jar
    })

# Cleanup function
def cleanup():
    """Cleanup resources when shutting down"""
    if jpype.isJVMStarted():
        jpype.shutdownJVM()

import atexit
atexit.register(cleanup)

if __name__ == "__main__":
    print("Starting Flask OCR service...")
    print(f"Zemberek JAR: {zemberek_jar}")
    print(f"JVM Status: {jpype.isJVMStarted()}")
    print(f"Morphology available: {'morphology' in globals()}")
    print(f"Spell checker available: {spell_checker is not None}")
    
    try:
        app.run(host="0.0.0.0", port=5000, debug=False)
    except KeyboardInterrupt:
        print("Shutting down...")
        cleanup()
