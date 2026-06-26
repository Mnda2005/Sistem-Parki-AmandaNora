.model small
.stack 100h

.data
    ; Slot Maksimal per lantai
    max_slots       db 5
    
    ; Array status jumlah untuk tampilan depan (Indeks 0=Lantai 1, dst.)
    occupied_motor  db 0, 0, 0, 0 
    occupied_mobil  db 0, 0, 0, 0 
    
    ; DATABASE MULTI-SLOT (4 Lantai x 5 Slot x 16 Byte)
    db_f1           db 5 dup(0, 15 dup('$'))
    db_f2           db 5 dup(0, 15 dup('$'))
    db_f3           db 5 dup(0, 15 dup('$'))
    db_f4           db 5 dup(0, 15 dup('$'))
    
    ; Variabel pembantu tracking internal
    current_floor   db 0
    current_type    db 0    ; 1 = Motor, 2 = Mobil
    addr_lantai     dw 0
    is_denda         db 0    ; Variabel penanda denda (0 = Tidak, 1 = Ya)
    
    ; Buffer Input (Int 21h Fungsi 0Ah)
    plate_masuk     db 15, ?, 15 dup('$')
    plate_keluar    db 15, ?, 15 dup('$')
    jenis_buffer    db 15, ?, 15 dup('$')
    
    ; Teks Menu Utama & Pesan Sistem
    msg_header      db 13,10,'================================',13,10,'   SISTEM PARKIR MULTI-SLOT 4LT',13,10,'================================$'
    msg_menu        db 13,10,'1. Check-In (Masuk)',13,10,'2. Check-Out (Keluar & Bayar)',13,10,'3. Exit',13,10,'Pilih Menu: $'
    msg_pilih_lt    db 13,10,'Pilih Lantai (1-4): $'
    
    ; Header & Komponen Status Slot
    msg_stat        db 13,10,'--- STATUS SLOT PARKIR ---$'
    msg_lt1         db 13,10,'Lantai 1: $'
    msg_lt2         db 13,10,'Lantai 2: $'
    msg_lt3         db 13,10,'Lantai 3: $'
    msg_lt4         db 13,10,'Lantai 4: $'
    msg_sep_motor   db ' Motor | $'
    msg_lbl_mobil   db ' Mobil Terisi$'
    
    ; Alur Form Input & Pertanyaan Denda
    msg_jenis       db 13,10,'Ketik Jenis (Motor/Mobil): $'
    msg_plat        db 13,10,'Masukkan No Plat: $'
    msg_durasi      db 13,10,'Durasi Parkir (Jam): $'
    msg_tanya_hilang db 13,10,'Apakah Tiket Hilang? (Y/T): $'
    
    ; Komponen Teks Struk Nota Resmi
    msg_struk       db 13,10,13,10,'================================',13,10,'       NOTA RESI PARKING LOG    ',13,10,'================================$'
    msg_nota_lt     db 13,10,' Posisi Lantai  : Lantai $'
    msg_nota_jenis  db 13,10,' Jenis Kendaraan: $'
    msg_nota_txt_mtr db 'Motor$'
    msg_nota_txt_mbl db 'Mobil$'
    msg_nota_plat   db 13,10,' No. Plat Nomor : $'
    msg_nota_jam    db 13,10,' Durasi Parkir  : $'
    msg_nota_txt_jam db ' Jam$'
    msg_nota_denda   db 13,10,' Denda Tiket     : Rp. 20.000$'
    msg_total       db 13,10,'--------------------------------',13,10,' TOTAL TARIF    : Rp. $'
    msg_footer      db 13,10,'================================',13,10,'   Terima Kasih Atas Kunjungan  ',13,10,'================================$',13,10
    
    ; Log Validasi Error
    msg_full        db 13,10,'[!] Parkiran di Lantai Ini Sudah Penuh!$'
    msg_empty       db 13,10,'[!] Parkiran Lantai Ini Kosong!$'
    msg_salah_plat  db 13,10,'[!] Plat Nomor Tidak Ditemukan di Lantai Ini!$',13,10

.code
main proc
    ; Inisialisasi Segmen Data untuk Struktur EXE murni
    mov ax, @data
    mov ds, ax
    mov es, ax      

