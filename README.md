# Robotics Intel NUC Setup & Configuration Guide

Repository ini berisi seluruh file konfigurasi, firmware EDID, udev rules, dan skrip instalasi otomatis untuk **Intel NUC (Ubuntu 24.04 LTS)** yang digunakan pada robot/autonomous vehicle.

Setup ini dirancang agar Intel NUC dapat beroperasi:
1. **100% Headless (Tanpa Layar Fisik)** dengan resolusi terkunci di **1280x720p 60Hz**.
2. **Seamless Mirroring**: Saat dicolokkan ke monitor touchscreen (MPI7002 / ByQDtech), tampilan langsung mirror tanpa black screen atau perubahan resolusi.
3. **Touchscreen Calibration**: Pemetaan input USB touchscreen 1:1 ke layar display.
4. **Ultra Low-Latency Remote Display**: Streaming desktop via **Sunshine + Moonlight** dengan hardware encoding Intel VAAPI (`hevc_vaapi`).

---

## 📁 Struktur Direktori

```text
Robotics_Nuc/
├── configs/
│   ├── 99-touchscreen.rules     # Udev rule untuk binding input touchscreen USB ke DP-2
│   ├── edid-720p.bin            # Binary EDID 1280x720p 60Hz dari layar fisik MPI7002
│   ├── monitors.xml             # Konfigurasi GNOME Display 720p untuk user & GDM
│   ├── sunshine.conf            # Konfigurasi Sunshine streaming server (VAAPI + X11)
│   └── sunshine.service         # Systemd user unit (start setelah graphical-session)
├── scripts/
│   └── setup_nuc.sh             # Skrip setup otomatis untuk NUC baru
└── README.md
```

---

## 🚀 Cara Instalasi di Intel NUC Baru

### 1. Clone Repository
```bash
git clone https://github.com/triwahyu45/Robotics_Nuc.git
cd Robotics_Nuc
```

### 2. Jalankan Skrip Setup Otomatis
```bash
chmod +x scripts/setup_nuc.sh
sudo ./scripts/setup_nuc.sh
```

Skrip ini akan secara otomatis:
- Menginstall driver Intel GPU non-free (`intel-media-va-driver-non-free`, `vainfo`).
- Menginstall firmware Realtek Bluetooth (`linux-firmware-realtek`, `bluez`, `bluez-tools`) agar dongle Bluetooth eksternal langsung plug-and-play.
- Menyalin firmware EDID `edid-720p.bin` ke `/lib/firmware/edid/`.
- Memperbarui `initramfs` dan parameter kernel bootloader `GRUB` agar port `DP-2` dan `HDMI-A-1` dipaksa aktif di 1280x720@60Hz (`drm.edid_firmware`).
- Mengaktifkan autologin GDM3 dan mematikan Wayland (menggunakan X11).
- Memasang Udev rules untuk touchscreen USB (`0483:5750`).
- Memasang konfigurasi Sunshine VAAPI.

### 3. Reboot NUC
```bash
sudo reboot
```

---

## 📡 Konfigurasi Sunshine & Pairing ke Moonlight Laptop/Tablet

### 1. Inisialisasi User/Password Web UI Sunshine
Di terminal NUC:
```bash
sunshine --creds <username> <password>
systemctl --user restart sunshine
```

### 2. Pairing Manual dengan Moonlight
1. Buka aplikasi **Moonlight** di Laptop / Tablet.
2. Klik tombol `+` (Add PC) lalu masukkan IP NUC (misal: `192.168.137.17` atau `192.168.0.104`).
3. Klik icon komputer NUC (🔒). Moonlight akan menampilkan **4 digit PIN**.
4. Buka browser di laptop:
   ```
   https://<IP_NUC>:47990/pin
   ```
5. Pilih perangkat kamu di menu dropdown, ketikkan 4 digit PIN, lalu klik **Send**.
6. Status di Moonlight akan berubah menjadi unlocked dan siap di-stream via app **Desktop**.

> [!IMPORTANT]
> **Catatan Penting Sunshine Conf:**
> Jangan pernah menambahkan opsi `flags = 0` di `sunshine.conf`. Di Sunshine, flag tersebut mengaktifkan `PIN_STDIN` yang memblokir permintaan pairing via Web UI browser.

---

## 🔧 Panduan Troubleshooting Cepat

- **Cek Status Service Sunshine**:
  ```bash
  systemctl --user status sunshine
  ```
- **Cek Deteksi Encoder Hardware Intel**:
  ```bash
  vainfo --display drm --device /dev/dri/renderD128
  ```
- **Cek Status Layar Virtual DRM**:
  ```bash
  for f in /sys/class/drm/card*-*/status; do echo "$f: $(cat $f)"; done
  ```
  *(Output `DP-2` atau `HDMI-A-1` harus `connected` meskipun tidak ada monitor fisik dicolok).*
- **Reset Pairing Cache jika Muncul Error "Incorrect PIN"**:
  Di NUC:
  ```bash
  systemctl --user stop sunshine
  rm -rf ~/.config/sunshine/credentials ~/.config/sunshine/sunshine_state.json
  sunshine --creds <username> <password>
  systemctl --user start sunshine
  ```
