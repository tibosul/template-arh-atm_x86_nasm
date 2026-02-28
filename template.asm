BITS 32

%define sys_exit 0x01
%define sys_write 0x04
%define sys_read 0x03
%define sys_creat 0x08
%define sys_open 0x05
%define sys_close 0x06
%define sys_lseek 0x13

%define stdin 0x00
%define stdout 0x01
%define stderr 0x02

%define read_only 0x00
%define write_only 0x01
%define read_write 0x02

%define seek_start 0x00
%define seek_current 0x01
%define seek_end 0x02

%define file_mode 0644

;------------------------------- FILE NAVIGATION --------------------------

%macro rewind_file 0                                 ; moves file pointer to start
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, sys_lseek
    mov ebx, [fd_in]                                ; file descriptor
    mov ecx, 0                                      ; offset 0
    mov edx, seek_start                             ; move to the beginning of the file
    int 0x80
    
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: rewind_file                      ; moves the file pointer to the beginning of the file

%macro go_back_in_file 1                             ; %1 = number of bytes to go back
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, sys_lseek
    mov ebx, [fd_in]                                ; file descriptor
    mov ecx, -%1                                    ; negative offset (going back)
    mov edx, seek_current                           ; from the current position
    int 0x80
    
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: go_back_in_file 10               ; goes back 10 bytes in the file

%macro go_to_end_of_file 0                           ; moves file pointer to end
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, sys_lseek
    mov ebx, [fd_in]                                ; file descriptor
    xor ecx, ecx                                    ; offset 0
    mov edx, seek_end                               ; from the end of the file
    int 0x80
    
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: go_to_end_of_file                ; moves the file pointer to the end of the file

%macro advance_in_file 1                             ; %1 = number of bytes
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, sys_lseek
    mov ebx, [fd_in]                                ; file descriptor
    mov ecx, %1                                     ; positive offset (advancing)
    mov edx, seek_current                           ; from the current position
    int 0x80
    
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: advance_in_file 20               ; advances 20 bytes in the file

;-----------------------------------------------------------------
; FILE WRITING MACROS
;-----------------------------------------------------------------

%macro print_to_file 2                               ; %1 = buffer, %2 = number of bytes
    push eax
    push ebx
    push ecx
    push edx

    mov eax, sys_write
    mov ebx, [fd_out]                               ; file descriptor
    mov ecx, %1                                     ; buffer
    mov edx, %2                                     ; number of bytes
    int 0x80

    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: print_to_file message, message_len ; writes the message to the output file

%macro print_char_to_file 1                              ; %1 = character
    push eax
    push ebx
    push ecx
    push edx

    mov byte [char_buffer], %1                      ; put the character in the buffer
    mov eax, sys_write
    mov ebx, [fd_out]                               ; file descriptor
    mov ecx, char_buffer                            ; buffer with the character
    mov edx, 1                                      ; write a single character
    int 0x80

    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: print_char_to_file 'A'           ; writes character 'A' to the output file

%macro print_newline_to_file 0                     ; write newline to file
    print_to_file newline, 1
%endmacro
; Example usage: print_newline_to_file            ; writes a newline character to the output file

%macro print_space_to_file 0                       ; write space to file
    print_to_file space, 1
%endmacro
; Example usage: print_space_to_file              ; writes a space character to the output file

%macro print_number_in_base_to_file 2                ; %1 = number, %2 = base (2-16)
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov eax, %1                                     ; number to convert
    mov ebx, %2                                     ; base
    
    ; Buffer for digits (max 32 digits for base 2)
    sub esp, 32                                     ; allocate space on stack
    mov edi, esp                                    ; edi = pointer to buffer
    add edi, 31                                     ; start from the end
    mov byte [edi], 0                               ; terminator
    dec edi
    
    ; Counter for digits
    xor ecx, ecx
    
    ; Special case for 0
    test eax, eax
    jnz %%convert_loop
    mov byte [edi], '0'
    mov ecx, 1
    jmp %%print_result
    
%%convert_loop:
    test eax, eax                                   ; any digits left?
    jz %%print_result
    
    xor edx, edx
    div ebx                                         ; eax = quotient, edx = remainder (digit)
    
    ; Convert digit to character
    cmp dl, 10
    jl %%digit
    add dl, 'A' - 10                                ; A-F for 10-15
    jmp %%store_digit