start:
    lea dx, msg_header
    mov ah, 09h
    int 21h

    ; ---- BLOK DISPLAY STATUS SLOT SEMUA LANTAI ----
    lea dx, msg_stat
    mov ah, 09h
    int 21h
    
    lea dx, msg_lt1
    mov ah, 09h
    int 21h
    mov al, [occupied_motor+0]
    call cetak_angka_motor
    mov al, [occupied_mobil+0]
    call cetak_angka_mobil
    
    lea dx, msg_lt2
    mov ah, 09h
    int 21h
    mov al, [occupied_motor+1]
    call cetak_angka_motor
    mov al, [occupied_mobil+1]
    call cetak_angka_mobil

    lea dx, msg_lt3
    mov ah, 09h
    int 21h
    mov al, [occupied_motor+2]
    call cetak_angka_motor
    mov al, [occupied_mobil+2]
    call cetak_angka_mobil

    lea dx, msg_lt4
    mov ah, 09h
    int 21h
    mov al, [occupied_motor+3]
    call cetak_angka_motor
    mov al, [occupied_mobil+3]
    call cetak_angka_mobil

    lea dx, msg_menu
    mov ah, 09h
    int 21h

    mov ah, 01h
    int 21h
    sub al, 48

    cmp al, 1
    je menu_masuk
    cmp al, 2
    je menu_keluar
    cmp al, 3
    je exit
    jmp start

; Prosedur pembantu cetak angka status depan
cetak_angka_motor proc
    mov dl, al
    add dl, 48
    mov ah, 02h
    int 21h
    lea dx, msg_sep_motor
    mov ah, 09h
    int 21h
    ret
cetak_angka_motor endp

cetak_angka_mobil proc
    mov dl, al
    add dl, 48
    mov ah, 02h
    int 21h
    lea dx, msg_lbl_mobil
    mov ah, 09h
    int 21h
    ret
cetak_angka_mobil endp


; ================================================
; MENU CHECK-IN (KENDARAAN MASUK)
; ================================================
menu_masuk:
    lea dx, msg_pilih_lt
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    sub al, 49              
    cmp al, 0
    jl menu_masuk
    cmp al, 3
    jg menu_masuk
    mov current_floor, al   
    
    ; Cek total slot terpakai di lantai ini (Motor + Mobil)
    mov bl, current_floor
    mov bh, 0
    mov al, [occupied_motor+bx]
    add al, [occupied_mobil+bx]
    cmp al, max_slots
    jge parkiran_full
    
    lea dx, msg_jenis
    mov ah, 09h
    int 21h
    lea dx, jenis_buffer
    mov ah, 0Ah
    int 21h
    
    ; Deteksi huruf ketiga (Index +4) -> mo't'or vs mo'b'il
    lea si, jenis_buffer
    mov al, [si+4]          
    cmp al, 'b'             
    je set_masuk_mobil
    cmp al, 'B'             
    je set_masuk_mobil
    mov current_type, 1     ; Motor
    jmp form_plat
set_masuk_mobil:
    mov current_type, 2     ; Mobil

form_plat:
    lea dx, msg_plat
    mov ah, 09h
    int 21h
    lea dx, plate_masuk     
    mov ah, 0Ah
    int 21h
    
    ; Cari slot kosong (0) di database lantai terpilih
    call dapatkan_alamat_lantai
    mov di, addr_lantai
    mov cx, 5
cari_slot_kosong:
    mov al, [di]
    cmp al, 0
    je slot_ditemukan
    add di, 16              
    loop cari_slot_kosong
    jmp parkiran_full

slot_ditemukan:
    mov al, current_type
    mov [di], al
    inc di                  
    
    ; Copy string plat nomor ke database slot
    lea si, plate_masuk+2
    mov cx, 14
    cld
    rep movsb
    
    ; Update counter tampilan depan
    mov bl, current_floor
    mov bh, 0
    cmp current_type, 1
    je inc_m_counter
    inc [occupied_mobil+bx]
    jmp start
inc_m_counter:
    inc [occupied_motor+bx]
    jmp start

parkiran_full:
    lea dx, msg_full
    mov ah, 09h
    int 21h
    jmp start


; ================================================
; MENU CHECK-OUT (KENDARAAN KELUAR)
; ================================================
menu_keluar:
    lea dx, msg_pilih_lt
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    sub al, 49              
    cmp al, 0
    jl menu_keluar
    cmp al, 3
    jg menu_keluar
    mov current_floor, al
    
    ; Cek apakah lantai kosong total
    mov bl, current_floor
    mov bh, 0
    mov al, [occupied_motor+bx]
    add al, [occupied_mobil+bx]
    cmp al, 0
    je kosong
    
    lea dx, msg_plat
    mov ah, 09h
    int 21h
    lea dx, plate_keluar    
    mov ah, 0Ah
    int 21h

    ; CARI DAN COCOKKAN PLAT DI DATABASE MULTI-SLOT
    call dapatkan_alamat_lantai
    mov di, addr_lantai
    mov cx, 5               
    
cari_plat_loop:
    push cx
    mov al, [di]
    cmp al, 0               
    je next_slot_search
    
    mov current_type, al    
    push di
    inc di                  
    lea si, plate_keluar+2  
    mov cx, 7               
    cld
    repe cmpsb
    pop di
    je plat_ketemu          

next_slot_search:
    add di, 16              
    pop cx
    loop cari_plat_loop
    
    lea dx, msg_salah_plat
    mov ah, 09h
    int 21h
    jmp start

