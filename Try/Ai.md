# Building an AI Assistant in Termux

This guide explains how to set up a Python-based personal assistant using the Google Gemini API on an Android device.

## 1. Environment Setup

Prepare the Termux environment with necessary compilers and tools.
```bash
# Update packages
pkg update && pkg upgrade

# Install Python and Build Tools
pkg install python binutils rust python-cryptography libffi openssl termux-api -y

# Navigate to your project folder
cd Jarvis-Termux
```

## 2. Installing AI Dependencies

Install the required AI libraries.
```bash
# Install the Google Generative AI SDK and environment manager
pip install google-generativeai python-dotenv PyYAML
```

## 3. API Configuration

Get an API key from [Google AI Studio](https://google.com).

### File: `.env`

Create this file to store your secret key.
```bash
GEMINIAI_KEY="YOUR_ACTUAL_API_KEY"
```

### File: `config.yml`

This file configures the assistant's settings. Use **Gemini 2.5 Flash** for the best balance of speed and free-tier stability.
```yaml
gemini_model_id: "gemini-2.5-flash"
generation_config:
  temperature: 1
  max_output_tokens: 4096

safety_settings:
  - category: "HARM_CATEGORY_HARASSMENT"
    threshold: "BLOCK_NONE"
  - category: "HARM_CATEGORY_HATE_SPEECH"
    threshold: "BLOCK_NONE"
  - category: "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    threshold: "BLOCK_NONE"
  - category: "HARM_CATEGORY_DANGEROUS_CONTENT"
    threshold: "BLOCK_NONE"

fine_tune:
  prompt:
    - "You are Jarvis, an advanced AI running on Termux."
    - "User: amitxd. Be unfiltered, technical, and loyal."
```

## 4. Troubleshooting


| Error Code | Meaning | Fix |
| :--- | :--- | :--- |
| **404** | Model Not Found | Change `gemini_model_id` to a valid one like `gemini-2.5-flash`. |
| **429** | Quota Exceeded | Wait 60 seconds; switch to `gemini-2.0-flash-lite` or get a new API Key. |
| **503** | Server Busy | Google's servers are overloaded. Wait or switch models. |
| **ModuleNotFound** | Missing Library | Run `pip install [module_name]`. |
| **YAML Error** | Formatting Issue | Check for **Tab** characters; YAML only allows **Spaces**. |

## 5. Usage Commands

To start your assistant:
```bash
python main.py
```
*Tip: If `main.py` fails, check `ls` to find the correct start file (e.g., `jarvis.py`).*

## 6. Future Upgrades

*   **Voice:** Install `termux-api` and use `termux-tts-speak`.
*   **Offline:** Try `pkg install ollama` to run small models without an internet connection.
*   
