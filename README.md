# PaperTrails OCR Backend

A Flask-based backend service for **PaperTrails**, a Flutter app that scans handwritten notes and performs Turkish-aware spell correction using Google Gemini OCR and the Zemberek NLP library.

---

## Features

* **Handwriting OCR** via Google Gemini (`gemini-2.5-flash` model)
* **Turkish spell correction** using Zemberek (Java-based NLP)
* **Seamless Python–Java integration** with JPype
* Clean JSON API for easy Flutter integration

---

## Prerequisites

* **Python 3.11+** installed and on your PATH
* **Java 11+** (for running the embedded JVM)
* **Git** (to clone this repository)
* **Google GenAI API Key** (set in `.env`)

---

## Repository Structure

```
backend/
├── .venv/                # Python virtual environment
├── flask_service.py      # Main Flask application
├── requirements.txt      # Python dependencies
├── zemberek-full.jar     # Zemberek “fat” JAR (place here)
├── org.jpype.jar         # JPype support JAR (place here)
├── .env                  # Environment variables (not checked in)
└── README.md             # This file
```

---

## Installation & Setup

1. **Clone this repo**

   ```bash
   git clone https://github.com/YOUR_USER/paper_trails-backend.git
   cd paper_trails-backend/backend
   ```

2. **Create & activate a virtual environment**

   ```bash
   # Windows (PowerShell)
   py -3.11 -m venv .venv
   .\.venv\Scripts\Activate.ps1

   # macOS/Linux
   python3.11 -m venv .venv
   source .venv/bin/activate
   ```

3. **Install Python dependencies**

   ```bash
   pip install --upgrade pip setuptools
   pip install -r requirements.txt
   ```

4. **Download & place required JARs**

   * **Zemberek**: Download `zemberek-full.jar` (v0.17.1) from the [Zemberek releases](https://github.com/ahmetaa/zemberek-nlp/releases) and save it as `zemberek-full.jar` in this folder.
   * **JPype**: Download `org.jpype.jar` from the [JPype repo](https://github.com/jpype-project/jpype/tree/master/native/jars) and save it as `org.jpype.jar` here.

5. **Set environment variables**
   Create a `.env` file in this directory:

   ```ini
   GENAI_API_KEY=your_gemini_api_key_here
   ```

---

## Running the Service

With the venv activated:

```bash
python flask_service.py
```

You should see:

```
 * Serving Flask app "flask_service"
 * Running on http://0.0.0.0:5000
```

---

## API Reference

### `POST /ocr`

Extract and correct handwritten text.

* **URL:** `/ocr`
* **Method:** `POST`
* **Request JSON:**

  ```json
  {
    "image": "<base64-encoded JPEG bytes>"
  }
  ```
* **Success Response:**

  * **Code:** 200 OK
  * **Content:**

    ```json
    {
      "text": "Corrected Turkish text"
    }
    ```
* **Error Responses:**

  * 400 Bad Request if JSON is malformed
  * 500 Internal Server Error on unexpected failures

---

## Troubleshooting

* **`RuntimeError: Can't find org.jpype.jar support library`**

  * Ensure `org.jpype.jar` is in this folder or under `venv/lib/site-packages/jpype/_jars/`.
  * Use Python 3.11 so pip installs a prebuilt JPype wheel.

* **`ModuleNotFoundError: No module named 'google'`**

  * Run `pip install google-genai`.

* **API key issues**:

  * Verify `.env` contains `GENAI_API_KEY`.
  * Restart the service after editing `.env`.

---

## Contributing

1. Fork this repository.
2. Create a feature branch (`git checkout -b feature/xyz`).
3. Commit your changes (`git commit -m "feat: ..."`).
4. Push to your branch (`git push origin feature/xyz`).
5. Create a Pull Request against `main`.

---

## Versioning

We use Git tags to mark releases:

```bash
git tag -a v0.1.0 -m "Initial backend release"
git push origin v0.1.0
```
---
