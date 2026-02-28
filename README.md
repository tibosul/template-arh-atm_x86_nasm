# template-arh-atm_x86_nasm

NASM x86 32-bit assembly template with macros for file I/O, number conversion,
buffer manipulation, and sorting. Targets Linux i386 using int 0x80 syscalls.

This is a course template. You copy template.asm, fill in your logic between
the open/close boilerplate, and use the macros instead of repeating the same
dozen syscall sequences by hand every assignment.

---

## Table of Contents

1. Requirements
2. Building and Running
3. How Macros Work in NASM
4. Defines and Constants
5. Required BSS/Data Variables
6. Macro Reference
   - File Navigation
   - File Writing
   - File Reading and Conversion
   - Arithmetic
   - Sorting
   - Buffer Utilities
7. Program Structure
8. Notes and Caveats

---

## 1. Requirements

- NASM assembler (2.x or later)
- GNU ld linker (binutils)
- Linux i386 or x86_64 with 32-bit support (ia32-libs / lib32 packages)

On a 64-bit Debian/Ubuntu system:

    sudo apt install nasm gcc-multilib

---

## 2. Building and Running

    nasm -f elf32 template.asm -o src.o
    ld -m elf_i386 src.o -o src
    ./src

The program expects `in.txt` in the current directory and writes output to
`out.txt`. If the input file cannot be opened the program exits with status 1.

---

## 3. How Macros Work in NASM

NASM macros are textual substitutions expanded at assembly time. They are not
function calls. No call/ret overhead, no stack frame. The macro body is copied
verbatim into the instruction stream at every point you use it.

Defining a macro:

    %macro name num_params
        ; body, parameters are %1, %2, ...
    %endmacro

Calling a macro:

    name arg1, arg2

Local labels inside a macro use the `%%label` prefix so each expansion gets
its own unique label and does not conflict with other expansions or surrounding
code.

All macros in this template save and restore every register they modify using
push/pop on the stack. A macro that uses eax, ebx, ecx, edx will push all four
at the start and pop them at the end. This means you can call them anywhere
without worrying about clobbering your registers -- with one exception: macros
that produce a result store it in a memory variable (e.g., `decimal_number`,
`bytes_read`) rather than in a register, so the caller reads it from memory
after the macro returns.

---

## 4. Defines and Constants

Syscall numbers (Linux i386):

    sys_exit    0x01
    sys_write   0x04
    sys_read    0x03
    sys_creat   0x08
    sys_open    0x05
    sys_close   0x06
    sys_lseek   0x13

Standard file descriptors:

    stdin   0x00
    stdout  0x01
    stderr  0x02

File open flags:

    read_only   0x00
    write_only  0x01
    read_write  0x02

lseek whence values:

    seek_start   0x00    ; SEEK_SET
    seek_current 0x01    ; SEEK_CUR
    seek_end     0x02    ; SEEK_END

Default file creation permissions:

    file_mode   0644

---

## 5. Required BSS/Data Variables

The macros reference global labels by name. Your program must declare them in
.data or .bss. The template already provides these; do not rename them.

    section .data
        space       db ' '
        newline     db 0x0A
        filename_in  db 'in.txt', 0
        filename_out db 'out.txt', 0

    section .bss
        fd_in               resd 1   ; input file descriptor
        fd_out              resd 1   ; output file descriptor
        bytes_read          resd 1   ; result of last read operation
        char_buffer         resb 1   ; single-character I/O scratch
        file_buffer         resb 256 ; general-purpose line buffer
        decimal_number      resd 1   ; result of read_number_from_file / buffer_to_decimal
        hex_char            resb 1   ; scratch byte for hex/binary print macros
        vector_dd           resd 100 ; dword array (up to 100 elements)
        dimensiune_vector_dd resd 1  ; number of elements currently in vector_dd
        catul               resd 1   ; quotient from divide_numbers
        restul              resd 1   ; remainder from divide_numbers
        produs              resd 1   ; product from multiply_numbers
        spaces_count        resd 1   ; result of count_spaces / count_whitespace macros
        numar1              resd 1   ; general-purpose number variable
        numar2              resd 1   ; general-purpose number variable

---

