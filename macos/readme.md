# 🍎 macOS Scripts

This folder contains shell scripts for managing and checking macOS systems.

---

## 🚀 How to Use

### Method 1 – Make a script executable and run it:

```bash
chmod +x scriptname.sh
./scriptname.sh
```

### Method 2 – Run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/Makeea/scripts/master/macos/scriptname.sh | bash
```

---

## 📂 Scripts and What They Do

- `battery-report.sh` – Checks battery health via `system_profiler` (Apple's own Cycle Count, Condition, and Maximum Capacity), rates its condition, and saves a report plus history CSV to `/var/reports`.

---

All scripts are written to be easy to use and modify.  
Feel free to read through each one before running it.
