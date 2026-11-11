;=======================================
; FINAL CLC CODE (FIXED v2)
; Date: April 13, 2026
; Author: Alex Razo
;
; FIXES APPLIED:
;   1. delay_2ms rewritten with nested loop (~1.99ms at 16MHz)
;   2. delay_20ms fixed to call delay_2ms 10x (~20ms) + saves r18
;   3. EN pulse width increased to 8 NOPs (~500ns) in both
;      writeCmdToLCD and writeDataToLCD (4 spots total)
;   4. BUZZER pin corrected from 2 (PB2) to 3 (PB3)
;   5. Missing "call writeDataToLCD" for space in display_alarm_info
;=======================================

.include "m328Pdef.inc"

;=======================================
; CONSTANTS
;=======================================
.equ RS      = 0
.equ EN      = 1
.equ BUZZER  = 3          ; FIX: was 2 (PB2), hardware is on PB3

.equ BTN_HR  = 1
.equ BTN_MIN = 2
.equ BTN_AHR = 3
.equ BTN_AMN = 4

;=======================================
; REGISTERS
;=======================================
.def sec_count = r20
.def tens      = r21
.def ones      = r22
.def min_count = r23
.def hr_count  = r24
.def temp_num  = r25

;=======================================
; SRAM
;=======================================
.dseg
.org 0x0100
alarm_hr:     .byte 1
alarm_min:    .byte 1
alarm_en:     .byte 1
alm_disp_cnt: .byte 1

;=======================================
; CODE
;=======================================
.cseg
.org 0x0000
    rjmp start

;=======================================
; START
;=======================================
start:
    ; Stack
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    ; GPIO
    ldi r16, 0xFF
    out DDRD, r16
    out DDRB, r16
    ldi r16, 0x00
    out DDRC, r16

    ; Pull-ups PC1-PC4
    ldi r16, 0b00011110
    out PORTC, r16

    ; Timer1 CTC mode, prescaler 1024
    ldi r16, 0
    sts TCCR1A, r16
    ldi r16, (1<<WGM12) | (1<<CS12) | (1<<CS10)
    sts TCCR1B, r16

    ldi r16, 0
    sts TCNT1H, r16
    sts TCNT1L, r16
    ldi r16, 0x3D
    sts OCR1AH, r16
    ldi r16, 0x09
    sts OCR1AL, r16

    call initADC
    call delay_20ms

    ; LCD INIT
    ldi r16, 0x33
    call writeCmdToLCD
    ldi r16, 0x32
    call writeCmdToLCD
    ldi r16, 0x28
    call writeCmdToLCD
    ldi r16, 0x0E
    call writeCmdToLCD
    ldi r16, 0x01
    call writeCmdToLCD
    ldi r16, 0x06
    call writeCmdToLCD

    ; INIT TIME
    ldi hr_count,0
    ldi min_count,0
    ldi sec_count,0

    ldi r16,0
    sts alarm_hr,r16
    sts alarm_min,r16
    sts alarm_en,r16

;=======================================
; MAIN LOOP
;=======================================
main:
    call check_buttons

wait_tick:
    in r16, TIFR1
    sbrs r16, OCF1A
    rjmp main

    ldi r16, (1<<OCF1A)
    out TIFR1, r16

    inc sec_count
    cpi sec_count,60
    brne disp
    ldi sec_count,0

    inc min_count
    cpi min_count,60
    brne disp
    ldi min_count,0

    inc hr_count
    cpi hr_count,24
    brne disp
    ldi hr_count,0

disp:
    call update_time_display
    call check_alarm
    rjmp main

;=======================================
; BUTTONS (4 BUTTON)
;=======================================
check_buttons:
    push r18
    in r18, PINC

; PC1 Hour
    sbrc r18, BTN_HR
    rjmp chk_min
    call delay_20ms
    inc hr_count
    cpi hr_count,24
    brlo hr_ok
    ldi hr_count,0
hr_ok:
    call update_time_display
wait_hr:
    in r18,PINC
    sbrs r18,BTN_HR
    rjmp wait_hr

; PC2 Minute
chk_min:
    in r18,PINC
    sbrc r18,BTN_MIN
    rjmp chk_ahr
    call delay_20ms
    inc min_count
    cpi min_count,60
    brlo min_ok
    ldi min_count,0
min_ok:
    call update_time_display
wait_min:
    in r18,PINC
    sbrs r18,BTN_MIN
    rjmp wait_min

; PC3 Alarm Hour (tap) / toggle (hold)
chk_ahr:
    in r18,PINC
    sbrc r18,BTN_AHR
    rjmp chk_amn

    call delay_20ms
    ldi r17,50

hold_loop:
    call delay_20ms
    in r18,PINC
    sbrc r18,BTN_AHR
    rjmp short_press
    dec r17
    brne hold_loop

    ; HOLD: toggle alarm on/off
    lds r16,alarm_en
    ldi r17,1
    eor r16,r17
    sts alarm_en,r16
    call display_alarm_info
    rjmp wait_ahr

short_press:
    lds r16,alarm_hr
    inc r16
    cpi r16,24
    brlo save_ahr
    ldi r16,0
save_ahr:
    sts alarm_hr,r16
    call display_alarm_info

wait_ahr:
    in r18,PINC
    sbrs r18,BTN_AHR
    rjmp wait_ahr