%%digit:
    add dl, '0'                                     ; 0-9 for 0-9
    
%%store_digit:
    mov [edi], dl
    dec edi
    inc ecx
    jmp %%convert_loop
    
%%print_result:
    ; edi+1 points to the first digit, ecx = number of digits
    inc edi
    
    ; Write to file
    mov eax, sys_write
    mov ebx, [fd_out]
    push ecx                                        ; save number of digits
    mov ecx, edi                                    ; buffer
    pop edx                                         ; length
    int 0x80
    
    add esp, 32                                     ; free the space on the stack
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: print_number_in_base_to_file 255, 16 ; writes 'FF' to the output file

%macro print_decimal_to_file 1                     ; write a decimal number (%1) to file
    print_number_in_base_to_file %1, 10
%endmacro
; Example usage: print_decimal_to_file 245         ; writes the decimal number to the output file

%macro print_hex_string_to_file 2                       ; %1 = buffer, %2 = length
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov esi, %1                                     ; pointer to input buffer
    mov ecx, %2                                     ; length of the string
    
%%hex_loop:
    test ecx, ecx                                   ; check if there are more bytes
    jz %%done
    
    movzx eax, byte [esi]                           ; load a byte
    
    ; Convert high nibble (first 4 bits)
    mov edx, eax
    shr edx, 4                                      ; shift right by 4 positions
    and edx, 0x0F                                   ; keep only the last 4 bits
    
    ; Convert to hexadecimal character
    cmp edx, 10
    jl %%high_digit
    add edx, 'a' - 10                               ; a-f for 10-15
    jmp %%print_high
%%high_digit:
    add edx, '0'                                    ; 0-9 for 0-9
    
%%print_high:
    mov [hex_char], dl
    push ecx                                        ; save counter
    
    mov eax, sys_write
    mov ebx, [fd_out]
    mov ecx, hex_char
    mov edx, 1
    int 0x80
    
    pop ecx                                         ; restore counter
    
    ; Convert low nibble (last 4 bits)
    movzx eax, byte [esi]
    and eax, 0x0F                                   ; keep only the last 4 bits
    
    ; Convert to hexadecimal character
    cmp eax, 10
    jl %%low_digit
    add eax, 'a' - 10                               ; a-f for 10-15
    jmp %%print_low
%%low_digit:
    add eax, '0'                                    ; 0-9 for 0-9
    
%%print_low:
    mov [hex_char], al
    push ecx                                        ; save counter
    
    mov eax, sys_write
    mov ebx, [fd_out]
    mov ecx, hex_char
    mov edx, 1
    int 0x80
    
    pop ecx                                         ; restore counter
    
    ; Optional: add space between bytes
    push ecx
    ; print_space_to_file
    pop ecx
    
    inc esi                                         ; move to the next byte
    dec ecx                                         ; decrement the counter
    jmp %%hex_loop
    
%%done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: print_hex_string_to_file buffer, 10 ; writes 10 bytes from buffer in hex format


%macro print_binary_string_to_file 2                 ; %1 = buffer, %2 = length
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov esi, %1                                     ; pointer to input buffer
    mov edi, %2                                     ; length of the string
    
%%byte_loop:
    test edi, edi                                   ; check if we have more bytes
    jz %%done
    
    movzx eax, byte [esi]                           ; load a byte
    mov ecx, 8                                      ; 8 bits per byte
    
%%bit_loop:
    push ecx                                        ; save bit counter
    push edi                                        ; save byte counter
    
    ; Test the most significant bit (bit 7)
    test eax, 0x80                                  ; 0x80 = 10000000b
    jz %%print_zero
    
    ; Bit is 1
    mov byte [hex_char], '1'
    jmp %%print_bit
    
%%print_zero:
    ; Bit is 0
    mov byte [hex_char], '0'
    
%%print_bit:
    push eax                                        ; save value
    
    mov eax, sys_write
    mov ebx, [fd_out]
    mov ecx, hex_char
    mov edx, 1
    int 0x80
    
    pop eax                                         ; restore value
    pop edi                                         ; restore byte counter
    pop ecx                                         ; restore bit counter
    
    ; Shift left for next bit
    shl eax, 1
    
    dec ecx                                         ; decrement bit counter
    jnz %%bit_loop                                  ; continue with next bits
    
    ; Optional: add space between bytes
    push edi
    ; print_space_to_file
    pop edi
    
    inc esi                                         ; move to next byte
    dec edi                                         ; decrement byte counter
    jmp %%byte_loop
    