## 6. Macro Reference

### File Navigation

These macros all operate on `fd_in` (the input file descriptor).

---

#### rewind_file

    rewind_file

Moves the file pointer of fd_in to the beginning of the file.
Equivalent to lseek(fd_in, 0, SEEK_SET).

Registers saved: eax, ebx, ecx, edx.
No output variables modified.

Example:

    rewind_file

---

#### go_back_in_file

    go_back_in_file N

Moves the file pointer of fd_in backward by N bytes from the current position.
Equivalent to lseek(fd_in, -N, SEEK_CUR).

Parameters:
  %1 -- immediate or register: number of bytes to go back

Registers saved: eax, ebx, ecx, edx.

Example:

    go_back_in_file 1    ; re-read the last byte on the next read

---

#### go_to_end_of_file

    go_to_end_of_file

Moves the file pointer of fd_in to the end of the file.
Equivalent to lseek(fd_in, 0, SEEK_END).

Registers saved: eax, ebx, ecx, edx.

Example:

    go_to_end_of_file

---

#### advance_in_file

    advance_in_file N

Moves the file pointer of fd_in forward by N bytes from the current position,
skipping that many bytes without reading them.
Equivalent to lseek(fd_in, N, SEEK_CUR).

Parameters:
  %1 -- immediate or register: number of bytes to skip

Registers saved: eax, ebx, ecx, edx.

Example:

    advance_in_file 4    ; skip the next 4 bytes

---

### File Writing

These macros write to fd_out (the output file descriptor).

---

#### print_to_file

    print_to_file buffer, length

Writes `length` bytes from `buffer` to fd_out.
Equivalent to write(fd_out, buffer, length).

Parameters:
  %1 -- address of the buffer (label or register)
  %2 -- number of bytes to write (immediate, register, or memory)

Registers saved: eax, ebx, ecx, edx.

Example:

    section .data
        msg db 'hello', 0x0A
        msg_len equ $ - msg

    print_to_file msg, msg_len

---

#### print_char_to_file

    print_char_to_file char

Writes a single character to fd_out. The character is stored in `char_buffer`
before the write.

Parameters:
  %1 -- a character literal, immediate byte, or register (byte-sized)

Registers saved: eax, ebx, ecx, edx.
Side effect: modifies char_buffer.

Example:

    print_char_to_file 'X'
    print_char_to_file al

---

#### print_newline_to_file

    print_newline_to_file

Writes a single newline character (0x0A) to fd_out. Implemented as a wrapper
around print_to_file using the `newline` label from .data.

Registers saved: eax, ebx, ecx, edx (via print_to_file).

Example:

    print_newline_to_file

---

#### print_space_to_file

    print_space_to_file

Writes a single space character (0x20) to fd_out. Implemented as a wrapper
around print_to_file using the `space` label from .data.

Registers saved: eax, ebx, ecx, edx (via print_to_file).

Example:

    print_space_to_file

---

#### print_number_in_base_to_file

    print_number_in_base_to_file number, base

Converts an unsigned 32-bit integer to its string representation in the given
base and writes it to fd_out. Base must be between 2 and 16 inclusive. Digits
above 9 are printed as uppercase A-F.

Uses 32 bytes of stack space for the digit buffer.

Parameters:
  %1 -- the number (immediate, register, or memory dword)
  %2 -- the base (immediate or register, 2..16)

Registers saved: eax, ebx, ecx, edx, esi, edi.

Examples:

    print_number_in_base_to_file 255, 16   ; writes "FF"
    print_number_in_base_to_file eax, 2    ; writes eax in binary
    print_number_in_base_to_file eax, 10   ; same as print_decimal_to_file

---

#### print_decimal_to_file

    print_decimal_to_file number

Writes the decimal string representation of an unsigned 32-bit integer to
fd_out. This is a convenience wrapper around print_number_in_base_to_file
with base 10.

Parameters:
  %1 -- the number (immediate, register, or memory dword)

Registers saved: same as print_number_in_base_to_file.

Example:

    mov eax, [decimal_number]
    print_decimal_to_file eax

---

#### print_hex_string_to_file

    print_hex_string_to_file buffer, length

