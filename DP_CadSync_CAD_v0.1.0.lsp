;;; ---------------------------------------------------------------------------
;;; DP_cadsyncblender — NUA CAD
;;; SPDX-FileCopyrightText: 2026 Ducphan
;;; SPDX-License-Identifier: GPL-2.0-only
;;; ---------------------------------------------------------------------------
;;; MOT lenh duy nhat: DPSYNC — chon doi tuong, bam OK, xong.
;;;
;;; Ghi ra  %TEMP%\dp_cadsync_scene.cadblend  roi Blender tu bat. KHONG co
;;; socket: AutoLISP khong mo duoc TCP, nen Blender la ben chu dong canh file
;;; (xem Addon/dp_cadsyncblender/giao_thuc.py).
;;;
;;; ---------------------------------------------------------------------------
;;; KHONG DIEU KHIEN LENH CUA CAD TU DAY
;;; ---------------------------------------------------------------------------
;;; File nay KHONG duoc goi (command "_.<lenh nao do>" ...). Da thu mot lan voi
;;; `-WBLOCK` de bo xuat C++ cua CAD ghi file thay minh; ket qua ngay
;;; 13/08/2026 tren VinaCAD: lenh khoi dong duoc, nhung thu tu cac cau hoi khac
;;; voi chuoi tham so gui kem, nen CAD dung lai hoi "Enter name of output file"
;;; va nguoi dung mac ket giua chung.
;;;
;;; Moi ban CAD hoi mot kieu, va khong co may cua bon phan mem kia de do. Doan
;;; tren may khach thi cai gia la ho ngoi truoc mot cau hoi khong hieu tu dau
;;; ra. Cham con sua duoc; lam nguoi dung mac ket thi khong.
;;;
;;; Phan do duong xuat nam o CAD/dp_chan_doan.lsp, chi nap khi co chu dinh.
;;;
;;; ---------------------------------------------------------------------------
;;; VI SAO .cadblend LA VAN BAN THUONG, KHONG PHAI GOI NEN NHU .sublend
;;; ---------------------------------------------------------------------------
;;; .sublend cua SU2Blender Sync la JSON -> zlib -> XOR. Ben do lam duoc vi nua
;;; SketchUp la Ruby, co san `json` va `zlib`. AutoLISP KHONG CO ca hai, va
;;; khong co ca thu vien de cai them — nen bat chuoc y nguyen la khong the.
;;;
;;; Thu .sublend thuc su dem lai la CHO DE LON THEM, va cai do nam o thiet ke
;;; ban ghi chu khong o phep nen. Ba thu duoi day lo viec do:
;;;
;;;   1. MOI thuc the deu mang `handle` (ma dinh danh trong ban ve, DXF code 5).
;;;      Day la thu tuong duong su_pid ben SketchUp: no song qua ca lan dong
;;;      file, nen ban sau lam dong bo TANG DAN — sua 3 doi tuong thi Blender
;;;      cap nhat dung 3 object, khong xoa dung lai ca ban ve.
;;;
;;;   2. Ban ghi `X <hexkhoa> <hexgiatri>` bam vao thuc the ngay TRUOC no. Cho
;;;      linetype, be day net, thuoc tinh block, noi dung chu... Dau doc BO QUA
;;;      khoa la thay vi chet, nen nua CAD moi hon van chay voi Blender cu.
;;;
;;;   3. Dau doc ben Blender tu nhan goi nen zlib. Ngay nao viet bo xuat bang
;;;      .NET/ObjectARX (co zlib that) thi doi mot dau la du.
;;;
;;; Van ban thuong con mot cai loi khong nen bo: mo bang Notepad la doc duoc.
;;; Day la addon MIEN PHI, khong co gi phai giau.
;;;
;;; VI SAO KHONG DUNG COM/DDE: VinaCAD 2026 khong co COM automation server, con
;;; DDE bat tay duoc nhung lenh roi vao hu khong — no GIA VO thanh cong. Da do
;;; 12/08/2026, dung thu lai.
;;;
;;; ---------------------------------------------------------------------------
;;; LUAT TUONG THICH — DOC TRUOC KHI SUA MOT DONG NAO
;;; ---------------------------------------------------------------------------
;;; File nay phai chay duoc tren: VinaCAD · AutoCAD · BricsCAD · ZWCAD ·
;;; GstarCAD. Nen no CHI dung AutoLISP LOI. Cam dung, du may ban thu thay chay:
;;;
;;;   vl-load-com  vl-string->list  vl-mkdir  vl-file-directory-p
;;;   vl-catch-all-apply  vl-catch-all-error-p  vlax-*  vla-*  vl-registry-*
;;;
;;; Ho vl-* / vlax-* la Visual LISP, gan voi ActiveX cua rieng Windows va cai
;;; dat khong day du o cac ban clone. Mot ham thieu la lenh chet giua chung voi
;;; thong bao "no function definition" — thu nguoi dung khong doc noi.
;;;
;;; He qua da thay trong thiet ke:
;;;   - KHONG tao thu muc con. Ghi thang mot file vao %TEMP% (bo vl-mkdir).
;;;   - Hex hoa ten bang (substr)+(ascii), khong dung vl-string->list.
;;;   - Khong bat loi bang vl-catch-all: kiem gia tri tra ve truoc khi dung.
;;;
;;; VI SAO TEN LAYER/BLOCK VIET DUOI DANG HEX: ten layer that cua ban ve co DAU
;;; CACH ("VYD - Wall") va co the co dau tieng Viet. Dinh dang la moi thuc the
;;; mot dong, cac truong cach nhau bang dau cach — mot ten co dau cach se lam
;;; lech toan bo dong. Hex hoa la duong duy nhat khong phai bay ra luat escape
;;; rieng roi cai lai o ca hai dau.
;;;
;;; CAI DAT: APPLOAD file nay roi them vao Startup Suite.
;;; Rieng VinaCAD: thu muc Support trong %APPDATA% KHONG tu nap acaddoc.lsp.
;;; ---------------------------------------------------------------------------

