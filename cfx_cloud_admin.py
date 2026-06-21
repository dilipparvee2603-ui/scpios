import firebase_admin
from firebase_admin import credentials, db
import random
import os
import sys
from datetime import datetime
from tkinter import Tk

# --- 1. RESOURCE PATH HELPER ---
def get_resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

# --- 2. SETUP ---
SERVICE_ACCOUNT_FILE = get_resource_path("serviceAccountKey.json")
DATABASE_URL = "https://cfx-scenepack-creator-default-rtdb.firebaseio.com/"
LOG_FILE = "MASTER_KEYS_LOG.txt"

def log_key_to_file(key):
    """Saves ONLY the key for easy bulk copy-pasting"""
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"{key}\n") # Just the key, nothing else
        return True
    except:
        return False

def copy_to_clipboard(text):
    try:
        r = Tk()
        r.withdraw()
        r.clipboard_clear()
        r.clipboard_append(text)
        r.update()
        r.destroy()
        return True
    except:
        return False

def init_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        print(f"❌ ERROR: Internal Security Key not found!")
        return None
    
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        firebase_admin.initialize_app(cred, {'databaseURL': DATABASE_URL})
        return db.reference('licenses')
    except Exception as e:
        print(f"❌ CONNECTION FAILED: {e}")
        return None

def generate_key():
    chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
    p1 = ''.join(random.choice(chars) for _ in range(4))
    p2 = ''.join(random.choice(chars) for _ in range(4))
    return f"{p1}-{p2}"

def main():
    os.system('cls' if os.name == 'nt' else 'clear')
    print("="*60)
    print("      CFX PRODUCTION SUITE: BULK SALES ADMIN")
    print("="*60)
    
    ref = init_firebase()
    if not ref: 
        input("\nPress Enter to exit...")
        return

    print("✅ REALTIME DATABASE CONNECTED")
    print(f"📄 CLEAN KEY LOGGING: {LOG_FILE}\n")
    
    try:
        while True:
            print("\n" + "-"*30)
            cmd = input("[G] Single Key | [B] Batch (for Sales) | [Q] Quit: ").upper()
            
            if cmd == 'G':
                key = generate_key()
                ref.child(key).set({
                    'status': 'NEW', 'deviceId': '', 'platform': 'MOBILE',
                    'createdAt': datetime.now().isoformat()
                })
                print(f"\n✨ KEY: {key} -> SYNCED ✅")
                copy_to_clipboard(key)
                log_key_to_file(key)
                print("📋 COPIED & SAVED TO LOG.")
            
            elif cmd == 'B':
                try:
                    count_in = input("How many keys for sale? ")
                    count = int(count_in) if count_in.strip() else 1
                    print(f"\n🚀 GENERATING {count} KEYS FOR BULK SALE...")
                    for i in range(count):
                        key = generate_key()
                        ref.child(key).set({
                            'status': 'NEW', 'deviceId': '', 'platform': 'MOBILE',
                            'createdAt': datetime.now().isoformat()
                        })
                        log_key_to_file(key)
                        print(f"  [{i+1}] {key} -> SYNCED ✅")
                    print(f"\n🎉 DONE! Open {LOG_FILE} to copy your keys for sale.")
                except:
                    print("Invalid input.")

            elif cmd == 'Q':
                break
    except Exception as e:
        print(f"\nAn error occurred: {e}")
        input("Press Enter to close...")

if __name__ == "__main__":
    main()