Reads `length` bytes from `buffer` and writes each byte as a two-character
lowercase hexadecimal string to fd_out. Bytes are processed in order; the high
nibble is written first, then the low nibble.

Parameters:
  %1 -- address of the input buffer
  %2 -- number of bytes to process (immediate or register)

Registers saved: eax, ebx, ecx, edx, esi, edi.
Side effect: modifies hex_char.

Example:

    print_hex_string_to_file file_buffer, 4
    ; If file_buffer contains 0xDE 0xAD 0xBE 0xEF, output is "deadbeef"

---

#### print_binary_string_to_file

    print_binary_string_to_file buffer, length

Reads `length` bytes from `buffer` and writes each byte as an 8-character
binary string to fd_out, most significant bit first (big-endian bit order).

Parameters:
  %1 -- address of the input buffer
  %2 -- number of bytes to process (immediate or register)

Registers saved: eax, ebx, ecx, edx, esi, edi.
Side effect: modifies hex_char (used as a 1-byte write scratch).

Example:

    print_binary_string_to_file file_buffer, 1
    ; If file_buffer[0] = 0xA5 (10100101b), output is "10100101"

---

#### print_binary_string_to_file_lsb

    print_binary_string_to_file_lsb buffer, length

Same as print_binary_string_to_file but bits are printed least significant bit
first (little-endian bit order).

Parameters:
  %1 -- address of the input buffer
  %2 -- number of bytes to process (immediate or register)

Registers saved: eax, ebx, ecx, edx, esi, edi.
Side effect: modifies hex_char.

Example:

    print_binary_string_to_file_lsb file_buffer, 1
    ; For 0x01 (00000001b), MSB-first gives "00000001", LSB-first gives "10000000"
    ; For 0x80 (10000000b), MSB-first gives "10000000", LSB-first gives "00000001"

---

### File Reading and Conversion

These macros read from fd_in. After a successful read the number of characters
actually read is stored in `bytes_read`.

---

#### read_from_file

    read_from_file buffer, max_bytes

Reads up to `max_bytes` bytes from fd_in into `buffer`.
Equivalent to read(fd_in, buffer, max_bytes).

Stores the number of bytes actually read in `bytes_read`. A value of 0 means
EOF was reached.

Parameters:
  %1 -- address of the destination buffer
  %2 -- maximum number of bytes to read

Registers saved: eax, ebx, ecx, edx.
Output: bytes_read

Example:

    read_from_file file_buffer, 256
    ; file_buffer now holds the data, [bytes_read] holds how many bytes came in

---

#### read_char_from_file

    read_char_from_file

Reads exactly one byte from fd_in into `char_buffer`.

Stores 1 in `bytes_read` on success, 0 at EOF.

Registers saved: eax, ebx, ecx, edx.
Output: char_buffer, bytes_read

Example:

    read_char_from_file
    mov al, [char_buffer]

---

#### read_line_from_file

    read_line_from_file buffer, max_size

Reads characters from fd_in one at a time until a newline (0x0A) is found,
EOF is reached, or `max_size` characters have been read. The newline is
consumed but not stored. The result is null-terminated.

Stores the number of characters read (excluding the null terminator) in
`bytes_read`.

Parameters:
  %1 -- address of the destination buffer
  %2 -- maximum number of characters to store (not counting the null byte)

Registers saved: eax, ebx, ecx, edx, esi, edi.
Output: buffer contains null-terminated string, bytes_read

Example:

    read_line_from_file file_buffer, 255
    ; file_buffer now holds one text line, null-terminated

---

#### read_until_space_from_file

    read_until_space_from_file buffer, max_size

Reads characters from fd_in one at a time until a space (0x20), newline
(0x0A), carriage return (0x0D), or EOF is reached, or until `max_size`
characters have been read. The delimiter is consumed but not stored. The
result is null-terminated.

Stores the number of characters read in `bytes_read`.

Parameters:
  %1 -- address of the destination buffer
  %2 -- maximum number of characters to store

Registers saved: eax, ebx, ecx, edx, esi, edi.
Output: buffer contains null-terminated token, bytes_read

Example:

    read_until_space_from_file file_buffer, 50

---

#### read_number_from_file

    read_number_from_file

