#!/usr/bin/env python3
"""
RustChain DOS Miner Bridge
Watches for ATTEST.TXT changes and submits attestations to nodes
"""
import os
import sys
import time
import json
import hashlib
import requests
import urllib3
urllib3.disable_warnings()

ATTEST_FILE = "ATTEST.TXT"
NODES = [
    "https://50.28.86.131:443",
    "https://50.28.86.153:443",
    "http://76.8.228.245:8099",
    "http://100.94.28.32:8099"
]

def parse_attest_file(filepath):
    """Parse ATTEST.TXT into dict"""
    data = {}
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if '=' in line:
                    key, val = line.strip().split('=', 1)
                    data[key] = val
    except:
        pass
    return data

def submit_attestation(attest_data):
    """Submit attestation to RustChain nodes"""
    wallet = attest_data.get('WALLET', 'unknown')
    layers = attest_data.get('LAYERS_PASSED', '0/7')
    emulator = attest_data.get('EMULATOR_DETECTED', 'unknown')
    entropy = attest_data.get('ENTROPY_SCORE', '0')
    
    # Build attestation payload
    payload = {
        "miner": wallet,
        "miner_id": wallet,
        "nonce": int(time.time() * 1000),
        "report": {
            "layers_passed": layers,
            "emulator_detected": emulator == "YES" or emulator == "true",
            "entropy_score": int(entropy) if entropy.isdigit() else 0
        },
        "device": {
            "device_family": "DOS",
            "device_arch": "8086" if emulator == "YES" else "retro",
            "model": "DOS_Miner_v1.0"
        },
        "signals": {},
        "fingerprint": {
            "all_passed": layers == "7/7",
            "checks": {
                "emulator_detected": emulator == "YES"
            }
        }
    }
    
    print(f"\n[*] Submitting attestation for {wallet}")
    print(f"    Layers: {layers}, Emulator: {emulator}")
    
    for node in NODES:
        try:
            url = f"{node}/attest/submit"
            print(f"    Trying {node}...")
            resp = requests.post(url, json=payload, timeout=10, verify=False)
            if resp.status_code == 200:
                print(f"    [OK] Submitted to {node}")
                print(f"    Response: {resp.text[:100]}")
                return True
            else:
                print(f"    [FAIL] {resp.status_code}: {resp.text[:50]}")
        except Exception as e:
            print(f"    [ERROR] {node}: {e}")
    
    return False

def main():
    print("=" * 60)
    print("  RustChain DOS Miner Bridge")
    print("  Watching ATTEST.TXT for changes...")
    print("=" * 60)
    
    last_hash = None
    
    while True:
        try:
            if os.path.exists(ATTEST_FILE):
                with open(ATTEST_FILE, 'rb') as f:
                    current_hash = hashlib.md5(f.read()).hexdigest()
                
                if current_hash != last_hash:
                    print(f"\n[*] ATTEST.TXT changed!")
                    attest_data = parse_attest_file(ATTEST_FILE)
                    if attest_data:
                        submit_attestation(attest_data)
                    last_hash = current_hash
            
            time.sleep(2)  # Check every 2 seconds
            
        except KeyboardInterrupt:
            print("\n[*] Bridge stopped")
            break
        except Exception as e:
            print(f"[ERROR] {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()