plat_ketemu:
    pop cx                  
    
    ; Kosongkan slot di database
    mov byte ptr [di], 0    
    mov [is_denda], 0       

    ; PERTANYAAN VALIDASI TIKET HILANG
    lea dx, msg_tanya_hilang
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    cmp al, 'y'
    je set_denda
    cmp al, 'Y'
    je set_denda
    jmp form_durasi_out

set_denda:
    mov [is_denda], 1       

form_durasi_out:
    ; Input Durasi Parkir
    lea dx, msg_durasi
    mov ah, 09h
    int 21h
    mov ah, 01h
    int 21h
    sub al, 48      
    mov cl, al              

    ; Hitung tarif dasar berdasarkan jenis kendaraan hasil database
    cmp current_type, 1
    je tarif_m_out
    mov bl, 5               ; Mobil = Rp 5.000
    jmp proses_hitung
tarif_m_out:
    mov bl, 2               ; Motor = Rp 2.000

proses_hitung:
    mov al, cl          
    mul bl                  
    
    ; Tambah nominal denda flat Rp 20.000 (+20 desimal) jika tiket hilang
    cmp [is_denda], 1
    jne update_counter
    add al, 20              

update_counter:
    ; Kurangi counter display utama sesuai jenis kendaraan
    push ax                 
    mov bl, current_floor
    mov bh, 0
    cmp current_type, 1
    je dec_m_counter
    dec [occupied_mobil+bx]
    jmp cetak_struk
dec_m_counter:
    dec [occupied_motor+bx]

; ------------------------------------------------
; PROSES OUTPUT RESI STRUK NOTA RESMI
; ------------------------------------------------
cetak_struk:
    push ax                 

    ; 1. Cetak Header Nota
    lea dx, msg_struk
    mov ah, 09h
    int 21h

    ; 2. Cetak Info Lantai
    lea dx, msg_nota_lt
    mov ah, 09h
    int 21h
    mov dl, current_floor
    add dl, 49              
    mov ah, 02h
    int 21h

    ; 3. Cetak Info Jenis Kendaraan
    lea dx, msg_nota_jenis
    mov ah, 09h
    int 21h
    cmp current_type, 1
    je cetak_txt_motor
    lea dx, msg_nota_txt_mbl
    jmp proses_cetak_jenis
cetak_txt_motor:
    lea dx, msg_nota_txt_mtr
proses_cetak_jenis:
    mov ah, 09h
    int 21h

    ; 4. Cetak Info Plat Nomor
    lea dx, msg_nota_plat
    mov ah, 09h
    int 21h
    lea dx, plate_keluar+2  
    mov ah, 09h
    int 21h

    ; 5. Cetak Info Durasi Jam
    lea dx, msg_nota_jam
    mov ah, 09h
    int 21h
    mov dl, cl              
    add dl, 48              
    mov ah, 02h
    int 21h
    lea dx, msg_nota_txt_jam
    mov ah, 09h
    int 21h

    ; 6. Cetak Baris Denda (Hanya jika tiket hilang)
    cmp [is_denda], 1
    jne skip_baris_denda
    lea dx, msg_nota_denda
    mov ah, 09h
    int 21h
skip_baris_denda:

    ; 7. Cetak Angka Total Tarif Rp.
    lea dx, msg_total
    mov ah, 09h
    int 21h
    pop ax                  

    aam                 
    add ax, 3030h       
    mov bx, ax          
    
    cmp bh, '0'
    je cetak_satuan
    mov dl, bh
    mov ah, 02h
    int 21h

cetak_satuan:
    mov dl, bl
    mov ah, 02h
    int 21h
    
    ; Cetak nominal ribuan belakang (.000)
    mov dl, '0'
    mov ah, 02h
    int 21h
    int 21h
    int 21h

    ; 8. Cetak Footer Penutup Nota
    lea dx, msg_footer
    mov ah, 09h
    int 21h

    jmp start


; ================================================
; PROSEDUR INTERNAL TRACKING ALAMAT MEMORI LANTAI
; ================================================
dapatkan_alamat_lantai proc
    mov al, current_floor
    cmp al, 0
    je fl1
    cmp al, 1
    je fl2
    cmp al, 2
    je fl3
    lea dx, db_f4
    mov addr_lantai, dx
    ret
fl1: lea dx, db_f1
    mov addr_lantai, dx
    ret
fl2: lea dx, db_f2
    mov addr_lantai, dx
    ret
fl3: lea dx, db_f3
    mov addr_lantai, dx
    ret
dapatkan_alamat_lantai endp


; ================================================
; BLOK ERROR HANDLING & TERMINASI PROGRAM
; ================================================
kosong:
    lea dx, msg_empty
    mov ah, 09h
    int 21h
    jmp start

exit:
    mov ah, 4ch
    int 21h
ret
main endp
end main