%%done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: print_binary_string_to_file buffer, 3 ; writes 3 bytes from buffer in binary (MSB first)

%macro print_binary_string_to_file_lsb 2            ; %1 = buffer, %2 = length
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov esi, %1                                     ; pointer to input buffer
    mov edi, %2                                     ; length of the string
    
%%byte_loop:
    test edi, edi                                   ; check if we have more bytes
    jz %%done
    
    movzx eax, byte [esi]                           ; load a byte
    mov ecx, 8                                      ; 8 bits per byte
    
%%bit_loop:
    push ecx                                        ; save bit counter
    push edi                                        ; save byte counter
    push eax                                        ; save value
    
    ; Test the least significant bit (bit 0)
    and eax, 0x01                                   ; 0x01 = 00000001b
    add al, '0'                                     ; convert 0/1 to '0'/'1'
    mov [hex_char], al
    
    mov eax, sys_write
    mov ebx, [fd_out]
    mov ecx, hex_char
    mov edx, 1
    int 0x80
    
    pop eax                                         ; restore value
    pop edi                                         ; restore byte counter
    pop ecx                                         ; restore bit counter
    
    ; Shift right for next bit
    shr eax, 1
    
    dec ecx                                         ; decrement bit counter
    jnz %%bit_loop                                  ; continue with next bits
    
    ; Optional: add space between bytes
    push edi
    ; print_space_to_file
    pop edi
    
    inc esi                                         ; move to next byte
    dec edi                                         ; decrement byte counter
    jmp %%byte_loop
    
%%done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: print_binary_string_to_file_lsb buffer, 3 ; writes 3 bytes from buffer in binary (LSB first)

;-----------------------------------------------------------------
; FILE READING MACROS
;-----------------------------------------------------------------

%macro read_from_file 2                              ; %1 = buffer, %2 = max bytes
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, sys_read
    mov ebx, [fd_in]                                ; file descriptor
    mov ecx, %1                                     ; buffer
    mov edx, %2                                     ; max bytes to read
    int 0x80
    mov [bytes_read], eax                           ; save how many bytes were actually read

    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: read_from_file buffer, 256      ; reads up to 256 bytes from input file to buffer

%macro read_number_from_file 0                       ; reads a signed integer from file
    push eax
    push ebx
    push ecx
    push edx
    push esi
    
    ; Read the number until space/newline
    read_until_space_from_file file_buffer, 256
    
    ; Check if it's negative
    mov esi, file_buffer
    cmp byte [esi], '-'
    jne %%positive_number
    
    ; It's negative, skip the minus sign
    inc esi
    buffer_to_decimal esi                           ; convert the positive part
    neg dword [decimal_number]                      ; negate the result
    jmp %%done
    
%%positive_number:
    ; Convert to positive number
    buffer_to_decimal file_buffer
    
%%done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: read_number_from_file            ; reads an integer and stores it in decimal_number

%macro read_line_from_file 2                         ; %1 = buffer, %2 = max_size
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    xor edi, edi                                    ; edi = character counter
    mov esi, %1                                     ; esi = pointer to buffer
    
%%loop_read_char:
    cmp edi, %2                                     ; check limit
    jge %%done_read                                 ; if we reached limit, exit
    
    mov eax, sys_read
    mov ebx, [fd_in]
    mov ecx, esi                                    ; read directly to current position
    mov edx, 1                                      ; read a single character
    int 0x80
    
    cmp eax, 0
    je %%done_read                                  ; EOF
    
    cmp byte [esi], 0x0A
    je %%done_read                                  ; newline found
    
    inc esi                                         ; move to next position in buffer
    inc edi                                         ; increment counter
    jmp %%loop_read_char
    
%%done_read:
    mov byte [esi], 0                               ; string terminator '\0'
    mov [bytes_read], edi                           ; save how many characters were read
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: read_line_from_file buffer, 100 ; reads a line (up to 100 chars) from file

