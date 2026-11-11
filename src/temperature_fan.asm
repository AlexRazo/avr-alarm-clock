/*CLC Code
 Members: Alex Razo, Matthew Shamalla, Isaac Atonson
 Date: March 31, 2026
*/
    
    /* Temp Sensor*/
    
    .include "m328Pdef.inc"
;*******************************
; Main Programa
;*********************--**********
Main:
   ; Initialize the stack pointer
    ldi r16, HIGH(RAMEND)   ; Load high byte of RAMEND into r16
    out sph, r16            ; Set stack pointer high byte
    ldi r16, LOW(RAMEND)    ; Load low byte of RAMEND into r16
    out spl, r16            ; Set stack pointer low byte
  
    call initGPIO           ; Call GPIO initialization function
    call initADC            ; Call ADC initialization function
 
ReadADC:
    ldi r16, 0x87 | (1<<ADSC)  ; Enable ADC and start conversion
    sts ADCSRA, r16            ; Store value to ADCSRA register to start ADC conversion
 
WaitEOC:
    lds r16, ADCSRA        ; Load ADC Status Register A
    sbrs r16, ADIF         ; Skip next instruction if ADC Interrupt Flag is set (conversion complete)
    rjmp WaitEOC           ; Loop until conversion is complete
    ldi r16, (1<<ADIF)     ; Load value to clear ADC interrupt flag
    sts ADCSRA, r16        ; Store to ADCSRA to clear the ADIF flag
 
    lds r16, ADCL          ; Load low byte of ADC result first (important for 10-bit ADC read)
    lds r17, ADCH          ; Load high byte of ADC result
 
    cpi r16, 155   ; Compare ADC result with # (temperature threshold)
    brsh EnableFan         ; If ADC value >= 142, branch to EnableFan
    rjmp DisableFan        ; Otherwise, branch to DisableFan
 
EnableFan:    
    sbi PORTB, 0           ; Set PORTB bit 0 to turn on the fan
    rjmp ReadADC           ; Repeat ADC reading loop
 
DisableFan:
    cbi PORTB, 0           ; Clear PORTB bit 0 to turn off the fan
    rjmp ReadADC           ; Repeat ADC reading loop
 
/**************************************
Function: initGPIO
Initializes GPIO settings
***************************************/
initGPIO:
    sbi DDRB, 0            ; Set PORTB bit 0 as output (Fan control)
    ldi r16, 0
    out DDRC, r16          ; Set all PORTC pins as inputs (ADC input)
    ret                    ; Return from subroutine
  
/**************************************
Function: initADC
Configures ADC settings
***************************************/
initADC:  
    ldi r16, 0b10000111    ; Enable ADC, select clk/128 prescaler (16MHz/128 = 125kHz)
    sts ADCSRA, r16        ; Store to ADC Status Register A
    ldi r16, 0b01000000    ; Select AVcc as reference voltage, enable ADC0 (PC0)
    sts ADMUX, r16         ; Store to ADC Multiplexer Selection Register (right-justified result)
    ret                    ; Return from subroutine