Reads a whitespace-delimited token from fd_in and converts it to a signed
32-bit integer. If the token starts with '-' the result is negated.

Internally calls read_until_space_from_file then buffer_to_decimal.

Stores the result in `decimal_number`.

Registers saved: eax, ebx, ecx, edx, esi.
Output: decimal_number

Example:

    read_number_from_file
    mov eax, [decimal_number]

---

#### buffer_to_decimal

    buffer_to_decimal buffer

Converts a null-terminated decimal digit string in `buffer` to an unsigned
32-bit integer. Stops at the first non-digit character or null byte.

Stores the result in `decimal_number`.

Parameters:
  %1 -- address of the null-terminated string

Registers saved: eax, ebx, ecx, edx, esi.
Output: decimal_number

Example:

    ; file_buffer contains "1234\0"
    buffer_to_decimal file_buffer
    ; [decimal_number] == 1234

---

#### read_vector_dd_from_file

    read_vector_dd_from_file vector

Reads `[dimensiune_vector_dd]` signed integers from fd_in and stores them as
dwords in `vector`. Each number is parsed by read_number_from_file.

You must set `dimensiune_vector_dd` before calling this macro.

Parameters:
  %1 -- address of a resd array large enough to hold all elements

Registers saved: eax, ebx, ecx, edx, esi, edi.
Side effect: modifies decimal_number, file_buffer, bytes_read (via the nested
read_number_from_file calls).

Example:

    mov dword [dimensiune_vector_dd], 5
    read_vector_dd_from_file vector_dd
    ; vector_dd[0..4] now holds the five integers from the file

---

### Arithmetic

---

#### divide_numbers

    divide_numbers dividend, divisor

Performs signed 32-bit integer division: dividend / divisor.

Uses idiv, which requires sign-extending eax into edx:eax via cdq before the
division. The quotient is stored in `catul`, the remainder in `restul`.

Parameters:
  %1 -- dividend (immediate, register, or memory dword)
  %2 -- divisor  (immediate, register, or memory dword)

Registers saved: eax, ebx, edx.

Output variables:
  catul  -- quotient
  restul -- remainder (same sign as dividend for idiv)

Example:

    mov dword [numar1], 17
    mov dword [numar2], 5
    divide_numbers [numar1], [numar2]
    ; [catul] == 3, [restul] == 2

---

#### multiply_numbers

    multiply_numbers factor1, factor2

Performs signed 32-bit integer multiplication: factor1 * factor2.

Uses imul. The lower 32 bits of the product are stored in `produs`. If the
full 64-bit result is needed, edx:eax holds it immediately after the macro
returns -- but the macro restores edx, so you would need to save edx yourself
before calling if you need the high 32 bits.

Parameters:
  %1 -- first factor  (immediate, register, or memory dword)
  %2 -- second factor (immediate, register, or memory dword)

Registers saved: eax, ebx, edx.
Output: produs (lower 32 bits of result)

Example:

    mov dword [numar1], 6
    mov dword [numar2], 7
    multiply_numbers [numar1], [numar2]
    ; [produs] == 42

---

### Sorting

---

#### bubble_sort_vector_dd

    bubble_sort_vector_dd vector, count

Sorts an array of 32-bit signed integers in place using bubble sort, ascending
order. Uses an optimized variant that stops early when no swap occurs in a
pass.

Parameters:
  %1 -- address of the dword array
  %2 -- number of elements (byte-sized value, loaded with movzx)

Registers saved: eax, ebx, ecx, edx, esi, edi.

Example:

    mov dword [dimensiune_vector_dd], 5
    read_vector_dd_from_file vector_dd
    bubble_sort_vector_dd vector_dd, [dimensiune_vector_dd]

---

#### bubble_sort_byte_vector

    bubble_sort_byte_vector buffer, count

Sorts an array of bytes in place using bubble sort, ascending order. Elements
are compared as unsigned bytes.

Parameters:
  %1 -- address of the byte array
  %2 -- number of elements (byte-sized value, loaded with movzx)

Registers saved: eax, ebx, ecx, edx, esi, edi.

Example:

    bubble_sort_byte_vector file_buffer, [bytes_read]

---

