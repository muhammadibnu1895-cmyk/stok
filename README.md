# StockFlow — Tahap 1

React + TypeScript + Vite + Supabase PostgreSQL. Tahap 1: UI responsif, dashboard, login dan role, master barang, kategori, gudang, rak, import Excel, SQL RLS, audit master data.

## Jalankan demo tanpa Supabase

1. Install Node.js 20+.
2. `npm install`
3. `npm run dev`
4. Buka alamat yang tampil (biasanya http://localhost:5173).
5. Login `admin` / `admin123` atau `petugas` / `petugas123`.

Tanpa `.env`, aplikasi masuk mode DEMO menggunakan data contoh dan localStorage. Data tiap browser terpisah, tidak cocok untuk uji multi-user terhubung. Kredensial demo bukan autentikasi aman.

## Aktifkan Supabase

1. Buat proyek Supabase.
2. Jalankan `supabase/schema.sql` di SQL Editor (untuk database baru).
3. Buat akun melalui Supabase Authentication > Users. Email/password sign-up publik sebaiknya dinonaktifkan; admin membuat user.
4. Promosikan akun admin tepercaya via SQL Editor (contoh di akhir `schema.sql`).
5. Salin `.env.example` ke `.env.local`, isi `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY` (publishable/anon key, **jangan** service_role).
6. Jalankan `npm run dev`, login memakai email/password Supabase.

Saat Supabase aktif, halaman mengambil data langsung dari tabel dan hak akses ditentukan RLS. Master data dapat ditambah admin; petugas hanya membaca. Admin user provisioning dilakukan di Supabase Console, bukan frontend. Pengelolaan role di UI saat ini hanya matriks informasi.

## Deploy

Build: `npm run build`. Upload isi `dist/` ke Netlify atau Vercel. Set environment variables VITE_* di hosting sebelum build. Untuk SPA ini navigasi menggunakan state (bukan routing URL) sehingga tidak membutuhkan rewrite route khusus.

## Batas Tahap 1

- Dashboard menampilkan agregat persediaan. Dalam demo saldo adalah data ilustrasi; di Supabase saldo dibaca dari `inventory_balances`.
- Mutasi stok, kartu stok, opname, approval, offline sync dan PDF **belum diimplementasikan**; ini untuk tahap berikutnya.
- Impor Excel mendukung kolom `sku,barcode,name,category,unit,cost_price,min_stock`; semua baris divalidasi sebelum insert. Dalam mode online error DB membatalkan insert batch.
- Tidak ada akun admin default di Supabase. Promosi admin dilakukan secara privileged melalui SQL Editor.
- RLS membaca master untuk user login. Untuk produksi multi-gudang, tambahkan pembatasan per gudang sesuai penugasan pada tahap berikutnya.
- `xlsx` digunakan untuk impor Excel; sebelum produksi lakukan review dependensi dan keamanan file unggahan, ukuran file, dan validasi server-side.