%macro read_char_from_file 0                         ; reads a single character from file
    push eax
    push ebx
    push ecx
    push edx
    
    mov eax, sys_read
    mov ebx, [fd_in]                                ; file descriptor
    mov ecx, char_buffer                            ; buffer for character
    mov edx, 1                                      ; read 1 byte
    int 0x80
    mov [bytes_read], eax                           ; save the result (1 or 0)
    
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: read_char_from_file              ; reads one character into char_buffer

%macro read_until_space_from_file 2                  ; %1 = buffer, %2 = max_size
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    xor edi, edi                                    ; edi = character counter
    mov esi, %1                                     ; esi = pointer to buffer
    
%%loop_read_char:
    cmp edi, %2                                     ; check limit
    jge %%done_read                                 ; if we reached limit, exit
    
    mov eax, sys_read
    mov ebx, [fd_in]
    mov ecx, esi                                    ; read directly to current position
    mov edx, 1                                      ; read a single character
    int 0x80
    
    cmp eax, 0
    jle %%done_read                                 ; EOF or error
    
    cmp byte [esi], ' '
    je %%done_read                                  ; space found
    
    cmp byte [esi], 0x0A
    je %%done_read                                  ; newline found (end of line)
    
    cmp byte [esi], 0x0D
    je %%done_read                                  ; carriage return found
    
    inc esi                                         ; move to next position in buffer
    inc edi                                         ; increment counter
    jmp %%loop_read_char
    
%%done_read:
    mov byte [esi], 0                               ; string terminator '\0'
    mov [bytes_read], edi                           ; save how many characters were read
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: read_until_space_from_file buffer, 50 ; reads until space/newline (max 50 chars)

%macro buffer_to_decimal 1                           ; %1 = buffer (string to convert)
    push eax
    push ebx
    push ecx
    push edx
    push esi
    
    xor eax, eax                                    ; result = 0
    mov esi, %1                                     ; pointer to buffer
    xor ecx, ecx                                    ; digit counter
    
%%convert_loop:
    movzx ebx, byte [esi]                           ; load character
    test ebx, ebx                                   ; check if terminator
    jz %%done_convert                               ; if yes, we're done
    
    cmp ebx, '0'                                    ; check if valid digit
    jb %%done_convert
    cmp ebx, '9'
    ja %%done_convert
    
    sub ebx, '0'                                    ; convert to digit
    
    ; eax = eax * 10 + digit
    mov edx, 10
    mul edx                                         ; eax = eax * 10
    add eax, ebx                                    ; eax = eax + digit
    
    inc esi
    jmp %%convert_loop
    
%%done_convert:
    mov [decimal_number], eax
    
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: buffer_to_decimal my_string     ; converts string to number in decimal_number

;----------------------------------------------------------------

%macro copy_buffer_in_other_buffer 2                 ; %1 = source, %2 = destination
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, %1                                     ; source
    mov edi, %2                                     ; destination

    ; Find first non-zero byte
    mov ecx, 256
.skip_zeros:
    cmp byte [esi], 0
    jne .found_nonzero
    inc esi
    loop .skip_zeros

.found_nonzero:
    ; Copy remaining bytes until first 0 after non-zero sequence or 256 bytes
    mov ecx, 256
.copy_loop:
    cmp byte [esi], 0
    je .done
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy_loop

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: copy_buffer_in_other_buffer src, dst ; copies src to dst, skipping leading zeros

%macro bubble_sort_vector_dd 2                       ; %1 = vector address, %2 = number of elements
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    movzx ecx, byte %2                              ; ecx = number of elements
    dec ecx                                         ; ecx = n-1 (for comparisons)
    
%%outer_loop:
    xor edx, edx                                    ; edx = swap flag (0 = no swap)
    mov esi, %1                                     ; esi = pointer to beginning
    mov edi, ecx                                    ; edi = number of remaining comparisons
    
%%inner_loop:
    mov eax, [esi]                                  ; eax = current element
    mov ebx, [esi + 4]                              ; ebx = next element
    
    cmp eax, ebx                                    ; compare
    jle %%no_swap                                   ; if in order, don't swap
    
    ; Perform swap
    mov [esi], ebx
    mov [esi + 4], eax
    mov edx, 1                                      ; set flag that swap occurred
    
