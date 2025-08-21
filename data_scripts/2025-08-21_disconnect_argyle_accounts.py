"""
This script will disconnect all Argyle accounts from the database and is
run as part of sunsetting DSC in Fall 2025.

One of the script inputs is a CSV export of the following SQL query:

```
SELECT
  account_id,
  argyle_user_id
FROM (
  SELECT
    (jsonb_each_text(argyle_accounts)).value AS account_id,
    argyle_user_id
  FROM users
  WHERE argyle_accounts IS NOT NULL
) t;
```

This script should be run a single time, and will delete all Argyle accounts
from the inputted CSV file.

"""

import os
import requests
import pandas as pd
import base64
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv())

# Get the Argyle link URL
argyle_url = os.getenv("ARGYLE_LINK_URL", "")
if not argyle_url:
    raise ValueError("ARGYLE_LINK_URL environment variable is not set")

# Get the Argyle API credentials
argyle_api_key = os.getenv("ARGYLE_API_KEY")
if not argyle_api_key:
    raise ValueError("ARGYLE_API_KEY environment variable is not set")

argyle_api_secret = os.getenv("ARGYLE_API_SECRET")
if not argyle_api_secret:
    raise ValueError("ARGYLE_API_SECRET environment variable is not set")
    
def delete_argyle_account(argyle_account_id: str) -> bool:
    """
    Deletes an Argyle account.
    
    Args:
        argyle_account_id: The Argyle account ID
        
    Returns:
        bool: True if deletion was successful
        
    Raises:
        Exception: If deletion fails with for any reason
    """

    # Build the full Argyle API URL
    url = f"{argyle_url}/v2/accounts/{argyle_account_id}"
    
    # Make the DELETE request
    headers = {
        "accept": "application/json",
        "content-type": "application/json",
        "authorization": f"Basic {base64.b64encode(f'{argyle_api_key}:{argyle_api_secret}'.encode()).decode()}",
    }
    
    response = requests.delete(url, headers=headers)

    if response.status_code == 404:
        raise Exception(f"status: {response.status_code} Argyle account {argyle_account_id} not found; it's possible that it has already been deleted. reason: {response.reason}")

    if not response.ok:
        raise Exception(f"status: {response.status_code} Failed to delete Argyle account {argyle_account_id}, reason: {response.reason}")
    
    print(f"Deleted Argyle account {argyle_account_id} {response.status_code} {response.reason}")
    return True


input_csv_file = os.getenv("INPUT_CSV_FILE", "")

if not input_csv_file:
    raise ValueError("INPUT_CSV_FILE environment variable is not set")

df = pd.read_csv(input_csv_file)

print(f"Loaded {len(df)} Argyle accounts from {input_csv_file}")

# Add a column to track deletion results
df["deletion_success"] = False
df["deletion_notes"] = ""

for index, row in df.iterrows():
    argyle_account_id = row["account_id"]
    print(f"Attempting to delete Argyle account {argyle_account_id}")
    try:
        delete_argyle_account(argyle_account_id)
        df.at[index, "deletion_success"] = True
    except Exception as e:
        df.at[index, "deletion_success"] = False
        df.at[index, "deletion_notes"] = str(e)
        print(f"Error deleting Argyle account {argyle_account_id}")

# Save results to output file
output_filename = input_csv_file.replace(".csv", "_deletion_results.csv")
df.to_csv(output_filename, index=False)
print(f"Saved deletion results to {output_filename}")

print("================================================")
print("================================================")
print("================================================")

print("Successfully deleted {}/{} Argyle accounts".format(
    df["deletion_success"].value_counts().get(True, 0),
    df.shape[0]
))