(setq DP:VERSION "0.1.0")

;;; --- Tien ich -------------------------------------------------------------

(defun dp:dxf (code elist) (cdr (assoc code elist)))

;;; ---------------------------------------------------------------------------
;;; MOC THOI GIAN — tat khi chay that, bat khi di tim cho nghen
;;; ---------------------------------------------------------------------------
;;; DP:DO = nil  -> khong ton mot loi goi nao (moi cho deu sau `if DP:DO`)
;;; DP:DO = T    -> gom gio theo bon tui, lenh DPDIAG bat len roi tat di
;;;
;;; VI SAO PHAI CO: ban 13/08/2026 chay 1,5 giay MOT doi tuong, trong khi do
;;; RIENG tung khau (ssname, entget, rtos, strcat, write-line) deu ra 0,1 ms
;;; cho ca doi tuong. Chenh 15.000 lan nghia la cho nghen nam o mot thu chi
;;; DPSYNC lam ma thuoc do khong lam — va doan tiep la phi thoi gian.
;;;
;;; VinaCAD KHONG hieu "\n" trong chuoi (do 13/08/2026): no ghi ra hai ky tu
;;; `\` va `n`. Moi cho xuong dong phai dung (chr 10).
(setq DP:NL (chr 10))
(setq DP:DO nil)
;; Ly do duong nhanh khong dung duoc. Rong = duong nhanh da chay.
(setq DP:VISAO "")

(defun dp:now () (getvar "DATE"))
(defun dp:giay (a b) (* 86400.0 (- b a)))

(defun dp:tui0 ()
  (setq DP:T_GET 0.0 DP:T_BLOCK 0.0 DP:T_WRITE 0.0 DP:N_GET 0 DP:N_WRITE 0)
)
(dp:tui0)

;; So thuc -> chuoi thap phan, KHONG phu thuoc don vi ban ve.
;;
;; PHAI dung (rtos x 2 8): mode 2 ep ve thap phan bat ke LUNITS. Goi (rtos x)
;; tran thi ban ve dat LUNITS = 4 (kien truc) se cho ra chuoi kieu 1'-3 1/2" —
;; Blender doc ra so 1, va sai lang le.
(defun dp:r (x)
  (if x (rtos (float x) 2 8) "0.0")
)

(defun dp:i (x) (itoa (fix x)))

;; Diem -> "x y z" (thieu Z thi coi la 0)
(defun dp:pt (p)
  (if p
    (strcat (dp:r (car p)) " " (dp:r (cadr p)) " "
            (dp:r (if (caddr p) (caddr p) 0.0)))
    "0.0 0.0 0.0"
  )
)

;; Vector day (code 210). Thieu thi la truc Z — truong hop thuong gap.
(defun dp:ext (e / v)
  (setq v (dp:dxf 210 e))
  (if v (dp:pt v) "0.0 0.0 1.0")
)

;; getvar an toan: bien he thong nay co the khong ton tai o ban clone, luc do
;; getvar tra nil va (fix nil) se lam chet lenh.
(defun dp:getvar (name dflt / v)
  (setq v (getvar name))
  (if v v dflt)
)

;; Ma dinh danh cua thuc the trong ban ve (DXF code 5), dang chuoi hex khong
;; dau cach nen ghi thang duoc.
;;
;; DAY LA CHIA KHOA CUA DONG BO TANG DAN VE SAU: handle song qua ca lan dong
;; file, nen Blender doi chieu duoc "object nay chinh la duong do lan truoc".
;; Ten thi doi duoc o ca hai dau, con handle thi khong.
;;
;; Thuc the trong DINH NGHIA block cung co handle rieng, nhung nhieu ban ve
;; cu khong sinh — nen phai co duong lui, va Blender phai coi "0" la khong co.
(defun dp:h (d / v)
  (setq v (dp:dxf 5 d))
  (if (and v (/= v "")) v "0")
)

;; Ban ghi mo rong: bam vao thuc the ngay TRUOC no.
;; Dau doc bo qua khoa la thay vi chet — do la ca muc dich cua no.
(defun dp:x (khoa giatri)
  (if (and khoa giatri)
    (dp:write (strcat "X " (dp:hex khoa) " " (dp:hex giatri)))
  )
)

;;; --- Hex hoa ten ----------------------------------------------------------

(setq DP:HEXD "0123456789ABCDEF")

(defun dp:byte2hex (b)
  (strcat (substr DP:HEXD (1+ (/ b 16)) 1)
          (substr DP:HEXD (1+ (rem b 16)) 1))
)

;; Ma ky tu -> cac byte UTF-8, roi hex. Chi xu ly toi U+FFFF: ten layer/block
;; khong bao gio cham toi day.
;;
;; CANH BAO CHUA DO: neu ban CAD tra ve BYTE cua bang ma cp1258 thay vi ma
;; Unicode cho chu co dau, ham nay boc no them mot lop UTF-8 va Blender doc ra
;; chu la (mojibake). HINH HOC KHONG BI ANH HUONG — chi ten collection xau di.
;; Chua co ban ve nao do that nen chua vá vong.
(defun dp:code2hex (c)
  (cond
    ((< c 128) (dp:byte2hex c))
    ((< c 2048)
     (strcat (dp:byte2hex (+ 192 (/ c 64)))
             (dp:byte2hex (+ 128 (rem c 64)))))
    (T
     (strcat (dp:byte2hex (+ 224 (/ c 4096)))
             (dp:byte2hex (+ 128 (rem (/ c 64) 64)))
             (dp:byte2hex (+ 128 (rem c 64)))))
  )
)

;; (substr)+(ascii) thay cho vl-string->list — xem LUAT TUONG THICH o dau file.
(defun dp:hex (s / r i n)
  (setq r "")
  (if s
    (progn
      (setq i 1 n (strlen s))
      (while (<= i n)
        (setq r (strcat r (dp:code2hex (ascii (substr s i 1)))))
        (setq i (1+ i))
      )
    )
  )
  ;; Chuoi rong van phai co gi do chiem cho, khong thi dong bi lech truong.
  (if (= r "") "00" r)
)

;;; --- Bang layer -----------------------------------------------------------

;; Chi so cua layer trong bang; them moi neu chua gap.
;; DP:LAYERS la danh sach (ten . chiso).
(defun dp:layer-idx (name / hit)
  (if (null name) (setq name "0"))
  (if (setq hit (assoc name DP:LAYERS))
    (cdr hit)
    (progn
      (setq DP:LAYERS (cons (cons name DP:NLAYER) DP:LAYERS))
      (dp:write (strcat "L " (dp:i DP:NLAYER) " " (dp:hex name) " "
                        (dp:i (dp:layer-color name))))
      (setq DP:NLAYER (1+ DP:NLAYER))
      (1- DP:NLAYER)
    )
  )
)

(defun dp:layer-color (name / tb c)
  (setq c 7)
  (if (setq tb (tblsearch "LAYER" name))
    (progn
      (setq c (dp:dxf 62 tb))
      ;; Mau AM = layer dang TAT. Blender chi can con so mau nen lay tri tuyet doi.
      (if c (setq c (abs c)) (setq c 7))
    )
  )
  c
)

;;; --- Ghi file -------------------------------------------------------------

;;; ---------------------------------------------------------------------------
;;; GHI FILE — GOM BO DEM, doc ky truoc khi "don gian hoa" lai
;;; ---------------------------------------------------------------------------
;;; DUNG GOI (write-line) MOT LAN CHO MOI DONG. Do ngay 13/08/2026 tren
;;; VinaCAD 2.0s: mot lan goi write-line ton 560 ms, an 355 tren 358 giay cua
;;; ca lenh. Cung phep ghi do, Python lam het 0,56 ms ke ca khi ep ghi thang
;;; xuong dia tung dong — chenh 1000 lan. He thong file vo can (da do rieng),
;;; bo thong dich LISP vo can (2,4 us moi vong lap), (entget) vo can
;;; (0,024 ms). Chi con write-line.
;;;
;;; Va gia cua no TI LE KICH THUOC FILE, khong phai kich thuoc dong: toc do
;;; tut dan dung theo do phinh cua file (14 KB -> 35 KB thi cham di 2,7 lan),
;;; tuc no ghi lai ca file moi lan goi. Nen cach chua khong phai "ghi nhanh
;;; hon" ma la "goi it lan hon".
;;;
;;; Gom DP:CHUNK dong thanh mot chuoi roi ghi mot lan. Voi ban ve 38.000 doi
;;; tuong: 38.000 lan goi -> 190 lan, uoc tinh tu "khong bao gio xong" xuong
;;; khoang 16 giay.
;;;
;;; VI SAO 200 CHU KHONG PHAI 2000: AutoLISP doi cu gioi han do dai chuoi, va
;;; khong ro VinaCAD con giu gioi han do khong. 200 dong la khoang 40 KB —
;;; du it lan goi de an, du nho de neu co gioi han thi cung kho cham toi. Con
;;; strcat thi cang gom to cang dat (moi lan noi la mot lan chep lai ca chuoi),
;;; nen to hon chua chac nhanh hon.
(setq DP:CHUNK 200)

(defun dp:buf0 () (setq DP:BUF "" DP:BUF_N 0 DP:CHUNKS '()))
(dp:buf0)

(defun dp:write (s)
  ;; MOI DONG deu ket bang DP:NL, ke ca dong cuoi goi.
  ;;
  ;; Truoc day noi dau xuong dong O GIUA cho tiet mot ky tu, vi (write-line)
  ;; tu them o cuoi. Nhung tu khi cac goi duoc NOI LAI voi nhau roi ghi mot
  ;; lan, cach do lam dong cuoi goi nay dinh lien dong dau goi sau — mot dong
  ;; rac giua file, cu 200 dong mot lan. Them deu thi noi kieu gi cung dung.
  (setq DP:BUF (strcat DP:BUF s DP:NL)
        DP:BUF_N (1+ DP:BUF_N))
  (if (>= DP:BUF_N DP:CHUNK)
    (setq DP:CHUNKS (cons DP:BUF DP:CHUNKS) DP:BUF "" DP:BUF_N 0)
  )
)

;; Do het bo dem xuong file. PHAI goi truoc (close), va phai goi CA khi lan
;; xuat bi bo giua chung — bo quen la nguoi dung mat sach phan chua do.
(defun dp:xa (f / t0)
  (if (> DP:BUF_N 0)
    (setq DP:CHUNKS (cons DP:BUF DP:CHUNKS) DP:BUF "" DP:BUF_N 0)
  )
  ;; -------------------------------------------------------------------
  ;; NOI HET LAI ROI GHI DUNG MOT LAN
  ;; -------------------------------------------------------------------
  ;; DPTIME3 ngay 13/08/2026 do duoc, va toi doc sot mat mot dong: lan ghi
  ;; DAU TIEN ton 0,000 giay, roi moi 0,055 -> 0,168 -> 0,371. Cac goi deu
  ;; bang nhau, nen gia KHONG dat theo kich thuoc noi dung — no dat theo SO
  ;; LAN da ghi vao cung mot file. Ghi 6 KB mot phat thi mien phi; phat thu
  ;; tu moi dat.
  ;;
  ;; Vay cach chua khong phai "gom to hon" ma la "goi it lan hon", va it
  ;; nhat co the la MOT.
  ;;
  ;; Van gom theo goi 200 dong o dp:write roi moi noi cac goi lai: strcat
  ;; chep lai ca chuoi moi lan noi, nen noi thang 38.000 dong vao mot chuoi
  ;; la O(n^2) tren chuoi dai — hang tram GB bi chep. Hai tang thi tang duoi
  ;; re, tang tren chi con vai tram phep noi.
  ;; DUNG (write-line), KHONG dung (princ). Da do ca hai tren VinaCAD
  ;; 13/08/2026 voi cung mot tuyen chon 296 doi tuong:
  ;;     write-line  ~38 s
  ;;     princ       88,88 s
  ;; princ nghe hop ly vi no di duong khac trong bo may CAD, nhung do xong
  ;; thi no cham hon gan gap ba. Dung thu lai.
  (setq t0 (dp:now))
  (write-line (apply 'strcat (reverse DP:CHUNKS)) f)
  (if DP:DO (setq DP:N_WRITE (1+ DP:N_WRITE)
                  DP:T_WRITE (+ DP:T_WRITE (dp:giay t0 (dp:now)))))
  (setq DP:CHUNKS '())
)

;;; --- Xuat mot thuc the ----------------------------------------------------
;;; Tra ve T neu da ghi mot dong, nil neu bo qua.

(defun dp:ent (e / d typ lay hnd line acc v n bulge flags sub t0)
  (if DP:DO (setq t0 (dp:now)))
  (setq d (entget e))
  (if DP:DO (setq DP:T_GET (+ DP:T_GET (dp:giay t0 (dp:now)))
                  DP:N_GET (1+ DP:N_GET)))
  (setq typ (dp:dxf 0 d))
  (setq lay (dp:layer-idx (dp:dxf 8 d)))
  (setq hnd (dp:h d))
  (cond

    ((= typ "LINE")
     (dp:write (strcat "E LINE " (dp:i lay) " " hnd " "
                       (dp:pt (dp:dxf 10 d)) " " (dp:pt (dp:dxf 11 d))))
     T)

    ((= typ "CIRCLE")
     (dp:write (strcat "E CIRCLE " (dp:i lay) " " hnd " "
                       (dp:pt (dp:dxf 10 d)) " " (dp:r (dp:dxf 40 d)) " "
                       (dp:ext d)))
     T)

    ((= typ "ARC")
     (dp:write (strcat "E ARC " (dp:i lay) " " hnd " "
                       (dp:pt (dp:dxf 10 d)) " " (dp:r (dp:dxf 40 d)) " "
                       (dp:r (dp:dxf 50 d)) " " (dp:r (dp:dxf 51 d)) " "
                       (dp:ext d)))
     T)

    ((= typ "POINT")
     (dp:write (strcat "E POINT " (dp:i lay) " " hnd " " (dp:pt (dp:dxf 10 d))))
     T)

    ((= typ "ELLIPSE")
     (dp:write (strcat "E ELLIPSE " (dp:i lay) " " hnd " "
                       (dp:pt (dp:dxf 10 d)) " "   ; tam
                       (dp:pt (dp:dxf 11 d)) " "   ; vector nua truc lon
                       (dp:r (dp:dxf 40 d)) " "    ; ti so truc nho / truc lon
                       (dp:r (dp:dxf 41 d)) " " (dp:r (dp:dxf 42 d)) " "
                       (dp:ext d)))
     T)

    ((= typ "LWPOLYLINE")
     ;; (assoc 10 d) chi lay duoc dinh DAU TIEN — phai duyet ca danh sach.
     ;; Bulge (code 42) KHONG xuat hien khi bang 0, nen phai bam theo tung cap:
     ;; gap 10 la mo mot dinh moi, bulge mac dinh 0. Ghep sai cho nay thi bulge
     ;; cua dinh nay nhay sang dinh khac va cung tron nam nham cho.
     (setq acc '() bulge 0.0 n 0)
     (foreach it d
       (cond
         ((= (car it) 10)
          (if (> n 0) (setq acc (cons bulge acc)))
          (setq acc (cons (cdr it) acc) bulge 0.0 n (1+ n)))
         ((= (car it) 42) (setq bulge (cdr it)))
       )
     )
     (if (> n 0) (setq acc (cons bulge acc)))
     (setq acc (reverse acc))
     (setq flags (dp:dxf 70 d))
     (if (null flags) (setq flags 0))
     (setq line (strcat "E LWPOL " (dp:i lay) " " hnd " " (dp:i flags) " "
                        (dp:r (if (dp:dxf 38 d) (dp:dxf 38 d) 0.0)) " "
                        (dp:ext d) " " (dp:i n)))
     ;; acc = (diem bulge diem bulge ...)
     (while acc
       (setq v (car acc) acc (cdr acc))
       (setq line (strcat line " " (dp:r (car v)) " " (dp:r (cadr v))
                          " " (dp:r (car acc))))
       (setq acc (cdr acc))
     )
     (dp:write line)
     T)

    ((= typ "POLYLINE")
     ;; POLYLINE nang: dinh nam o cac thuc the VERTEX theo sau, ket bang SEQEND.
     ;; Bo qua luoi (flag 16 = polygon mesh, 64 = polyface): v0.1 chi lam net.
     (setq flags (dp:dxf 70 d))
     (if (null flags) (setq flags 0))
     (if (or (= 16 (logand flags 16)) (= 64 (logand flags 64)))
       (progn (setq DP:SKIP (1+ DP:SKIP)) nil)
       (progn
         (setq acc '() n 0 sub (entnext e))
         (while (and sub (/= "SEQEND" (dp:dxf 0 (entget sub))))
           (setq v (entget sub))
           ;; Dinh dieu khien cua spline-fit (flag 16) khong phai net ve that.
           (if (/= 16 (logand (if (dp:dxf 70 v) (dp:dxf 70 v) 0) 16))
             (progn
               (setq acc (cons (list (dp:dxf 10 v)
                                     (if (dp:dxf 42 v) (dp:dxf 42 v) 0.0))
                               acc))
               (setq n (1+ n))
             )
           )
           (setq sub (entnext sub))
         )
         (setq acc (reverse acc))
         (setq line (strcat "E POLY " (dp:i lay) " " hnd " " (dp:i flags) " "
                            (dp:ext d) " " (dp:i n)))
         (foreach v acc
           (setq line (strcat line " " (dp:pt (car v)) " " (dp:r (cadr v))))
         )
         (dp:write line)
         T
       )
     ))

    ((= typ "INSERT")
     ;; Do RIENG khau nay: no la thu duy nhat trong dp:ent co the chay lau
     ;; khong gioi han — mot dinh nghia block co bao nhieu thuc the thi no
     ;; duyet bay nhieu, va con de quy vao block long nhau.
     (if DP:DO (setq t0 (dp:now)))
     (dp:block-def (dp:dxf 2 d))
     (if DP:DO (setq DP:T_BLOCK (+ DP:T_BLOCK (dp:giay t0 (dp:now)))))
     (dp:write (strcat "E INS " (dp:i lay) " " hnd " " (dp:hex (dp:dxf 2 d)) " "
                       (dp:pt (dp:dxf 10 d)) " "
                       (dp:r (if (dp:dxf 41 d) (dp:dxf 41 d) 1.0)) " "
                       (dp:r (if (dp:dxf 42 d) (dp:dxf 42 d) 1.0)) " "
                       (dp:r (if (dp:dxf 43 d) (dp:dxf 43 d) 1.0)) " "
                       (dp:r (if (dp:dxf 50 d) (dp:dxf 50 d) 0.0)) " "
                       (dp:ext d)))
     T)

    ;; Chua lam: TEXT/MTEXT/DIMENSION/HATCH/SPLINE/SOLID/3DFACE/proxy.
    ;;
    ;; Doi tuong proxy (loai bao ve la SO, vi du 4449) la cua addon khong co
    ;; tren may — (entget) khong cho ra hinh hoc co nghia. Nhanh cond nay nuot
    ;; chung mot cach co y; bo dem DP:SKIP dem lai de bao o cuoi lenh, vi cai
    ;; nguy hiem nhat cua chung la bien mat KHONG BAO GI.
    (T (setq DP:SKIP (1+ DP:SKIP)) nil)
  )
)

;;; --- Dinh nghia block -----------------------------------------------------

;;; ---------------------------------------------------------------------------
;;; DUYET DINH NGHIA BLOCK — doc ky truoc khi sua
;;; ---------------------------------------------------------------------------
;;; (entnext) CUA VinaCAD KHONG DUNG O CUOI DINH NGHIA BLOCK.
;;;
;;; Do ngay 13/08/2026 tren ban ve that: vong `(while e (dp:ent e) (setq e
;;; (entnext e)))` — cach viet chuan van thay o khap noi — chay tuot ra khoi
;;; chuoi cua block roi bo tiep qua CA CO SO DU LIEU 38.000 doi tuong. Bang
;;; chung: block `SC_CABINET_...` nuot 277 ban ghi va van tang, cac ban ghi do
;;; mang toa do ~827.000 cua ban ve chu khong phai toa do trong block, con so
;;; thuc the cap cao nhat thi dung yen. Va cang di xa (entnext) cang cham
;;; (1,7/giay tut xuong 0,85/giay), nen mot lenh DPSYNC khong bao gio ket thuc.
;;;
;;; HAI CAI CHAN, va can ca hai:
;;;
;;;   1. DUNG O "ENDBLK". Day la thuc the ket thuc chuoi cua moi dinh nghia
;;;      block, co trong dac ta DXF. Kiem no la cach dung dan; dua vao viec
;;;      (entnext) tra nil la dua vao mot hanh vi ma VinaCAD khong co.
;;;
;;;   2. CHAN CUNG DP:BLOCK_MAX. Neu ban CAD nao khong sinh ca ENDBLK thi cai
;;;      chan 1 vo dung, va loi quay lai y nguyen. Cham tran thi DEM lai roi
;;;      bao ra — khong duoc im lang, vi im lang chinh la thu da lam mat ca
;;;      buoi sang nay.
(setq DP:BLOCK_MAX 20000)

(defun dp:block-def (name / tb e typ dem)
  (if (and name (not (member name DP:BLOCKS)))
    (progn
      ;; Danh dau TRUOC khi duyet: mot ban ve hong co the co block tu chua chinh
      ;; no, va vong de quy do se treo CAD ma khong bao loi gi.
      (setq DP:BLOCKS (cons name DP:BLOCKS))
      (if (setq tb (tblsearch "BLOCK" name))
        (progn
          (dp:write (strcat "B " (dp:hex name) " " (dp:pt (dp:dxf 10 tb))))
          (setq e (dp:dxf -2 tb) dem 0)
          (while (and e (< dem DP:BLOCK_MAX))
            (setq typ (dp:dxf 0 (entget e)))
            (if (= typ "ENDBLK")
              (setq e nil)
              (progn
                (dp:ent e)
                (setq e (entnext e) dem (1+ dem))
              )
            )
          )
          (if (>= dem DP:BLOCK_MAX)
            (setq DP:TRAN (cons name DP:TRAN))
          )
          (dp:write "BEND")
        )
      )
    )
  )
)

;;; --- Hop thoai xac nhan ---------------------------------------------------
;;; Quy trinh nguoi dung: go DPSYNC -> chon doi tuong -> hop thoai -> OK.
;;;
;;; VI SAO LA DCL CHU KHONG PHAI (alert): alert chi co mot nut OK, khong co
;;; duong lui. Chon nham 30.000 doi tuong ma khong huy duoc thi phai ngoi cho
;;; het lan xuat.
;;;
;;; VI SAO KHONG PHAI (initget)+(getkword): do la hoi tren DONG LENH, ma dong
;;; lenh cua VinaCAD dang bi an — nguoi dung se thay CAD dung im khong ly do.
;;;
;;; VI SAO GHI FILE .dcl RA %TEMP% LUC CHAY: load_dialog tim file theo duong
;;; support cua tung phan mem, ma nam phan mem thi nam duong khac nhau. Tu ghi
;;; ra roi nap bang duong TUYET DOI thi khong phai lo chuyen do o dau ca.
(defun dp:dcl-file (/ p f)
  (setq p (strcat (dp:tmp-dir) "\\dp_cadsync.dcl"))
  (setq f (open p "w"))
  (if f
    (progn
      (write-line "dpsync : dialog { label = \"DP CAD Sync\";" f)
      (write-line "  : text { key = \"d1\"; }" f)
      (write-line "  : text { key = \"d2\"; }" f)
      (write-line "  spacer;" f)
      (write-line "  ok_cancel;" f)
      (write-line "}" f)
      (close f)
      p
    )
  )
)

;; Tra ve T neu nguoi dung bam OK.
;;
;; (sslength) la con so da co san trong tap chon, khong phai phep dem — no
;; khong duyet qua doi tuong nao ca.
;;
;; CO BIEN `hien` RIENG, khong suy tu `ok`: "nguoi dung bam Cancel" va "hop
;; thoai khong mo len duoc" deu cho ok = nil. Gop hai cai lam mot thi tren ban
;; CAD khong nap noi DCL, lenh se im lang khong lam gi va trong y het nhu vua
;; bi huy — kieu loi khong bao gio tu to giac.
(defun dp:hoi-2 (dong1 dong2 / p id ok hien)
  (setq ok nil hien nil)
  (setq p (dp:dcl-file))
  (if p
    (progn
      (setq id (load_dialog p))
      ;; load_dialog tra so AM khi that bai. Khong kiem thi new_dialog do vao
      ;; mot id vo nghia va treo.
      (if (and id (>= id 0))
        (progn
          (if (new_dialog "dpsync" id)
            (progn
              (setq hien T)
              (set_tile "d1" dong1)
              (set_tile "d2" dong2)
              (setq ok (= 1 (start_dialog)))
            )
          )
          (unload_dialog id)
        )
      )
    )
  )
  ;; DUONG LUI: ban CAD nao khong nap noi DCL thi van phai chay duoc. alert
  ;; khong co nut Cancel — bam OK la di tiep. Tha vay con hon lenh chet im.
  (if (null hien)
    (progn
      (alert (strcat dong1 DP:NL dong2))
      (setq ok T)
    )
  )
  ok
)

(defun dp:hoi (n)
  (dp:hoi-2 (strcat "Send " (itoa n) " objects to Blender?")
            "Blender updates itself when this finishes.")
)

;;; --- Duong ra -------------------------------------------------------------

;; Ghi THANG vao %TEMP%, khong tao thu muc con: tao thu muc doi vl-mkdir, ma
;; ham do khong chac co o ZWCAD/GstarCAD. Mot file thi khong can thu muc.
(defun dp:tmp-dir (/ tmp)
  (setq tmp (getenv "TEMP"))
  (if (or (null tmp) (= tmp "")) (setq tmp (getenv "TMP")))
  (if (or (null tmp) (= tmp "")) (setq tmp "C:\\Windows\\Temp"))
  tmp
)

;; Duong dan nay la GIAO UOC voi nua Blender — doi o day thi phai doi ca
;; TEN_FILE trong Addon/dp_cadsyncblender/giao_thuc.py.
(defun dp:out-path ()
  (strcat (dp:tmp-dir) "\\dp_cadsync_scene.cadblend")
)

;;; --- Than lenh ------------------------------------------------------------

(setq DP:CAP nil)

(defun dp:run (ss / path n i e ok t_run bao f dxf)
  (setq n (sslength ss))
  (setq t_run (dp:now))
  ;; HOI TRUOC KHI LAM BAT CU VIEC GI: bam Cancel o hop thoai la khong mo file,
  ;; khong ghi mot byte nao. Neu mo file truoc roi moi hoi thi lan huy van de
  ;; lai mot file rong de len ban cu, va Blender co the doc phai no.
  (if (not (dp:hoi n))
    (princ)
    (progn

  ;; ---------------------------------------------------------------------
  ;; KHONG DIEU KHIEN LENH CUA CAD TRONG DUONG CHAY CHINH
  ;; ---------------------------------------------------------------------
  ;; Da thu goi `-WBLOCK` bang (command ...) de bo xuat C++ cua CAD ghi file.
  ;; Ngay 13/08/2026 no lam VinaCAD dung lai hoi "Enter name of output file"
  ;; ngay giua lenh: lenh khoi dong duoc, nhung THU TU CAC CAU HOI khac voi
  ;; chuoi tham so gui kem, nen CAD ngoi cho nguoi go.
  ;;
  ;; Do la kieu hong khong duoc phep co trong duong chay chinh: nguoi dung
  ;; dang lam viec bong nhien bi mot lenh la chan duong, va khong hieu vi sao.
  ;; Moi ban CAD lai hoi mot kieu, ma toi khong co may cua bon phan mem kia de
  ;; do — nen KHONG doan tren may khach.
  ;;
  ;; Phan do duong xuat da chuyen sang CAD/dp_chan_doan.lsp (lenh DPROUTE),
  ;; chi nap khi co chu dinh. Duong chay chinh di thang bo ghi cua chinh minh:
  ;; cham, nhung khong bao gio lam nguoi dung mac ket.
  (dp:run-cham ss n t_run)
    )
  )
  (princ)
)

;;; DUONG CU — chi chay khi phan mem CAD khong chiu ghi DXF.
;;;
;;; Cham, va cham theo BINH PHUONG so doi tuong: mot phong khoang 35 giay, ca
;;; ban ve thi khong bao gio xong. Giu lai vi no khong phu thuoc lenh nao cua
;;; CAD ca — con hon la khong chay duoc gi.
(defun dp:run-cham (ss n t_run / path i e ok bao f)
  (setq DP:LAYERS '() DP:NLAYER 0 DP:BLOCKS '() DP:SKIP 0 DP:TRAN '())
  (dp:buf0)
  (setq path (dp:out-path))
  (setq DP:FILE (open path "w"))
  (if (null DP:FILE)
    (alert (strcat "DP_CadSync: cannot write the export file." DP:NL path))
    (progn
      (dp:write "DPCAD 1")
      (dp:write (strcat "VER " DP:VERSION))
      (dp:write (strcat "CAD " (dp:hex (dp:getvar "ACADVER" "?"))))
      (dp:write (strcat "DWG " (dp:hex (strcat (dp:getvar "DWGPREFIX" "")
                                               (dp:getvar "DWGNAME" "")))))
      ;; INSUNITS ghi ra chi de xem. Blender KHONG duoc suy ti le tu no: tren
      ;; ban ve that cua Ducphan no khai 1 (inch) trong khi don vi la mm.
      (dp:write (strcat "INSUNITS " (dp:i (dp:getvar "INSUNITS" 0))))

      ;; Khong in tien trinh ra dong lenh: dong lenh cua VinaCAD dang bi an nen
      ;; khong ai doc duoc, ma moi lan (princ) van ton mot vong ve lai man hinh.
      ;;
      ;; DP:CAP: chan so doi tuong, chi dung khi di do (DPDIAG dat no). Chay
      ;; that thi no la nil va vong lap khong bi cat.
      (if (and DP:CAP (> n DP:CAP)) (setq n DP:CAP))
      (setq i 0 ok 0)
      (while (< i n)
        (setq e (ssname ss i))
        (if (dp:ent e) (setq ok (1+ ok)))
        (setq i (1+ i))
      )

      ;; DONG "END" LA DAU HIEU GHI XONG, khong phai trang tri. Blender canh
      ;; file nay bang bo dem gio va co the doc dung luc CAD dang viet do dang
      ;; — no chi nhan file nao KET bang dong nay. Doi/bo dong nay la Blender
      ;; im lang khong bao gio nhan duoc gi nua.
      (dp:write (strcat "END " (dp:i ok)))
      ;; PHAI xa bo dem TRUOC khi dong file. Bo dong nay thi file ra rong hoac
      ;; cut duoi, va cai thieu lai chinh la dong END — Blender se cho mai.
      (dp:xa DP:FILE)
      (close DP:FILE)
      (setq DP:FILE nil)

      ;; PHAI dung (alert), KHONG dung (princ): dong lenh cua VinaCAD dang bi
      ;; an, nen moi thu in ra bang princ nguoi dung khong he thay.
      ;;
      ;; Xuong dong bang (chr 10), KHONG dung "\n": VinaCAD khong hieu day
      ;; thoat do va se hien ra hai ky tu `\` va `n` ngay giua cau.
      (setq bao (strcat "DP_CadSync " DP:VERSION DP:NL DP:NL
                        "Sent    : " (itoa ok) " objects" DP:NL
                        "Skipped : " (itoa DP:SKIP)
                        " (text / dimensions / hatch / splines / proxies)"
                        DP:NL
                        "Blocks  : " (itoa (length DP:BLOCKS)) DP:NL
                        "Time    : " (rtos (dp:giay t_run (dp:now)) 2 2)
                        " s for " (itoa n) " objects"))


      ;; Cham tran khi duyet block = chuoi thuc the cua block khong ket bang
      ;; ENDBLK tren ban CAD nay. Phai NOI RA: hinh hoc lay ve se thieu, va
      ;; im lang o dung cho nay la thu da lam mat ca buoi sang 13/08/2026.
      (if DP:TRAN
        (setq bao (strcat bao DP:NL DP:NL
                          "!! " (itoa (length DP:TRAN)) " block(s) hit the "
                          (itoa DP:BLOCK_MAX) " entity limit." DP:NL
                          "   This CAD does not emit ENDBLK - geometry will "
                          "be missing." DP:NL
                          "   Please report this to the author."))
      )

      (if DP:DO
        (progn
          (setq bao
            (strcat bao DP:NL DP:NL "=== TIMING ===" DP:NL
              "entget    " (rtos DP:T_GET 2 3) " s / " (itoa DP:N_GET)
              " calls = " (rtos (if (> DP:N_GET 0)
                                  (/ (* 1000.0 DP:T_GET) DP:N_GET) 0.0) 2 3)
              " ms" DP:NL
              "block-def " (rtos DP:T_BLOCK 2 3) " s" DP:NL
              "write-line" (rtos DP:T_WRITE 2 3) " s / " (itoa DP:N_WRITE)
              " calls = " (rtos (if (> DP:N_WRITE 0)
                                  (/ (* 1000.0 DP:T_WRITE) DP:N_WRITE) 0.0) 2 3)
              " ms" DP:NL
              "rest      " (rtos (- (dp:giay t_run (dp:now))
                                    (+ DP:T_GET DP:T_BLOCK DP:T_WRITE)) 2 3)
              " s"))
          ;; Ten file KHAC dp_dotocdo.txt: file kia dang bi mot tien trinh khac
          ;; giu (do 13/08/2026 — VinaCAD da tat ma van khoa), nen ghi vao do
          ;; se that bai lang le va toi lai doc phai ket qua cu.
          (setq f (open (strcat (dp:tmp-dir) "\\dp_diag.txt") "a"))
          (if f (progn (write-line bao f) (close f)))
        )
      )
      (alert bao)
    )
  )
  (princ)
)

;;; ---------------------------------------------------------------------------
;;; LENH CHINH
;;; ---------------------------------------------------------------------------
;;; Quy trinh cua nguoi dung chi co bay nhieu:
;;;   go DPSYNC  ->  chon doi tuong  ->  hop thoai  ->  OK  ->  Blender tu cap nhat.
;;;
;;; CHI XUAT PHAN DA CHON. Khong co duong nao cham vao ca ban ve:
;;;   - khong (ssget "_X"): tren ban ve that cua Ducphan la 38.000 doi tuong,
;;;     quet het vua lau vua khong phai thu nguoi dung muon;
;;;   - khong co nhanh "Enter = toan bo" — lo tay mot cai la ngoi cho.
;;;
;;; Khong bam gi ben Blender ca: nua Blender canh file bang bo dem gio (xem
;;; theo_doi.py). AutoLISP khong mo duoc socket nen khong goi sang duoc, va do
;;; cung la ly do file phai ket bang dong "END" — Blender lay dong do lam dau
;;; hieu "da ghi xong", neu khong no doc nham mot file dang viet do dang.
(defun C:DPSYNC (/ ss)
  ;; "_I" = tap chon DA CO san truoc khi go lenh (pickfirst). Nguoi dung quen
  ;; kieo chuot chon roi moi go lenh la thoi quen thuong gap; khong bat cai nay
  ;; thi CAD vut tap chon do di va bat ho chon lai tu dau.
  ;;
  ;; PICKFIRST tat thi "_I" tra nil — luc do roi xuong (ssget) hoi binh thuong.
  (setq ss (ssget "_I"))
  (if (null ss)
    (progn
      (princ (strcat DP:NL "Select objects to send to Blender: "))
      (setq ss (ssget))
    )
  )
  (if ss
    (dp:run ss)
    (alert "DP_CadSync: nothing selected."))
  (princ)
)

;;; ---------------------------------------------------------------------------
;;; DUNG THEM LENH NAO NUA
;;; ---------------------------------------------------------------------------
;;; File nay chi duoc phep dinh nghia MOT lenh: DPSYNC.
;;;
;;; Ngay 13/08/2026 co luc no de ra bay lenh (DPSYNC, DPSYNCW, DPDIAG, DPTIME1,
;;; DPTIME2, DPTIME3, DPPROBE) va Ducphan hoi thang "sao lam gi lam lam lenh
;;; the". Dung. Sau la thuoc do di tim cho nghen — do la viec cua toi, khong
;;; phai thu de lai trong CAD cua nguoi dung.
;;;
;;; Thuoc do nam o CAD/dp_chan_doan.lsp, KHONG chep sang may nguoi dung. Bo do
;;; van con day du de mo lai khi can.
;;;
;;; DPSYNCW da bo: go DPSYNC roi quet cua so la ra dung ket qua do. Mot lenh
;;; lam duoc viec cua hai thi lenh thu hai chi la mot thu de nho nham.
(alert (strcat "DP_CadSync " DP:VERSION " loaded." DP:NL DP:NL
               "One command:  DPSYNC" DP:NL DP:NL
               "Type DPSYNC, select objects, click OK." DP:NL
               "Blender updates itself - nothing to click there."))
(princ)