; PC4 Alarm Minute
chk_amn:
    in r18,PINC
    sbrc r18,BTN_AMN
    rjmp done_btn
    call delay_20ms
    lds r16,alarm_min
    inc r16
    cpi r16,60
    brlo save_amn
    ldi r16,0
save_amn:
    sts alarm_min,r16
    call display_alarm_info
wait_amn:
    in r18,PINC
    sbrs r18,BTN_AMN
    rjmp wait_amn

done_btn:
    pop r18
    ret

;=======================================
; ALARM
;=======================================
check_alarm:
    lds r16,alarm_en
    cpi r16,1
    brne end_alarm

    lds r16,alarm_hr
    cp r16,hr_count
    brne end_alarm

    lds r16,alarm_min
    cp r16,min_count
    brne end_alarm

    cpi sec_count,30
    brsh end_alarm

    call beep_buzzer

end_alarm:
    ret

;=======================================
; BUZZER (ACTIVE LOW)
;=======================================
beep_buzzer:
    push r17
    ldi r17,50
buzz:
    cbi PORTB,BUZZER
    call delay_2ms
    sbi PORTB,BUZZER
    call delay_2ms
    dec r17
    brne buzz
    pop r17
    ret

;=======================================
; DISPLAY TIME
;=======================================
update_time_display:
    ldi r16,0x80
    call writeCmdToLCD
    mov temp_num,hr_count
    call print_2_digits
    ldi r16,':'
    call writeDataToLCD
    mov temp_num,min_count
    call print_2_digits
    ldi r16,':'
    call writeDataToLCD
    mov temp_num,sec_count
    call print_2_digits
    ret

;=======================================
; PRINT 2 DIGITS
;=======================================
print_2_digits:
    mov ones,temp_num
    ldi tens,0
loop10:
    cpi ones,10
    brlo done10
    subi ones,10
    inc tens
    rjmp loop10
done10:
    ldi r16,'0'
    add tens,r16
    add ones,r16
    mov r16,tens
    call writeDataToLCD
    mov r16,ones
    call writeDataToLCD
    ret

;=======================================
; ADC INIT
;=======================================
initADC:
    ldi r16,0b10000111
    sts ADCSRA,r16
    ldi r16,0b01000000
    sts ADMUX,r16
    ret

;=======================================
; LCD COMMAND
; FIX: EN pulse increased to 8 NOPs (~500ns) on both nibbles
;=======================================
writeCmdToLCD:
    mov r17,r16
    andi r17,0xF0
    out PORTD,r17
    cbi PORTB,RS
    sbi PORTB,EN
    nop                   ; FIX: 8 NOPs = ~500ns, meets HD44780 450ns minimum
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    cbi PORTB,EN

    mov r17,r16
    swap r17
    andi r17,0xF0
    out PORTD,r17
    sbi PORTB,EN
    nop                   ; FIX: 8 NOPs on second nibble too
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    cbi PORTB,EN
    call delay_2ms
    ret

;=======================================
; LCD DATA
; FIX: EN pulse increased to 8 NOPs (~500ns) on both nibbles
;=======================================
writeDataToLCD:
    mov r17,r16
    andi r17,0xF0
    out PORTD,r17
    sbi PORTB,RS
    sbi PORTB,EN
    nop                   ; FIX: 8 NOPs = ~500ns, meets HD44780 450ns minimum
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    cbi PORTB,EN

    mov r17,r16
    swap r17
    andi r17,0xF0
    out PORTD,r17
    sbi PORTB,EN
    nop                   ; FIX: 8 NOPs on second nibble too
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    cbi PORTB,EN
    call delay_2ms
    ret

;=======================================
; DISPLAY ALARM INFO
; FIX: Added missing "call writeDataToLCD" for space character
;=======================================
display_alarm_info:
    ldi r16,0xC0
    call writeCmdToLCD
    ldi r16,'A'
    call writeDataToLCD
    ldi r16,'l'
    call writeDataToLCD
    ldi r16,'m'
    call writeDataToLCD
    ldi r16,':'
    call writeDataToLCD
    ldi r16,' '
    call writeDataToLCD   ; FIX: was missing in original

    lds temp_num,alarm_hr
    call print_2_digits
    ldi r16,':'
    call writeDataToLCD
    lds temp_num,alarm_min
    call print_2_digits

    lds r16,alarm_en
    cpi r16,1
    brne off_txt
    ldi r16,'O'
    call writeDataToLCD
    ldi r16,'N'
    call writeDataToLCD
    ret

off_txt:
    ldi r16,'O'
    call writeDataToLCD
    ldi r16,'F'
    call writeDataToLCD
    ldi r16,'F'
    call writeDataToLCD
    ret

;=======================================
; DELAYS
; FIX: delay_2ms rewritten with nested loop
;      Original: 200 x 3 = 600 cycles (~37us) -- far too short
;      Fixed:    53 x 200 x 3 = 31,800 cycles (~1.99ms at 16MHz)
;
; FIX: delay_20ms reduced from 200 calls to 10 calls (~20ms)
;      and now saves/restores r18
;=======================================
delay_2ms:
    push r19
    ldi r18, 53
outer:
    ldi r19, 200
inner:
    dec r19
    brne inner
    dec r18
    brne outer
    pop r19
    ret

delay_20ms:
    push r18
    ldi r18, 10
d3:
    call delay_2ms
    dec r18
    brne d3
    pop r18
    ret
