/**********************************************************************************************************
* Project: MatrixArrayVisualizer.pde
* By: Chris Wittmier @ Sensitronics LLC
**********************************************************************************************************/ 
import processing.serial.*;
 
 
/**********************************************************************************************************
* CONSTANTS
**********************************************************************************************************/
int COLS = 16;
int  ROWS = 16;
int CELL_SIZE = 20;
int END_MARKER = 0xFF;
int SCALE_READING = 2;
int min_force_thresh = 1;

boolean INVERT_X_AXIS = false;
boolean INVERT_Y_AXIS = false;
boolean SWAP_AXES = true;


/**********************************************************************************************************
* GLOBALS
**********************************************************************************************************/
Cell[][] grid;
Serial sPort;

int xcount = 0;
int ycount = 0;
boolean got_zero = false;
int got_byte_count = 0;
int last_byte_count = 0;


/**********************************************************************************************************
* setup()
**********************************************************************************************************/
void setup() 
{
  background(0, 0, 0);
  
  int port_count = Serial.list().length;
  sPort = new Serial(this, Serial.list()[port_count - 1], 115200);  
  
  size(640, 640);

  
  grid = new Cell[COLS][ROWS];
  for (int i = 0; i < COLS; i++)
  {
    for (int j = 0; j < ROWS; j++)
    {
      grid[i][j] = new Cell(i * CELL_SIZE, j * CELL_SIZE, CELL_SIZE, CELL_SIZE);
    }
  }

}


/**********************************************************************************************************
* draw()
**********************************************************************************************************/
void draw() 
{
  rxRefresh();
}



/**********************************************************************************************************
* rxRefresh()
**********************************************************************************************************/
void rxRefresh() 
{
  while(sPort.available() > 0)
  {
    byte got_byte = (byte) sPort.read();
    got_byte_count ++;
    int unsigned_force = got_byte & 0xFF;
    if(unsigned_force == END_MARKER)
    {
      xcount = 0;
      ycount = 0;
    }
    else if(got_zero)
    {
      for(int i = 0; i < unsigned_force; i ++)
      {
        updatePixel(xcount, ycount, 0);
        xcount ++;
        if(xcount >= COLS)
        {
          xcount = 0;
          ycount ++;
          if(ycount >= ROWS)
          {
            ycount = ROWS - 1;
          }
        }
      }
      got_zero = false;
    }
    else if(got_byte == 0)
    {
      got_zero = true;
    }
    else
    {
      updatePixel(xcount, ycount, unsigned_force);
      xcount ++;
      if(xcount >= COLS)
      {
        xcount = 0;
        ycount ++;
        if(ycount >= ROWS)
        {
          ycount = ROWS - 1;
        }
      }
    }
  }
}



/**********************************************************************************************************
* updatePixel()
**********************************************************************************************************/
void updatePixel(int xpos, int ypos, int force)
{
  if(SWAP_AXES)
  {
    int temp = xpos;
    xpos = ypos;
    ypos = temp;
  }
  if((xpos < ROWS) && (ypos < COLS))
  {
    if(INVERT_Y_AXIS)
    {
      xpos = (COLS - 1) - xpos;
    }
    if(INVERT_X_AXIS)
    {
      ypos = (COLS - 1) - ypos;
    }
    grid[ypos][xpos].display(force);
  }
}


/**********************************************************************************************************
* class Cell
**********************************************************************************************************/
class Cell 
{
  float x, y;
  float w, h;
  int current_force = 0;
  float calibrated = 0;
  
  Cell(float tempX, float tempY, float tempW, float tempH) 
  {
    x = tempX;
    y = tempY;
    w = tempW;
    h = tempH;
  } 

  void display(int newforce) 
  {
    if(newforce < min_force_thresh)
    {
      newforce = 0;
    }
    else
    {
      newforce *= SCALE_READING;
    }
    if(newforce != current_force)
    {
      noStroke();
      fill(0, newforce, 0);
      rect(x, y, w, h); 
      current_force = newforce;
    }
  }
 
}