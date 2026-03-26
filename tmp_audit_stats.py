import sqlite3
import os

DB_PATH = 'Data/Store/leobook.db'

def audit():
    if not os.path.exists(DB_PATH):
        print(f"Error: {DB_PATH} not found.")
        return

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    
    try:
        # Check total rows
        total = conn.execute("SELECT COUNT(*) FROM predictions").fetchone()[0]
        
        # Check rows missing intelligence (xg_home is NULL or empty string implies not enriched)
        missing_intel = conn.execute("SELECT COUNT(*) FROM predictions WHERE xg_home IS NULL OR xg_home = ''").fetchone()[0]
        
        # Check rows missing outcome_correct
        missing_outcome = conn.execute("SELECT COUNT(*) FROM predictions WHERE outcome_correct IS NULL OR outcome_correct = ''").fetchone()[0]
        
        # Check rows using legacy RL confidence (0.6, 0.3 or anything > 0.3)
        # Note: In new recalibration, anything > 0.20 is High, 0.08 to 0.20 is Medium. 
        # Sparse rows might have '0.6' or '0.3'.
        sparse_confidence = conn.execute("SELECT COUNT(*) FROM predictions WHERE confidence IN ('0.6', '0.3')").fetchone()[0]

        print(f"Total Rows: {total}")
        print(f"Missing Intelligence (xG, Form, BTTS): {missing_intel}")
        print(f"Missing Outcome Correct: {missing_outcome}")
        print(f"Legacy RL Confidence (0.6/0.3): {sparse_confidence}")
        
    finally:
        conn.close()

if __name__ == "__main__":
    audit()
