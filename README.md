# VibeNotes 📓

> Aplikasi logbook kegiatan berbasis *Computer Vision* yang mampu mendeteksi objek pendukung aktivitas secara real-time serta menganalisis suasana kegiatan (*vibe*) menggunakan pendekatan Pengolahan Citra Digital dan Edge AI.

---

## 👥 Tim Pengembang

**Tim:** VibeNotes — Kelompok A4
**Anggota:** Gilang Aditya Sumarna

🎨 **Figma UI:**
https://www.figma.com/design/HF5KzagzbEBtxOAhoM9VUV/VibeNote-Design?node-id=0-1&t=KHsNVRo0Yt1o5oLT-0

---

## 🚀 Fitur Utama

* 📸 **Real-time Camera Stream**
  Mengakses kamera perangkat secara live dengan manajemen lifecycle yang aman.

* 🤖 **Object Detection (Edge AI)**
  Mendeteksi objek seperti laptop, buku, minuman, dan perangkat aktivitas menggunakan model TensorFlow Lite / YOLO secara lokal (tanpa API eksternal).

* 🎨 **Spatial Overlay**
  Menampilkan hasil deteksi dalam bentuk *bounding box* menggunakan `CustomPainter`.

* 🧠 **Vibe Analysis (PCD)**
  Menganalisis suasana kegiatan berdasarkan distribusi warna dan pencahayaan (HSV, brightness, contrast).

* 📖 **Logbook System**
  Menyimpan kegiatan beserta hasil analisis visual dalam bentuk logbook.

* 📊 **Insight Sederhana**
  Memberikan gambaran pola aktivitas berdasarkan data yang tersimpan.

---

## 🔄 Alur Sistem

```
Camera Stream
   ↓
Preprocessing (Resize, Normalization, HSV)
   ↓
ML Inference (TFLite / YOLO)
   ↓
Bounding Box Overlay
   ↓
Vibe Analysis
   ↓
Save to Logbook
```

---

## 🧠 Konsep Pengolahan Citra Digital (PCD)

Aplikasi ini menerapkan beberapa teknik PCD:

* **Resizing** untuk menyesuaikan dimensi input model
* **Normalisasi** nilai piksel ke rentang [0,1]
* **Color Space Conversion (RGB → HSV)** untuk analisis suasana
* **Ekstraksi fitur visual** melalui model deteksi objek

---

## 📌 Mapping ke Functional Requirements

| Requirement                     | Implementasi                         |
| ------------------------------- | ------------------------------------ |
| FR-01: Vision Acquisition       | Modul kamera (`core/camera`)         |
| FR-02: Edge Inference           | Modul inference (`core/inference`)   |
| FR-03: Spatial Overlay          | CustomPainter (`core/overlay`)       |
| FR-04: Digital Image Processing | Preprocessing (`core/preprocessing`) |
| FR-05: Performance Management   | Isolate (background processing)      |

---

## 🛠️ Tech Stack

| Layer            | Teknologi                                            |
| ---------------- | ---------------------------------------------------- |
| Framework        | Flutter (Mobile)                                     |
| ML / CV          | TensorFlow Lite, OpenCV (FFI), MediaPipe / YOLO Nano |
| Database Lokal   | Hive                                                 |
| Database Cloud   | MongoDB Atlas                                        |
| State Management | Provider / Bloc                                      |
| Config           | flutter_dotenv (.env)                                |

---

## 🏗️ Arsitektur (SOLID)

```
lib/
├── config/          # EnvConfig — Single Source of Truth (.env)
├── core/
│   ├── camera/      # Hardware Stream (FR-01)
│   ├── inference/   # Edge Inference (FR-02)
│   ├── overlay/     # Spatial Overlay (FR-03)
│   └── preprocessing/ # Image Processing (FR-04)
├── features/
│   ├── logbook/     # CRUD entri kegiatan
│   ├── detection/   # Halaman deteksi real-time
├── data/
│   ├── local/       # Hive storage
│   ├── remote/      # MongoDB sync
│   └── models/      # Data model
└── state/           # Provider / Bloc
```

### Prinsip yang digunakan:

* **Separation of Concerns**
* **Environment Driven Configuration**
* **Resource Safety (dispose lifecycle)**

---

## ⚙️ Konfigurasi

Gunakan file `.env` sebagai *Single Source of Truth*:

```
MODEL_PATH=assets/model.tflite
CONFIDENCE_THRESHOLD=0.5
INPUT_SIZE=224
```

---

## ▶️ Cara Menjalankan

```bash
# Clone repository
git clone https://github.com/Ditt21-Lang/VibeNote.git
cd VibeNote

# Install dependencies
flutter pub get

# Setup environment
cp .env.example .env

# Generate Hive adapters
dart run build_runner build

# Run aplikasi
flutter run
```

---

## 📊 Status Pengembangan

* [x] Project Initialization
* [ ] Camera Integration
* [ ] Object Detection
* [ ] Overlay Visualization
* [ ] Vibe Analysis
* [ ] Logbook System
* [ ] Performance Optimization (Isolate)

---

## 📌 Catatan

Proyek ini dikembangkan sebagai bagian dari Tugas Besar Pengolahan Citra Digital dengan fokus pada implementasi Edge AI pada perangkat mobile.

---

## 🧾 Lisensi

Digunakan untuk keperluan akademik.
