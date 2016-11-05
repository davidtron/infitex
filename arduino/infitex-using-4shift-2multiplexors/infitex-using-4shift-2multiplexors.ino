/**
 * Code is based on an amalgamation of:
 *  Initial optimisation based on sensitronics: http://sensitronics.com/tutorials/fsr-matrix-array/page6.php
 *  Since we are using the shift register breakout board: http://maximumoctopus.com/electronics/ultrashiftotron.htm#
 *  Subsequently optimised to use SPI instead software shiftOut:  http://forum.arduino.cc/index.php?topic=52383.0
 *  
 *  This does not need an arduino mega and can be run on a smaller cheaper arduino compatible board.
 */
#include <SPI.h>

#define BAUD_RATE                 115200
#define ROW_COUNT                 16      // rows are read by multiplexor
#define COLUMN_COUNT              16      // columns are set by shift register

// Reads the multiplexed input back to one arduino pin
#define PIN_ADC_INPUT             A0

// Input pins on the ultra-shift-o-tron (quad 74HC595 shift register breakout board)
// ARDUINO Mega Pin 52 (SPI:SCK)                   --->  74HC595 Pin 11 (SCK "Shift register clock input") SH_CP
// ARDUINO Mega Pin 51 (SPI:MOSI)                  --->  74HC595 Pin 14 (SER "Serial Data Input") DS
// ARDUINO Mega Pin 53 SS (generic digital output) --->  74HC595 Pin 12 (RCK "Storage register clock input") ST_CP

// ARDUINO UNO Pin 13 (SPI:SCK)                    --->  74HC595 Pin 11 (SCK "Shift register clock input")  SH_CP
// ARDUINO UNO Pin 11 (SPI:MOSI)                   --->  74HC595 Pin 14 (SER "Serial Data Input") DS
// ARDUINO UNO Pin 10 SS (generic digital output)  --->  74HC595 Pin 12 (RCK "Storage register clock input") ST_CP

#define SHIFT_REGISTER_LATCH_SS (53)
// The other pins for SCK and MOSI are defined by SPI library and do not need to be controlled in this sketch

// Channel pins 0, 1, 2 for multiplexors must be wired to consecutive Arduino pins
#define PIN_MUX_CHANNEL_0         5  
#define PIN_MUX_CHANNEL_1         6
#define PIN_MUX_CHANNEL_2         7

// inhibit = active low enable. All multiplexors IC enables must be wired to consecutive Arduino pins
#define PIN_MUX_INHIBIT_0         8 
#define PIN_MUX_INHIBIT_1         9
#define PIN_MUX_INHIBIT_2         10
#define PIN_MUX_INHIBIT_3         11

// To switch out different multiplexor types
#define ROWS_PER_MUX              8
#define MUX_COUNT                 2
#define CHANNEL_PINS_PER_MUX      3

#define PACKET_END_BYTE           0xFF
#define MAX_SEND_VALUE            254  //reserve 255 (0xFF) to mark end of packet
#define COMPRESSED_ZERO_LIMIT     254
#define MIN_SEND_VALUE            1    //values below this threshold will be treated and sent as zeros


int current_enabled_mux = MUX_COUNT - 1;  //init to number of last mux so enabled mux increments to first mux on first scan.
int compressed_zero_count = 0;


void setup() { 
  Serial.begin(BAUD_RATE);
  
  //initialize SPI:  
  SPI.setBitOrder(MSBFIRST);
  SPI.begin();
  pinMode(SHIFT_REGISTER_LATCH_SS, OUTPUT);
  // The other pins for SCK and MOSI are defined by SPI library and do not need to be controlled in this sketch
 
  //clear all shift registers so that all output pins go low.
  // If we chained another ultashiftotron board there would be another 4 bytes zeroed here
  
  SPI.transfer(0x00);
  SPI.transfer(0x00);
  SPI.transfer(0x00);
  SPI.transfer(0x00);
  digitalWrite(SHIFT_REGISTER_LATCH_SS, LOW);
  digitalWrite(SHIFT_REGISTER_LATCH_SS, HIGH);

  // Set up pins to control the array of multiplexors
  pinMode(PIN_MUX_CHANNEL_0, OUTPUT);
  pinMode(PIN_MUX_CHANNEL_1, OUTPUT);
  pinMode(PIN_MUX_CHANNEL_2, OUTPUT);
  pinMode(PIN_MUX_INHIBIT_0, OUTPUT);
  pinMode(PIN_MUX_INHIBIT_1, OUTPUT);
  pinMode(PIN_MUX_INHIBIT_2, OUTPUT);
  pinMode(PIN_MUX_INHIBIT_3, OUTPUT);
}

