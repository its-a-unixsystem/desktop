# Coin Price Script

This script fetches cryptocurrency data from the [Kraken API](https://www.kraken.com/en-gb/features/api) and displays the current price along with the percentage change since the previous day's price. It cycles through a set of trading pairs, rotating automatically based on the current timestamp.

---

## Features

- **Rotates Through Pairs**: Cycles through an array of trading pairs (e.g., `BTC/EUR`, `ETH/EUR`) at a user-defined interval.
- **Configurable Candle Interval**: Uses Kraken’s OHLC endpoint with a selected candle interval (e.g., 5 minutes).
- **JSON Output**: Prints structured JSON (for status bars or widgets) containing:
  - Current price  
  - Percentage change  
  - A CSS/class-like field indicating upward or downward trends

---

## Requirements

- **jq** for parsing JSON responses.  
- **bc** for floating-point arithmetic in Bash.  
- **curl** to fetch data from Kraken.  

---

## Setup

1. **Create or Copy the Script**  
   Save the script locally (e.g., `coin_price.sh`) and make it executable:
   ```bash
   chmod +x coin_price.sh
   ```

2. **(Optional) Create a Pairs File**  
   If you are using the version that reads trading pairs from a file:
   1. Create a text file (e.g., `pairs.txt`) in the same directory.  
   2. Include one pair and its symbol per line, for example:
      ```
      DOTEUR 
      TBTCEUR 
      XETHZEUR ⟠
      ```
   3. Adjust the file path in the script if needed or pass it as a command-line argument.

3. **Install Dependencies**  
   - Ensure `jq`, `bc`, and `curl` are available on your system.

---

## Usage

1. **Run the Script**  
   If you have a script version that hardcodes pairs, simply execute:
   ```bash
   ./coin_price.sh
   ```
   If your script reads from `pairs.txt`:
   ```bash
   ./coin_price.sh pairs.txt
   ```
   or provide another file path:
   ```bash
   ./coin_price.sh /path/to/your_pairs_file.txt
   ```

2. **Automatic Pair Rotation**  
   - The script computes an index based on the current Unix timestamp divided by a defined rotation interval (e.g., 10 seconds).  
   - Each new invocation (or at each time interval) selects a different pair from the list.

3. **Interpreting the Output**  
   - It outputs JSON of the form:
     ```json
     {
       "text": "XETHZEUR €1200.00 (+5.32%)",
       "tooltip": "",
       "class": "up"
     }
     ```
   - The `"class"` field can be `"up"`, `"down"`, `"critdown"`, or other classifications depending on the price move.  
   - The `"text"` shows the symbol, price, and percentage change.

---

## Customization

- **Rotation Interval**: Modify `ROTATION_SECONDS` in the script (e.g., `10` seconds).
- **Candle Interval**: Adjust `CHART_INTERVAL` (e.g., `5` minutes).
- **Thresholds**: The script typically treats a drop of more than 10% as `"critdown"`; you can tweak this value within the script.

---

## License

Licensed under the MIT License. You may use, modify, and distribute this script as needed.
