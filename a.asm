
; === MaiDOS ===

welcome:
    call App.clear      ; BIOSの画面をクリア

    mov si, Value.message.welcome   ; 起動メッセージ
    call Io.print_string
    call Io.print_newline       ; 改行して見やすくする


; === シェル ===

Shell.start:
    call Io.print_newline        ; 改行
    mov si, Value.prompt         ; シェルのプロンプト文字列を表示
    call Io.print_string

    mov bx, 0   ; 入力バッファのインデックスを初期化
    xor dh, dh  ; Space入力フラグを初期化

Shell.mainloop:
    call Io.get_key     ; ユーザー入力取得

    cmp al, 0x0D        ; Enterキーかチェック (0x0D = CR)
    je Shell.execute    ; 押されたらコマンド実行

    cmp al, ' '                 ; Spaceキーかチェック (0x0D = CR)
    je Shell.mainloop.space     ; 押されたら引数解析

    cmp al, 0x08                ; Backspaceキーかチェック (0x08 = BS)
    je Io.backspace

    call Io.print_char              ; 入力文字を画面に表示
    mov [Buffer.input + bx], al     ; 入力をバッファに追加
    inc bx                          ; バッファを指すbxを進める

    jmp Shell.mainloop              ; ループ継続

Shell.mainloop.space:
    call Io.print_char              ; 入力文字を画面に表示

    cmp dh, 0                       ; Spaceがすでに入力されたかどうか
    jne Shell.mainloop.space_twice

    mov byte [Buffer.input + bx], 0     ; Null文字をバッファに追加
    inc bx                              ; バッファを指すbxを進める
    inc dh                              ; Space入力フラグを立てる
    jmp Shell.mainloop                  ; ループ継続

Shell.mainloop.space_twice:             ; 2回目以降に押されたSpaceの処理
    mov byte [Buffer.input + bx], ' '   ; Space文字をバッファに追加
    inc bx                              ; バッファを指すbxを進める
    jmp Shell.mainloop                  ; ループ継続

Shell.execute:
    ; === シェルコマンドを実行 ===

    cmp bx, 0       ; 入力が空か
    je Shell.start  ; プロンプト開始へ戻る

    mov byte [Buffer.input + bx], 0     ; 文字列終端を追加
    call Io.print_string                ; 改行

    mov si, Buffer.input        ; アプリ起動
    call Kernel.launch_app

    call Io.print_newline       ; 2回改行

    jmp Shell.start         ; プロンプト開始へ戻る


; === カーネル ===

Kernel.launch_app:
    ; == アプリを起動 ==

    mov si, Buffer.input        ; 表示
    mov di, Value.command.echo
    call String.compare         ; 入力とコマンド名"echo"が同じか比較
    cmp ax, 1                   ; ならば実行する
    je App.echo

    mov si, Buffer.input        ; 画面クリア
    mov di, Value.command.clear
    call String.compare         ; 入力とコマンド名"clear"が同じか比較
    cmp ax, 1                   ; ならば実行する
    je App.clear

    mov si, Buffer.input        ; ヘルプ
    mov di, Value.command.help
    call String.compare         ; 入力とコマンド名"help"が同じか比較
    cmp ax, 1                   ; ならば実行する
    je App.help

    mov si, Buffer.input            ; 終了
    mov di, Value.command.shutdown
    call String.compare             ; 入力とコマンド名"shutdown"が同じか比較
    cmp ax, 1                       ; ならば実行する
    je App.shutdown

    mov si, Value.message.error     ; マッチしない場合
    call Io.print_string
    mov si, Buffer.input        ; エラーメッセージを出力
    call Io.print_string

Kernel.app_success:
    ; == プロセス終了(成功) ==
    ret


; === アプリ ===

App.echo:
    ; == 引数を表示 ==
    mov si, Buffer.input
    add si, 5
    call Io.print_string
    jmp Kernel.app_success

App.clear:
    ; == 画面をクリア ==
    mov ax, 0x07c0
    mov ds, ax
    mov ah, 0x0
    mov al, 0x3
    int 0x10            ; BIOS コール
    jmp Kernel.app_success

App.help:
    ; == ヘルプを表示 ==
    mov si, Value.message.help
    call Io.print_string
    jmp Kernel.app_success

App.shutdown:
    ;  == シャットダウン ==
    mov ax, 0x5307      ; APM機能：Set Power State（電源状態の設定）
    mov bx, 1           ; デバイス番号（通常は1を指定、全デバイスに対して）
    mov cx, 3           ; 電源状態 3：シャットダウン（完全に電源オフする状態）
    int 15h             ; BIOS割り込み15hを呼び出してAPM関数を実行


; === 文字列操作 ===

String.compare:         ; 文字列比較
    mov cx, 20          ; 最大20文字比較
String.compare.loop:
    mov al, [si]        ; SI: 入力文字列
    mov ah, [di]        ; DI: 比較対象
    cmp al, ah
    jne String.compare.no_match     ; 違えば終了

    test al, al
    jz String.compare.match         ; 両方の文字列が Null文字に到達したら一致

    inc si
    inc di
    jmp String.compare.loop         ; 比較ループ継続
String.compare.match:
    mov ax, 1
    ret
String.compare.no_match:    ; 違えばfalseで終了
    xor ax, ax
    ret


; === 入出力処理(IO) ===

Io.get_key:
    mov ah, 0x00    ; 入力
    int 0x16        ; BIOS コール
    ret

Io.print_char:
    mov ah, 0x0E    ; 出力
    int 0x10        ; BIOS コール
    ret

Io.print_string:
    lodsb                   ; 文字をロード
    or al, al               ; Null文字ならば終了
    jz Io.print_string.done
    call Io.print_char
    jmp Io.print_string     ; 次の文字へ
Io.print_string.done:
    ret

Io.print_newline:          ; 改行を出力
    mov si, Value.newline
    call Io.print_string
    ret

Io.backspace:
    cmp bx, 0
    jz Shell.mainloop   ; 何も入力されていなければスキップ
    dec bx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10            ; カーソルを戻す
    mov al, ' '
    int 0x10            ; 空白を上書き
    mov al, 0x08
    int 0x10            ; カーソルを再び戻す
    jmp Shell.mainloop


; === データ ===

Value.prompt    db '[sh]> ', 0
Value.newline   db 0x0D, 0x0A, 0

; コマンド群
Value.command.echo    db 'echo', 0
Value.command.clear   db 'clear', 0
Value.command.help    db 'help', 0
Value.command.shutdown    db 'shutdown', 0

; メッセージ群
Value.message.welcome:
    db 'Welcome back to computer, comrade!', 0
Value.message.error:
    db 'Error! unknown command: ', 0
Value.message.help:
    db 'MaiDOS v0.2.5', 0x0D, 0x0A, \
    'Created for anarchists with love and solidarity', 0x0D, 0x0A, \
    'Apps: echo, clear, help, shutdown', 0

; コマンド入力受け付け用バッファ領域
Buffer.input times 16 db 0

; 残りのバイト列を埋める
times 510-($-$$) db 0
; ブートセクタの印
db 0x55
db 0xAA