/**
 * Main run loop sends reading of the entire matrix per loop
 */
void loop() {
  compressed_zero_count = 0;
  
  for(int i = 0; i < ROW_COUNT; i ++) {
    setRow(i);
    
    for(int j = 0; j < COLUMN_COUNT; j ++) {

      setColumn(j);
      int raw_reading = analogRead(PIN_ADC_INPUT);
      byte send_reading = (byte) (lowByte(raw_reading >> 2));
      sendCompressed(send_reading);
    } 
  }
  if(compressed_zero_count > 0) {
        Serial.write((byte) 0);
        Serial.write((byte) compressed_zero_count);
  }
  Serial.write((byte) PACKET_END_BYTE);
}


/**
 * setRow() - Enable single mux IC and channel to read specified matrix row.
 */
void setRow(int row_number) {
  if((row_number % ROWS_PER_MUX) == 0) { // We've reached channel 0 of a mux IC, so disable the previous mux IC, and enable the next mux IC
  
    digitalWrite(PIN_MUX_INHIBIT_0 + current_enabled_mux, HIGH);  //Muxes are enabled using offset from MUX_INHIBIT_0. This is why mux inhibits MUST be wired to consecutive Arduino pins!
    current_enabled_mux ++;
    if(current_enabled_mux >= MUX_COUNT) {
      current_enabled_mux = 0;
    }
    digitalWrite(PIN_MUX_INHIBIT_0 + current_enabled_mux, LOW);  //enable the next mux, active low
  }
  for(int i = 0; i < CHANNEL_PINS_PER_MUX; i ++) {
    if(bitRead(row_number, i)) {
      digitalWrite(PIN_MUX_CHANNEL_0 + i, HIGH);
    }
    else {
      digitalWrite(PIN_MUX_CHANNEL_0 + i, LOW);
    }
  }
}

/**
 * Send to ultrashiftotron
 */
void setColumn(int columnNumber) {
  unsigned long bitpattern = 1l<<columnNumber; 

  // If we chained another ultashiftotron board there would be another 4 bytes sent here shifted as 56,48,40,32
 // If we only use 10 pins on the shiftotron, we only transfer 2 bytes (16bits)
 // enable the other 2 to give 32bit shift
 
 
 // SPI.transfer(bitpattern >> 24);
 // SPI.transfer(bitpattern >> 16);
  SPI.transfer(bitpattern >> 8);
  SPI.transfer(bitpattern);

  digitalWrite(SHIFT_REGISTER_LATCH_SS, LOW);
  digitalWrite(SHIFT_REGISTER_LATCH_SS, HIGH);
}


/**
 * sendCompressed() - If value is nonzero, send it via serial terminal as a single byte. If value is zero,
 * increment zero count. The current zero count is sent and cleared before the next nonzero value
 */
void sendCompressed(byte value) {
  if(value < MIN_SEND_VALUE) {
    if(compressed_zero_count < (COMPRESSED_ZERO_LIMIT - 1)) {
      compressed_zero_count ++;
    }
    else {
      Serial.write((byte) 0);
      Serial.write((byte) COMPRESSED_ZERO_LIMIT);
      compressed_zero_count = 0; 
    }
  }
  else {
    if(compressed_zero_count > 0) {
      Serial.write((byte) 0);
      Serial.write((byte) compressed_zero_count);
      compressed_zero_count = 0;
    }
    if(value > MAX_SEND_VALUE) {
       Serial.write((byte) MAX_SEND_VALUE);
    }
    else {
       Serial.write((byte) value);
    }
  }
}


