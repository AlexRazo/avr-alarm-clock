# 24-Hour Alarm Clock with Temperature Monitoring (ATmega328P, AVR Assembly)

A 24-hour alarm clock built on an ATmega328P microcontroller and written entirely in AVR Assembly. It keeps time with a hardware timer, shows the time and alarm on a 16x2 LCD, sounds a buzzer at the alarm time, and uses a TMP36 sensor to switch a fan on when it gets too warm.

**Demo video:** [Watch on YouTube](https://www.youtube.com/shorts/ipeXLS_9Pr4)

EEE-212 team project, Grand Canyon University, Spring 2026.
Team: Alex Razo, Matthew Shamalla, Aaron Cab, Isaac Atonson

## Features

- **Timekeeping:** Timer1 in CTC mode (16 MHz clock, 1024 prescaler, compare value 15625) produces an exact 1-second tick. The code rolls seconds into minutes and minutes into hours on a 24-hour cycle.
- **LCD display:** a 16x2 HD44780-style LCD driven in 4-bit mode shows `HH:MM:SS` on line 1 and the alarm time and ON/OFF status on line 2.
- **Four push buttons** with internal pull-ups and 20 ms software debouncing:
  - PC1: set hour
  - PC2: set minute
  - PC3: tap to set alarm hour, hold for about 1 second to turn the alarm on or off
  - PC4: set alarm minute
- **Alarm:** when the alarm is on and the time matches, the buzzer on PB3 beeps for the first 30 seconds of that minute.
- **Temperature monitoring:** the 10-bit ADC reads a TMP36 sensor on PC0 and turns a fan on PB0 on above a set threshold.

## Hardware

| Part | Purpose |
| --- | --- |
| ATmega328P (16 MHz) | Microcontroller |
| 16x2 LCD + 10 kΩ potentiometer | Display and contrast |
| 4 tactile push buttons | Time and alarm setting |
| 5 V buzzer | Alarm |
| TMP36 temperature sensor | Temperature input |
| Breadboard, jumper wires, USB cable | Wiring and programming |

## Files

- `src/alarm_clock.asm`: final alarm clock code (timekeeping, buttons, LCD, alarm)
- `src/temperature_fan.asm`: TMP36 reading with the ADC and threshold fan control

## Tools

MPLAB X IDE, AVR assembler (`m328Pdef.inc`), ATmega328P.

## What I'd improve next

- Move timekeeping into a Timer1 compare-match interrupt so button handling can never delay the clock
- Show the live temperature on the LCD next to the time
- Support multiple alarms and a snooze button
