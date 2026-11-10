# Robotics Intel NUC Setup & Configuration Guide

Repository ini berisi seluruh file konfigurasi, firmware EDID, udev rules, dan skrip instalasi otomatis untuk **Intel NUC (Ubuntu 24.04 LTS)** yang digunakan pada robot/autonomous vehicle.

Setup ini dirancang agar Intel NUC dapat beroperasi:
1. **100% Headless (Tanpa Layar Fisik)** dengan resolusi terkunci di **1280x720p 60Hz**.
2. **Anti-Disconnect & Seamless Mirroring**: Port `HDMI-1` dan `DP-2` dikunci dalam mode mirror 1280x720p. Dicolok atau dicabut monitor saat robot jalan **tidak akan memutuskan koneksi remote Moonlight**.
3. **Touchscreen Calibration**: Pemetaan input USB touchscreen 1:1 ke layar display (`MPI7002 / ByQDtech`).
4. **Ultra Low-Latency Remote Display**: Streaming desktop via **Sunshine + Moonlight** dengan hardware encoding Intel VAAPI (`hevc_vaapi`) dan zero-fail display check wrapper.
5. **Bluetooth External Dongle**: Driver & firmware Realtek (`RTL8761BU`) aktif plug-and-play.
6. **Built-in System Health & Task Manager**: CLI diagnostic tools (`btop`, `htop`, `iotop`, `nvme-cli`) untuk pantau CPU, RAM, suhu, dan kesehatan SSD.

---

## 📁 Struktur Direktori

```text
Robotics_Nuc/
├── configs/
│   ├── 99-touchscreen.rules     # Udev rule untuk binding input touchscreen USB ke DP-2
│   ├── edid-720p.bin            # Binary EDID 1280x720p 60Hz dari layar fisik MPI7002
│   ├── monitors.xml             # Konfigurasi GNOME Display 720p Mirror untuk user & GDM
│   ├── sunshine.conf            # Konfigurasi Sunshine streaming server (VAAPI + X11)
│   └── sunshine.service         # Systemd user unit yang memanggil sunshine-wrapper
├── scripts/
│   ├── setup_nuc.sh             # Skrip 1-Click Setup Otomatis untuk NUC baru
│   └── sunshine-wrapper.sh      # Skrip wrapper anti Error 503 (wait for X11 & lock mirror)
└── README.md
```

---

## 🚀 1-Click Setup di Intel NUC Baru

Cukup jalankan satu perintah berikut di terminal NUC baru:

```bash
git clone https://github.com/triwahyu45/Robotics_Nuc.git
cd Robotics_Nuc
chmod +x scripts/setup_nuc.sh
sudo ./scripts/setup_nuc.sh
```

Lalu reboot NUC:
```bash
sudo reboot
```

### ⚡ Apa yang Otomatis Dilakukan Skrip:
- Menginstall driver Intel GPU non-free (`intel-media-va-driver-non-free`, `vainfo`).
- Menginstall firmware Realtek Bluetooth (`linux-firmware-realtek`, `bluez`) agar dongle Bluetooth eksternal langsung aktif.
- Menginstall tool monitoring sistem & disk health (`btop`, `htop`, `nvme-cli`, `smartmontools`).
- Menyalin firmware EDID `edid-720p.bin` ke `/lib/firmware/edid/`.
- Memperbarui `initramfs` dan parameter kernel bootloader `GRUB` agar port `DP-2` dan `HDMI-A-1` dipaksa aktif di 1280x720@60Hz (`drm.edid_firmware`).
- Mengaktifkan autologin GDM3 dan mematikan Wayland (menggunakan X11).
- Mengunci mode mirror 1280x720p permanen di level user dan GDM login screen (`monitors.xml`).
- Memasang Udev rules untuk touchscreen USB (`0483:5750`).
- Mengaktifkan wrapper service Sunshine (`sunshine-wrapper.sh`) agar tidak ada `Error 503`.

---

## 📡 Pairing Sunshine ke Moonlight di Laptop / Tablet

Jika ingin menghubungkan laptop / tablet baru ke NUC:

1. **Set Password Web UI Sunshine (jika belum):**
   ```bash
   sunshine --creds <username> <password>
   systemctl --user restart sunshine
   ```
2. **Buka Moonlight di Laptop/Tablet:**
   - Klik **Add Host (+)** -> Masukkan IP NUC (misal: `192.168.0.104` atau IP hotspot).
   - Catat 4 angka PIN yang muncul di Moonlight.
3. **Masukkan PIN ke Web UI Sunshine:**
   - Buka browser: `https://<IP-NUC>:47990`
   - Klik tab **PIN**, masukkan 4 angka tadi, lalu klik **Send**.
4. **Selesai!** Klik icon **Desktop** di Moonlight untuk remote 1280x720p 60FPS ultra smooth.

---

## 📊 CLI Task Manager & Cek Kesehatan SSD / RAM

Untuk memonitor status NUC saat robot beroperasi:

- **Buka Task Manager Grafis di Terminal:**
  ```bash
  btop
  ```
  *(Menampilkan grafik CPU per-core, penggunaan RAM, proses yang makan memory leak, kecepatan disk I/O, dan suhu).*

- **Cek Kesehatan & Umur NVMe SSD NUC:**
  ```bash
  sudo nvme smart-log /dev/nvme0n1
  ```
  *(Perhatikan `percentage_used`, `temperature`, dan `media_errors`).*