### Buffer Utilities

---

#### copy_buffer_in_other_buffer

    copy_buffer_in_other_buffer src, dst

Copies a null-terminated string from `src` to `dst`, skipping any leading zero
bytes in `src` first. Copies at most 256 bytes (not counting leading zeros).

The skip-zeros step means the macro is not a plain memcpy replacement. If your
source buffer genuinely starts with a valid null byte (i.e., empty string),
the macro will scan past it looking for non-zero content.

Parameters:
  %1 -- address of the source buffer
  %2 -- address of the destination buffer

Registers saved: eax, ebx, ecx, edx, esi, edi.

Example:

    copy_buffer_in_other_buffer file_buffer, second_buffer

---

#### count_spaces_in_buffer

    count_spaces_in_buffer buffer, length

Counts the number of ASCII space characters (0x20) in the first `length` bytes
of `buffer`.

Stores the count in `spaces_count`.

Parameters:
  %1 -- address of the buffer
  %2 -- number of bytes to examine (immediate or register)

Registers saved: eax, ebx, ecx, esi.
Output: spaces_count

Example:

    read_line_from_file file_buffer, 255
    count_spaces_in_buffer file_buffer, [bytes_read]
    ; [spaces_count] holds the number of spaces on that line

---

#### count_whitespace_in_buffer

    count_whitespace_in_buffer buffer, length

Counts the number of whitespace characters in the first `length` bytes of
`buffer`. Whitespace is defined as: space (0x20), tab (0x09), newline (0x0A),
carriage return (0x0D).

Stores the count in `spaces_count`.

Parameters:
  %1 -- address of the buffer
  %2 -- number of bytes to examine (immediate or register)

Registers saved: eax, ebx, ecx, esi.
Output: spaces_count

Example:

    count_whitespace_in_buffer file_buffer, 256

---

## 7. Program Structure

The _start label opens both files, runs your code, then closes them and exits.
The section between the two comment separators is where you put your logic:

    _start:
    _open_input_file:
        ; opens in.txt into fd_in

    _open_output_file:
        ; creates out.txt into fd_out

    ;-----------------------------------------------------------
    ; YOUR CODE GOES HERE
    ;-----------------------------------------------------------

    _final:
    _file_in_close:
        ; closes fd_in

    _file_out_close:
        ; closes fd_out

    _exit:
        ; exits with status 0

    _exit_with_error:
        ; exits with status 1

If either open/create call returns a negative value the program jumps directly
to _exit_with_error and does not run any of your code.

---

## 8. Notes and Caveats

**Register preservation.** All macros push every register they modify and pop
them on exit. You may call any macro at any point in your code without saving
registers beforehand. Results are communicated through dedicated memory
variables, not through registers.

**Nested macro calls.** Several macros call other macros internally (e.g.,
read_number_from_file calls read_until_space_from_file and buffer_to_decimal).
This works because NASM macros expand inline; there is no actual nesting of
function calls. Each local label (%%label) is unique per expansion so there
are no label collisions.

**Signed vs unsigned.** The arithmetic macros (divide_numbers, multiply_numbers)
use idiv/imul and treat numbers as signed. The print_number_in_base_to_file
macro uses div (unsigned). If you need to print a signed number and it may be
negative, check its sign first, print a '-' with print_char_to_file, negate it,
then call print_decimal_to_file on the positive value.

**Buffer sizes.** file_buffer is 256 bytes. read_line_from_file and
read_until_space_from_file accept a max_size parameter so you can limit reads
to smaller sizes, but they will not protect you if you pass an address that
points to less memory than max_size allows. vector_dd holds up to 100 dwords
(400 bytes). Exceeding these limits corrupts adjacent BSS data.

**lseek syscall number.** sys_lseek is defined as 0x13 (19 decimal), which is
the correct number for lseek on Linux i386. Do not confuse it with llseek
(0x8C).

**file_mode.** The output file is created with sys_creat using permissions 0644
(owner read/write, group read, others read). The umask of the running process
will further restrict these permissions.

**32-bit only.** This template uses the int 0x80 ABI and 32-bit registers. It
will not assemble as ELF64. Build with -f elf32 and link with -m elf_i386.
