
#define BAUD_RATE                 115200
#define ROW_COUNT                 32
#define COLUMN_COUNT              32

// Reads the multiplexed input back to one arduino pin
#define PIN_ADC_INPUT             A0

// Input pins on the ultra-shift-o-tron (quad 74HC595 shift register breakout board)
#define PIN_LATCH_ST_CP           2
#define PIN_CLOCK_SH_CP           3
#define PIN_DATA_DS               4

// Channel pins 0, 1, 2 for multiplexors must be wired to consecutive Arduino pins
#define PIN_MUX_CHANNEL_0         5  
#define PIN_MUX_CHANNEL_1         6
#define PIN_MUX_CHANNEL_2         7

// inhibit = active low enable. All mux IC enables must be wired to consecutive Arduino pins
#define PIN_MUX_INHIBIT_0         8 
#define PIN_MUX_INHIBIT_1         9
#define PIN_MUX_INHIBIT_2         10
#define PIN_MUX_INHIBIT_3         11

// To switch out different multiplexor types
#define ROWS_PER_MUX              8
#define MUX_COUNT                 4
#define CHANNEL_PINS_PER_MUX      3

int current_enabled_mux = MUX_COUNT - 1;  //init to number of last mux so enabled mux increments to first mux on first scan.


void setup() { 
  Serial.begin(BAUD_RATE);
  
  // Setup pins to output so you can control the shift register
  pinMode(PIN_LATCH_ST_CP, OUTPUT);
  pinMode(PIN_CLOCK_SH_CP, OUTPUT);
  pinMode(PIN_DATA_DS, OUTPUT);

  // Set up pins to control the array of multiplexors
  pinMode(PIN_MUX_CHANNEL_0, OUTPUT);
  pinMode(PIN_MUX_CHANNEL_1, OUTPUT);
  pinMode(PIN_MUX_CHANNEL_2, OUTPUT);
  pinMode(PIN_MUX_INHIBIT_0, OUTPUT);
  pinMode(PIN_MUX_INHIBIT_1, OUTPUT);
}

void loop() {
  for(int i = 0; i < ROW_COUNT; i ++) {
    setRow(i);
    
    for(int j = 0; j < COLUMN_COUNT; j ++) {

      setColumn(j);
      int raw_reading = analogRead(PIN_ADC_INPUT);
      byte send_reading = (byte) (lowByte(raw_reading >> 2));
      printFixed(send_reading);
      Serial.print(" ");
    }
    Serial.println();
  }
  Serial.println();
  delay(200);
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
void setColumn(int rowNumber) {

  unsigned long bitpattern = 1<<rowNumber; 
  
  // tell the 595s we're about to add some new data!
  digitalWrite(PIN_LATCH_ST_CP, LOW);

  // This block sets the bit pattern of what to write out
  // if we wanted to add 8 595's we would call 8 shifts
  // TODO: cleaned up with a loop to make code more manageable.
  // See what arbitrary number bit shifted
  shiftOut(PIN_DATA_DS, PIN_CLOCK_SH_CP, MSBFIRST, ((bitpattern >> 24) & 255));
  shiftOut(PIN_DATA_DS, PIN_CLOCK_SH_CP, MSBFIRST, ((bitpattern >> 16) & 255));
  shiftOut(PIN_DATA_DS, PIN_CLOCK_SH_CP, MSBFIRST, ((bitpattern >> 8) & 255));
  shiftOut(PIN_DATA_DS, PIN_CLOCK_SH_CP, MSBFIRST, (bitpattern & 255));

  //tell the 595s to ouput our data. 
  digitalWrite(PIN_LATCH_ST_CP, HIGH);
}

/**********************************************************************************************************
* printFixed() - print a value padded with leading spaces such that the value always occupies a fixed
* number of characters / space in the output terminal.
**********************************************************************************************************/
void printFixed(byte value) {
  if(value < 10)
  {
    Serial.print("  ");
  }
  else if(value < 100)
  {
    Serial.print(" ");
  }
  Serial.print(value);
}


