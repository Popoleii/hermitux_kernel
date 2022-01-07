; Copyright 2010-2016 Stefan Lankes, RWTH Aachen University
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;    * Redistributions of source code must retain the above copyright
;      notice, this list of conditions and the following disclaimer.
;    * Redistributions in binary form must reproduce the above copyright
;      notice, this list of conditions and the following disclaimer in the
;      documentation and/or other materials provided with the distribution.
;    * Neither the name of the University nor the names of its contributors
;      may be used to endorse or promote products derived from this software
;      without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
; ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; This is the kernel's entry point for the application processors.
; HermitCore switches to the protected mode and jump to its kernel.
; This trampline code is only used by the HemritCore's single kernel version.

KERNEL_STACK_SIZE equ 0x100
kernel_start equ 0x800000

[BITS 16]			; Assembler should generate 16 bits code
SECTION .text		; This code will be put in the .text section
GLOBAL _start		; Will be accessible from outside this module
ORG 0x800			; Address the pogram will be loaded in memory
_start:
	cli				; disable interrupts
	lgdt [gdtr]		; load 32 bits gdt for protected mode

	; switch to protected mode by setting PE bit
	mov eax, cr0 	; eax <- cr0
	or al, 0x1   	; set the first bit (PE == protection enable) to 1, al are the lower 8 bits of eax
	mov cr0, eax 	; actually enable protected mode by setting the control register

	; far jump to the 32bit code
	jmp dword codesel : _pmstart

[BITS 32]			; Assembler should generate 32 bits code from now on
ALIGN 4 			; Align on 4 bytes boundary
_pmstart:
	xor eax, eax		; fast way to put zero in eax
	mov ax, datasel		; ax is the lower 16 bits of eax
	mov ds, ax			; set all data segment to point to datasel
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	mov esp, boot_stack+KERNEL_STACK_SIZE-16  ; Stack grows down (why -16?) so put stack pointer at the bottom
	jmp short stublet
	jmp $

; GDT for the protected mode (32 bits)
; http://wiki.osdev.org/Global_Descriptor_Table
ALIGN 4
gdtr:                           ; descritor table (descriptor for the table)
        dw gdt_end-gdt-1        ; limit (table size)
        dd gdt                  ; base adresse (address of the table itself)
gdt:							; the actual table starts here
        dd 0,0                  ; first entry: null descriptor (64 bits full of zeros)
codesel equ $-gdt				; second entry: code selector
        dw 0xFFFF               ; segment size 0..15
        dw 0x0000               ; segment address 0..15
        db 0x00                 ; segment address 16..23 
        db 0x9A                 ; access permissions und type
        db 0xCF                 ; additional information and segment size 16...19, total segment size is 0xFFFFF 4KB pages (4GB)
        db 0x00                 ; segment address 24..31 --> address the segment begins 0x00000000
datasel equ $-gdt				; second entry: data selector
        dw 0xFFFF               ; segment size 0..15
        dw 0x0000               ; segment address 0..15
        db 0x00                 ; segment address 16..23 --> address the segment begins
        db 0x92                 ; access permissions and type
        db 0xCF                 ; additional informationen and degment size 16...19, total size 4GB
        db 0x00                 ; segment address 24..31
gdt_end:

; Access for code: present, kernel level, executable, growing up, readable,
; and not accessed yet
; For data: present, kernel level, not executable, grows up, RW, and not
; accessed yet
; Flags for both page and data: 32 bits protected mode, and the unit of the
; base address (segment address) is in 4KB pages (not in bytes)

ALIGN 4
GDTR64:
    dw GDT64_end - GDT64 - 1     ; Limit.
    dq GDT64                     ; Base.

; we need a new GDT to switch in the 64bit modus
GDT64:                           ; Global Descriptor Table (64-bit).
    .Null: equ $ - GDT64         ; The null descriptor.
    dw 0                         ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 0                         ; Access.
    db 0                         ; Granularity.
    db 0                         ; Base (high).
    .Code: equ $ - GDT64         ; The code descriptor.
    dw 0                         ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 10011010b                 ; Access.
    db 00100000b                 ; Granularity.
    db 0                         ; Base (high).
    .Data: equ $ - GDT64         ; The data descriptor.
    dw 0                         ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 10010010b                 ; Access.
    db 00000000b                 ; Granularity.
    db 0                         ; Base (high).
GDT64_end:

; GDT64:
; - code:
;  - limit (size) = 0x0 (is that a problem?)
;  - base = 0x0
;  - access: present, kernel level of privileges, executable, grows up,
;  RW, not accessed yet

ALIGN 4
stublet:

; This will set up the x86 control registers:
; Caching and the floating point unit are enabled
; Bootstrap page tables are loaded and page size
; extensions (huge pages) enabled.
;
; HermitCore's boot processor map its kernel into
; the address space of this trampoline code.
; => more information in apic.c
cpu_init:
    ; check for long mode

    ; do we have the instruction cpuid?
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    jz $ ; there is no long mode

    ; cpuid > 0x80000000?
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb $ ; It is less, there is no long mode.

    ; do we have a long mode?
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29 ; Test if the LM-bit, which is bit 29, is set in the D-register.
    jz $ ; They aren't, there is no long mode.

    ; we need to enable PAE modus
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Set CR3
    mov eax, 0xDEADBEAF
    add eax, ebp
    or eax, (1 << 0)        ; set present bit
    mov cr3, eax

    ; Set CR4 (PAE is already set)
    mov eax, cr4
    and eax, 0xfffbf9ff     ; disable SSE
    or eax, (1 << 7)        ; enable PGE
    mov cr4, eax

    ; Set CR0 (PM-bit is already set)
    mov eax, cr0
    and eax, ~(1 << 2)      ; disable FPU emulation
    or eax, (1 << 1)        ; enable FPU montitoring
    and eax, ~(1 << 30)     ; enable caching
    and eax, ~(1 << 29)     ; disable write through caching
    and eax, ~(1 << 16)     ; allow kernel write access to read-only pages
    or eax, (1 << 31)       ; enable paging
    mov cr0, eax

    lgdt [GDTR64]           ; Load the 64-bit global descriptor table.
    mov ax, GDT64.Data
    mov ss, ax
    mov ds, ax
    mov es, ax

    jmp GDT64.Code:start64  ; Set the code segment and enter 64-bit long mode.

[BITS 64]			; Assembler should generate 64 bits code from now on
ALIGN 8
start64:
    push kernel_start
    ret

ALIGN 16
global boot_stack
boot_stack:
    TIMES (KERNEL_STACK_SIZE) DB 0xcd ; Fill this area with 0x100 times the byte 0xcd
