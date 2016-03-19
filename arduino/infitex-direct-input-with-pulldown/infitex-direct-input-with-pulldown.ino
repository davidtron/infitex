
const int columns = 16; //Define columns number ( between 1 and 16 )
const int rows = 14;    //Define rows number (between 1 and 54)
const int factor = 1.5;    //signal amplifying factor

//declaration of the INPUT pins we will use; i is the position within the array for the columns
int pin[] = {A15, A14, A13, A12, A11, A10, A9, A8, A7, A6, A5, A4, A3, A2, A1, A0};

//declaration of the OUTPUT pins we will use; i is the position within the array for the rows
int dpin[] = {23, 25, 27, 29, 31, 33, 35, 37, 36, 34, 32, 30, 28, 26};     

int sensorValue[columns];   // array of column values read row by row
int msensorValue[columns];  // array of values sent to processing


// Define various ADC prescaler
const unsigned char PS_16 = (1 << ADPS2);
const unsigned char PS_32 = (1 << ADPS2) | (1 << ADPS0);
const unsigned char PS_64 = (1 << ADPS2) | (1 << ADPS1);
const unsigned char PS_128 = (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);


void setup() {

  // Analog input for columns
  for (int j = 0; j <= columns - 1 ; j++) {
    pinMode (pin[j], INPUT);
  }

  // Digital output for rows
  for (int k = 0; k <=rows - 1; k++) {
    pinMode(dpin[k], OUTPUT); 
  }

  Serial.begin(115200);   //turn serial on

  // set up the ADC
  ADCSRA &= ~PS_128;  // remove bits set by Arduino library

  // you can choose a prescaler from above.
  // PS_16, PS_32, PS_64 or PS_128
  ADCSRA |= PS_32;    // set our own prescaler to 32

}

void loop() {
      
    for (int i = 0; i < rows ; i++) {

      digitalWrite (dpin[i], HIGH); //turn row i on
      for (int m = 0; m < columns ; m++) {
        sensorValue[m] = factor * analogRead (pin[m]); //read value column m
        // delay(1);
        if (sensorValue[m] < 1) {   // this is to reduce noise
          sensorValue[m] = 0;
        }

        msensorValue[m] = map (sensorValue[m], 0, 1024, 0, 255);    //map all values read to a new range from 0 to 255

        Serial.print(msensorValue[m]);
        if(!(i == rows-1 && m ==columns-1)) {
          Serial.print(",");
        }
      }
      digitalWrite (dpin[i], LOW); //turn row i off
    }

    // This needs to print the last value (we are currently missing it)
    Serial.println();
}