%%no_swap:
    add esi, 4                                      ; move to next element
    dec edi                                         ; decrement counter
    jnz %%inner_loop                                ; continue inner loop
    
    test edx, edx                                   ; check if any swap occurred
    jz %%done                                       ; if not, vector is sorted
    
    dec ecx                                         ; decrement for outer loop
    jnz %%outer_loop                                ; continue outer loop
    
%%done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: bubble_sort_vector_dd vector_dd, [dimensiune_vector_dd] ; sorts dword vector

%macro bubble_sort_byte_vector 2                     ; %1 = vector address, %2 = number of elements
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    movzx ecx, byte %2                              ; ecx = number of elements
    dec ecx                                         ; ecx = n-1 (for comparisons)
    
%%outer_loop:
    xor edx, edx                                    ; edx = swap flag (0 = no swap)
    mov esi, %1                                     ; esi = pointer to beginning
    mov edi, ecx                                    ; edi = number of remaining comparisons
    
%%inner_loop:
    movzx eax, byte [esi]                           ; eax = current element (byte)
    movzx ebx, byte [esi + 1]                       ; ebx = next element (byte)
    
    cmp eax, ebx                                    ; compare
    jle %%no_swap                                   ; if in order, don't swap
    
    ; Perform swap
    mov [esi], bl                                   ; put bl (next element) in current position
    mov [esi + 1], al                               ; put al (current element) in next position
    mov edx, 1                                      ; set flag that swap occurred
    
%%no_swap:
    inc esi                                         ; move to next element (1 byte)
    dec edi                                         ; decrement counter
    jnz %%inner_loop                                ; continue inner loop
    
    test edx, edx                                   ; check if any swap occurred
    jz %%done                                       ; if not, vector is sorted
    
    dec ecx                                         ; decrement for outer loop
    jnz %%outer_loop                                ; continue outer loop
    
%%done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: bubble_sort_byte_vector buffer, 10 ; sorts 10 bytes in buffer

%macro read_vector_dd_from_file 1                    ; %1 = vector (resd)
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov esi, %1                                     ; pointer to vector
    mov ecx, [dimensiune_vector_dd]                 ; number of elements to read
    xor edi, edi                                    ; elements read counter
    
%%read_loop:
    cmp edi, ecx                                    ; read all elements?
    jge %%done
    
    ; Read the number
    read_number_from_file
    
    ; Save in vector
    mov eax, [decimal_number]
    mov [esi + edi * 4], eax                        ; vector[i] = number
    
    inc edi                                         ; increment counter
    jmp %%read_loop
    
%%done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: read_vector_dd_from_file vector_dd ; reads dimensiune_vector_dd integers into vector

%macro divide_numbers 2                              ; %1 = dividend, %2 = divisor
    push eax
    push ebx
    push edx
    
    mov eax, %1                                     ; load dividend into eax
    cdq                                             ; extend sign from eax into edx:eax
                                                    ; (required for signed division)
    mov ebx, %2                                     ; load divisor into ebx
    idiv ebx                                        ; divide edx:eax by ebx
                                                    ; result: eax = quotient, edx = remainder
    
    mov [catul], eax                                ; save quotient
    mov [restul], edx                               ; save remainder
    
    pop edx
    pop ebx
    pop eax
%endmacro
; Example usage: divide_numbers [numar1], [numar2] ; divides numar1 by numar2, stores in catul/restul

%macro multiply_numbers 2                            ; %1 = first factor, %2 = second factor
    push eax
    push ebx
    push edx
    
    mov eax, %1                                     ; load first factor into eax
    mov ebx, %2                                     ; load second factor into ebx
    imul ebx                                        ; multiply eax by ebx
                                                    ; result in eax (for 32-bit numbers)
                                                    ; EDX:EAX for 64-bit result
    
    mov [produs], eax                               ; save product (lower 32 bits)
    
    pop edx
    pop ebx
    pop eax
%endmacro
; Example usage: multiply_numbers [numar1], [numar2] ; multiplies numar1 by numar2, stores in produs

%macro count_spaces_in_buffer 2                      ; %1 = buffer, %2 = buffer length
    push eax
    push ebx
    push ecx
    push esi
    
    mov esi, %1                                     ; pointer to buffer
    mov ecx, %2                                     ; buffer length
    xor eax, eax                                    ; space counter = 0
    
