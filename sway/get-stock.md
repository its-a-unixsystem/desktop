# Tiingo Stock Price Script

This script fetches stock price data from the [Tiingo API](https://api.tiingo.com/) and displays the latest price along with the percentage change vs. the previous close. It cycles through multiple tickers by computing an index based on the current timestamp.

---

## Features

- **Rotates Through Tickers**: A time-based rotation (default 10 seconds) selects which ticker to display.
- **Safe API Key Handling**: Reads the Tiingo API key from an external file (permissions recommended: `chmod 600`).
- **JSON Output**: Prints output in JSON, suitable for status bars (e.g., `i3blocks`, `polybar`).

---

## Requirements

- **jq** for JSON parsing.
- **bc** for floating-point arithmetic in Bash.
- **curl** to make API requests.
- A **Tiingo API key** stored in a file (see below).

---

## Setup

1. **Clone or Copy the Script**  
   Save the script locally, e.g., `get-stock.sh`.

2. **Store Your Tiingo API Key**  
   - Create a file (default: `tiingo_api_key.txt`) containing **only** your API key:
   
   ```bash
   echo "YOUR_API_KEY_HERE" > tiingo_api_key.txt
   chmod 600 tiingo_api_key.txt
   ```
   
   This prevents others from reading your credentials.

3. **Make the Script Executable**  
   ```bash
   chmod +x get-stock.sh
   ```

---

## Usage

1. **Run the Script**  
   ```bash
   ./get-stock.sh
   ```
   - By default, the script looks for a file named `tiingo_api_key.txt` in the same directory.
   - If you wish to specify a custom file for your API key, pass it as an argument:
     ```bash
     ./get-stock.sh /path/to/your_key_file.txt
     ```

2. **Observe the Rotating Tickers**  
   - The script uses `TICKERS=("NVDA" "BRK-A" "SPY")` by default.
   - Every `ROTATION_SECONDS` (10 by default), a different ticker from the array will be shown.

3. **JSON Output**  
   The script outputs JSON in the form:
   ```json
   {
     "text": "TICKER $LAST_PRICE (CHANGE_PCT%)",
     "tooltip": "",
     "class": "CLASS_NAME"
   }
   ```
   - `CLASS_NAME` indicates how the price moved:
     - `"critdown"` if below `CRITICAL_DOWN_THRESHOLD` (e.g., -10%).
     - `"down"` if negative but not critically so.
     - `"wayup"` if above a certain positive threshold (e.g., +5%).
     - `"up"` otherwise.

---

## License

Licensed under the MIT License. You are free to use, modify, and distribute this script as needed.