%%loop_count:
    test ecx, ecx                                   ; more characters?
    jz %%done_count                                 ; if not, exit
    
    cmp byte [esi], ' '                             ; is it a space?
    jne %%next_char                                 ; if not, continue
    
    inc eax                                         ; increment space counter
    
%%next_char:
    inc esi                                         ; next character
    dec ecx                                         ; decrement remaining length
    jmp %%loop_count
    
%%done_count:
    mov [spaces_count], eax                         ; save result
    
    pop esi
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: count_spaces_in_buffer buffer, 100 ; counts spaces in first 100 bytes of buffer

%macro count_whitespace_in_buffer 2                  ; %1 = buffer, %2 = length
    push eax
    push ebx
    push ecx
    push esi
    
    mov esi, %1                                     ; pointer to buffer
    mov ecx, %2                                     ; buffer length
    xor eax, eax                                    ; whitespace counter = 0
    
%%loop_count:
    test ecx, ecx                                   ; more characters?
    jz %%done_count                                 ; if not, exit
    
    mov bl, [esi]                                   ; load current character
    
    cmp bl, ' '                                     ; space?
    je %%found_whitespace
    cmp bl, 0x09                                    ; tab (ASCII 9)?
    je %%found_whitespace
    cmp bl, 0x0A                                    ; newline (ASCII 10)?
    je %%found_whitespace
    cmp bl, 0x0D                                    ; carriage return (ASCII 13)?
    je %%found_whitespace
    
    jmp %%next_char                                 ; not whitespace
    
%%found_whitespace:
    inc eax                                         ; increment counter
    
%%next_char:
    inc esi                                         ; next character
    dec ecx                                         ; decrement remaining length
    jmp %%loop_count
    
%%done_count:
    mov [spaces_count], eax                         ; save result
    
    pop esi
    pop ecx
    pop ebx
    pop eax
%endmacro
; Example usage: count_whitespace_in_buffer buffer, 100 ; counts all whitespace chars in buffer


;------------------------------------------------------------------

section .data

	space db ' '
	newline db 0x0A

	filename_in db 'in.txt', 0
	filename_out db 'out.txt', 0
    test_message db 'abcd'
    test_message_len equ $ - test_message

section .bss

	fd_in resd 1                                    ; file descriptor for input
	fd_out resd 1                                   ; file descriptor for output

	; Reading buffers and variables
	bytes_read resd 1                               ; how many bytes were read from file
	char_buffer resb 1                              ; buffer for one character
	file_buffer resb 256                            ; buffer for one line (max 256 chars)

	; Number conversion system
	decimal_number resd 1                           ; actual decimal number
    hex_char resb 1                                 ; temporary buffer for hex character

    vector_dd resd 100                              ; dword vector (up to 100 elements)
    dimensiune_vector_dd resd 1                     ; size of dword vector

    catul resd 1                                    ; quotient from division
    restul resd 1                                   ; remainder from division
    produs resd 1                                   ; product from multiplication

    spaces_count resd 1                             ; counter for spaces/whitespace

    numar1 resd 1                                   ; first number
    numar2 resd 1                                   ; second number

section .text
    global _start

_start:
_open_input_file:
    mov eax, sys_open
    mov ebx, filename_in                            ; input file name
    mov ecx, read_only                              ; open mode (read)
    mov edx, 0                                      ; we don't use permissions here
    int 0x80
    mov [fd_in], eax                                ; save file descriptor

    cmp eax, -1                                     ; check if opened successfully
    jl _exit_with_error

_open_output_file:
    mov eax, sys_creat
    mov ebx, filename_out                           ; output file name
    mov ecx, file_mode                              ; permissions for file
    int 0x80
    mov [fd_out], eax                               ; save file descriptor

    cmp eax, -1                                     ; check if created successfully
    jl _exit_with_error

;----------------------------------------------------------------------------

    read_number_from_file
    mov eax, [decimal_number]
    print_decimal_to_file eax
    print_newline_to_file

;----------------------------------------------------------------------------

_final:
_file_in_close:
    mov eax, sys_close
    mov ebx, [fd_in]
    int 0x80

_file_out_close:
    mov eax, sys_close
    mov ebx, [fd_out]
    int 0x80

_exit:
    mov eax, sys_exit
    xor ebx, ebx
    int 0x80

_exit_with_error:
    mov eax, sys_exit
    mov ebx, 1
    int 0x80
