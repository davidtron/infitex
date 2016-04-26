/* Based on Snowforce.pde Visualization software for the Snowboard 
 GPL V3.0
 */
import processing.serial.*; // import the Processing serial library
import controlP5.*;
import peasy.*;
import java.awt.event.*;

ControlP5 cp5;
PeasyCam cam;
CameraState state;
DataLogger dataLogger;

// icon and title
final static String ICON = "snowforce.png";
final static String TITLE = "infi-tex";

// max ad value to adopt
final int MAXVAL = 254;
int MAXDRIVE = 32;
int MAXSENSE = 32;
int END_MARKER = 0xFF;

// configuration parameters read from david.ini
String DEVICE = "arduinomega";
int NDRIVE;
int NSENSE;
int INTERPSCALE;
String PORT; // com port
int[] ACTIVERANGE; // actual sensor data to show [rmin, rmax, cmin, cmax]
int[] driveindex;
int[] senseindex;

// general application information
boolean do_data_acquisition = false;
boolean do_data_log = false;
Serial a_port;
String comPort;
int baudRate=115200;
String packetType="compressed";
PrintWriter debugLog;

// data and statistics
int[][] data;
int[][] data_to_draw;
int[][] backgroundNoise;
int[][] out_interp2d;
int minFrame = 0;
int maxFrame = 0;
int current_time = millis();
float sensorFrameRate;
String strSensorData;

// camera control parameters
int sx; // width of one grid cell
int sy; // height of one grid cell
float eyeX, eyeY, eyeZ; // camera eye position
float transX, transY; // translation of 3d graphic
float oldMouseX, newMouseX, mouseDx;
float oldMouseY, newMouseY, mouseDy;

// preprocessing - data and visualization control
boolean fillGrid; // fill grid or not
boolean doBackgroundNoiseFiltering;
// thresholinding in visulatization.
int nThresholdValue = 6;
int[] thresholdValue = {
    0, 10, 20, 30, 40, 50
};
int thresholdValueIndex = 0;

// misc.
int visualizationType = 3; // 2 (2D) or 3 (3D).
boolean printDebugInfo = false;
int plotMethod = 0; // interp, separate interp, and cylinder
boolean drawGrid = true;
float zscale = 4; // control z axis scale of graph
boolean xDir = true;
boolean yDir = true;
boolean zDir = true;
boolean drawHeatmap = false;
boolean drawMessages = true;
boolean showMeasurement = true;

int globalCount = 0;

void setup()
{
    // initialize screen
    size(800, 600, P3D);   

    // look at width/2, height/2, 0 at distance 1000
    cam = new PeasyCam(this, width/2, height/2, 0, (width/800)*1000);
    cam.setMinimumDistance(50);
    cam.setMaximumDistance(15500);
    state = cam.getState();

    changeAppIcon( loadImage(ICON) );
    changeAppTitle(TITLE);
    
    fillGrid = true;
    doBackgroundNoiseFiltering = false;
    
    // read configuration
    readINI(null); // read default ini files
    applyINI();
    
    
    setupSerial(); // initialize serial communication.
    setupControl(); // setup gui controls
    
    cam.lookAt(frame.getWidth()/2, frame.getHeight()/2, 0, (width/800)*1000);
    
    debugLog = createWriter("infitex-debug.log"); 
}

void readINI(File selection)
{
    String[] config;
    String delims = "=";
    String[] tokens;
    
    if (selection == null) config = loadStrings("david.ini");
    else config= loadStrings(selection.getAbsolutePath());
        
    tokens = config[0].split(delims);
    DEVICE = tokens[1];
    if (DEVICE.equals("arduinomega"))
    {
        MAXDRIVE = 32;
        MAXSENSE = 32;
    }
    else if (DEVICE.equals("mc1509"))
    {
        MAXDRIVE = 48;
        MAXSENSE = 48;
    }   

    tokens = config[1].split(delims);
    NDRIVE = int(tokens[1]);

    tokens = config[2].split(delims);
    NSENSE = int(tokens[1]);

    tokens = config[3].split(delims);
    ACTIVERANGE = int(split(tokens[1], ','));

    tokens = config[4].split(delims);
    INTERPSCALE = int(tokens[1]);

    tokens = config[5].split(delims);
    PORT = tokens[1];
    
    tokens = config[6].split(delims);
    baudRate = int(tokens[1]);

    tokens = config[7].split(delims);
    xDir = boolean(tokens[1]);

    tokens = config[8].split(delims);
    yDir = boolean(tokens[1]);

    tokens = config[9].split(delims);
    zDir = boolean(tokens[1]);

    tokens = config[10].split(delims);
    driveindex = int(split(tokens[1], ','));

    tokens = config[11].split(delims);
    senseindex = int(split(tokens[1], ','));
    
    tokens = config[12].split(delims);
    packetType = tokens[1];
    
}

void applyINI()
{
    // initialize module variables
    data = new int[NDRIVE][NSENSE];
    int nrow_data_to_draw = ACTIVERANGE[1]-ACTIVERANGE[0]+1;
    int ncol_data_to_draw = ACTIVERANGE[3]-ACTIVERANGE[2]+1;
    data_to_draw = new int[nrow_data_to_draw][ncol_data_to_draw];
    backgroundNoise = new int[NDRIVE][NSENSE];
    out_interp2d = new int[ncol_data_to_draw*INTERPSCALE][ncol_data_to_draw*INTERPSCALE];

    for (int i = 0; i < data.length; i++)
    {
        for (int j = 0; j < data[i].length; j++)
        {
            data[i][j] = 0;
            backgroundNoise[i][j] = 0;
        }
    }

    // grid setting
    sx = width/data.length;
    sy = height/data[0].length;

    sensorFrameRate = 0;
    strSensorData = "";

    dataLogger = new DataLogger();
}


void setupSerial()
{
    if (Serial.list().length == 0) // no device.
    {
        comPort = "Not Found";
        println("Device not attached.");
    } else
    {
        if (PORT.equals("auto")) comPort = Serial.list()[1];
        else comPort = PORT;

        println(comPort);
    }
}

void startSerial()
{
    if (comPort.equals("Not Found"))
    { // create virtual data if serial port or device is not available.
        for (int i = 0; i < data.length; i++)
        {
            for (int j = 0; j < data[0].length; j++)
            {
                data[i][j] = int(random(0, 50));
            }
        }
    } else
    { // serial port initialization with error handling
        a_port = new Serial(this, comPort, baudRate, 'N', 8, 1);
        //a_port = new Serial(this, Serial.list()[1], 115200);

        println("Initializing communication");
        int comm_init_start = millis();
        int comm_init_wait_time = 5000; // ms; 5s
        
        /*
        while (true)
        {
            a_port.write("A");
            if (a_port.readStringUntil(10) != null)
            {
                println("Establised communication!");
                break;
            }
            if ( (millis() - comm_init_start) > comm_init_wait_time )
            {
                println("Can't establish communication with Serial");
                comPort = "Not Found";
                break;
            }
        }
        */
        
    }
}

void draw()
{
    // read data from the Snowboard
    if (do_data_acquisition && !comPort.equals("Not Found")) {
      getData(); 
    }
    
    background(70, 100, 255);

    drawGraph();

    if (drawMessages == true)
    {
        // beginHUD() and endHUD() are for avoiding interference by PeasyCam
        // while drawing texts.
        // http://forum.processing.org/two/discussion/4470/solved-how-to-use-peasy-cam-without-affecting-the-text-position/p1
        cam.beginHUD();
        drawLogo();
        drawHelp();
        drawInfo();
        //drawCopyright();
        if (showMeasurement == true) drawMeasurement(); // sensor 2D measurement
        //drawCopyright();

        cam.endHUD();
        drawControl();
    }

    dataLogger.logData(data);
}

// get heatmap rgb values
int[] jet(float min, float max, float x)
{
    float r, g, b;
    float dv;

    r = 1;
    g = 1;
    b = 1;

    if (x < min) x = min;
    if (x > max) x = max;
    dv = max - min;

    if (x < (min + 0.25*dv))
    {
        r = 0;
        g = 4 * (x - min) / dv;
    } else if (x < (min + 0.5 * dv))
    {
        r = 0;
        b = 1 + 4 * (min + 0.25 * dv - x) / dv;
    } else if (x < (min + 0.75 * dv))
    {
        r = 4 * (x - min - 0.5 * dv) / dv;
        b = 0;
    } else
    {
        g = 1 + 4 * (min + 0.75 * dv - x) / dv;
        b = 0;
    }

    int[] rgb = new int[3];
    rgb[0] = int(255*r);
    rgb[1] = int(255*g);
    rgb[2] = int(255*b);
    return rgb;
}

// 2D visualization (heatmap)
void visualization2D()
{
    // interp2d will output `out_interp2d`.
    interp2d(data_to_draw);

    int nrow = out_interp2d.length;
    int ncol = out_interp2d[0].length;

    PImage img = createImage(nrow, ncol, RGB);

    for (int i = 0; i < nrow; i++)
    {
        for (int j = 0; j < ncol; j++)
        {
            int[] rgb = jet(0, 255, float(out_interp2d[i][j]));
            img.pixels[i*ncol + j] = color(rgb[0], rgb[1], rgb[2]);//color(204, 153, 0, out_interp2d[i][j]);
        }
    }

    int w, h; // 4:3 ratio
    if (nrow > ncol)
    {
        w = 480;
        h = 360;
    } else
    {
        w = 360;
        h = 480;
    }

    int x0 = (width-w)/2;
    int y0 = (height-h)/2;

    img.resize(w, h);
    image(img, x0, y0);
}


void visualization3D()
{
    switch (plotMethod)
    {
    case 0: // 1) Full interpolation
        interp2d(data_to_draw);
        surf(out_interp2d, drawGrid, zDir);
        break;

    case 1: // 2) Fill 0 between data to separte each cell
        // pending 2 zero rows/cols on upper and left edge.
        // if not, interpolated graph is shifted to upper and left direction.
        // probably due to the inherent characterstics of bicubic interpolation?
        int[][] data_to_draw_fill0 = new int[2*data_to_draw.length+2][2*data_to_draw[0].length+2];
        for (int i = 0; i < data_to_draw_fill0.length; i++)
        {
            for (int j = 0; j < data_to_draw_fill0[0].length; j++)
            {
                data_to_draw_fill0[i][j] = 0;
            }
        }

        for (int i = 0; i < data_to_draw.length; i++)
        {
            for (int j = 0; j < data_to_draw[0].length; j++)
            {
                data_to_draw_fill0[2*(i+1)][2*(j+1)] = data_to_draw[i][j];
            }
        }

        interp2d(data_to_draw_fill0);

        surf(out_interp2d, drawGrid, zDir);
        break;

    // obsolete. no longer supported.
    case 2: // 3) Cylinder plot
        interp2d(data_to_draw);
        for (int i = 0; i < out_interp2d.length; i++)
        {
            for (int j = 0; j < out_interp2d[0].length; j++)
            {
                out_interp2d[i][j] = 0;
            }
        }

        surf(out_interp2d, drawGrid, zDir);

        int[][] ccolor = {
            {
                255, 0, 0
            }
            , {
                0, 255, 0
            }
            , {
                0, 0, 255
            }
            , {
                255, 0, 255
            }
        };
        int k = 0;
        for (int i = 0; i < data_to_draw.length; i++)
        {
            for (int j = 0; j < data_to_draw[0].length; j++)
            {
                int color_index = k % ccolor.length;
                float x = width / (data_to_draw[0].length + 1) * (j + 1);
                float y = height / (data_to_draw.length + 1) * (i + 1);
                float r = width / ( 4*(data_to_draw[0].length + 1) );
                // 0 height cylider causes overlapped ugly plot.
                if (data_to_draw[i][j] > 0) drawCylinder(x, y, 30, r, r, data_to_draw[i][j], ccolor[color_index]);
                k++;
            }
        }
        break;
    }
}

// data acquisition
boolean getData()
{
    // lock buffer.
    //print("*");

    // request data
    //a_port.write("A");
   

    
    // read the serial buffer:
    int [] sensors = new int[NDRIVE*NSENSE];
    
    if (packetType.equals("string")) {     
        String myString = a_port.readStringUntil('\n');
        if (myString == null) {
          print(".");
          return false;
        }
        println("got data " + myString);
    
        // if you got any bytes other than the linefeed:
        myString = trim(myString);
    
        // split the string at the commas
        // and convert the sections into integers:
        sensors = int(split(myString, ','));
    } else if (packetType.equals("binary")) {
        int[] resp = new int[NDRIVE*NSENSE];
        byte[] buffer = new byte[NDRIVE*NSENSE];
        int nread = 0;
        int offset = 0;
        while (true) {
            if (a_port.available() > 0) {
                nread = a_port.readBytes(buffer);
                for (int i = 0; i < nread; i++) { 
                  resp[offset + i] = (int)(buffer[i]) & 0xFF;
                }
                offset += nread;
            }
            if (offset == NDRIVE*NSENSE) break;
        }
        
        if (offset != NDRIVE*NSENSE) return false;
        
        for (int i = 0; i < sensors.length; i++) { 
          // Copy the data into sensors
          sensors[i] = resp[i];
        }
    } else if (packetType.equals("compressed")) {
        boolean got_zero = false;
        int[] resp = new int[NDRIVE*NSENSE];
        int offset = 0;
        debugLog.println("trying for data " + globalCount);
        
        while (true) {
            if (a_port.available() > 0) {
              byte got_byte = (byte) a_port.read();
              int unsigned_force = got_byte & 0xFF;
              if(unsigned_force == END_MARKER) {
                // End of the frame
                debugLog.println("End frame");
                break;
              } else if(got_zero) {
                debugLog.println("found 0s = "+unsigned_force + ". Offset is " + offset);

                // We send 0 as 2 bytes, the 0 then the amount
                for(int i = 0; i < unsigned_force; i ++) {
                    // Add 0's to resp here. Sometimes this is bigger than the array - how?
                    if(offset+i < resp.length) {
                      resp[offset+i]=0;                      
                    } else {
                      debugLog.println("Somehow bigger than the array?");
                      return false;
                    }
                    

                }
                
                // Increment the reading for the number of 0s we just inserted
                offset = offset + unsigned_force;
                got_zero = false;
              } else if(got_byte == 0) {
                // Store that we got zero so we know next byte is how many zeros
                got_zero = true;
              } else {
                debugLog.println("found "+unsigned_force + ". Offset is " + offset);
                resp[offset] = unsigned_force;
                offset++;
              }
            } else {
              debugLog.println("not bytes available?");
            }
        }
        
        // Error check
        if (offset != NDRIVE*NSENSE) {
          debugLog.println("Incorrect amount of data received offset was " + offset +". Expected "+ NDRIVE*NSENSE);
          return false;
        } else {
          debugLog.println("Correct frame of data");
        }
        for (int i = 0; i < sensors.length; i++) { 
          // Copy the data into sensors
          sensors[i] = resp[i];
        }
    }
    

    // statistics of sensor data.
    // get min and max value of current frame.
    minFrame = 100000;
    maxFrame = 0;
    for (int i = 0; i < sensors.length; i++)
    {
        if (sensors[i] < minFrame) minFrame = sensors[i];
        if (sensors[i] > maxFrame) maxFrame = sensors[i];
    }

    // error checking.
    if (sensors.length != MAXDRIVE*MAXSENSE)
    {
        print("Incorrect data: ");
        print(sensors.length);
        println(" bytes. Expected " + MAXDRIVE*MAXSENSE);


        return false;
    }

    globalCount++;
    debugLog.flush();
    // create information for gui.     
    strSensorData = "";
    sensorFrameRate = millis() - current_time;

    // copy sensor data to variables for gui
    // preprocessing (filtering) is done here.
    int k = 0;
    for (int i = 0; i < data.length; i++)
    {
        for (int j = 0; j < data[0].length; j++)
        {
            // offset removal
            if (doBackgroundNoiseFiltering == true)
            {

                data[driveindex[i]][senseindex[j]] = sensors[k++] - backgroundNoise[driveindex[i]][senseindex[j]];
                if (data[driveindex[i]][senseindex[j]] < 0) data[driveindex[i]][senseindex[j]] = 0;
            } else
            {
                data[driveindex[i]][senseindex[j]] = sensors[k++];
            }

            // thresholding
            if (thresholdValueIndex != 0)
            {
                if (data[driveindex[i]][senseindex[j]] < thresholdValue[thresholdValueIndex]) data[driveindex[i]][senseindex[j]] = 0;
            }

            strSensorData += data[driveindex[i]][senseindex[j]] + ",";
        }
        strSensorData += "\n";
    }

    // debug print
    if (printDebugInfo == true)
    {
        print("DT:");
        print(sensorFrameRate);
        print("ms, ");
        print("SENSOR: (");
        print(data.length);
        print(", ");
        print(data[0].length);
        print("): [");
        for (int i = 0; i < data.length; i++)
        {
            for (int j = 0; j < data[i].length; j++)
            {
                print(data[i][j]);
                print(",");
            }
        }
        println("]");
    }

    // update curren time
    current_time = millis();

    return true;
}


// main plotting function
void surf(int[][] data, boolean grid_on, boolean zdir)
{
    int sx = width/data.length;
    int sy = height/data[0].length;

    if (zdir == false)
    {
        for (int i = 0; i < data.length; i++)
        {
            for (int j = 0; j < data[0].length; j++)
            {
                data[i][j] = -data[i][j];
            }
        }
    }


    noStroke();

    // draw grid
    if (grid_on == true)
    {
        for (int i = 0; i < data.length-1; i++)
        {
            for (int j = 0; j < data[i].length-1; j++)
            {
                // fill the first cell with red color
                stroke(31, 31, 31, 80);
                strokeWeight(3);
                noFill();

                beginShape();
                vertex((i+1)*sx, j*sy, data[i+1][j]);
                vertex((i+1)*sx, (j+1)*sy, data[i+1][j+1]);
                vertex(i*sx, (j+1)*sy, data[i][j+1]);
                endShape();
            }
        }
    }

    // fill grid
    if (fillGrid == true)
    {
        for (int i = 1; i < data.length; i++)
        {
            for (int j = 1; j < data[i].length; j++)
            {
                // fill the first cell with green color
                noStroke();
                
                if (i == 1 && j == 1) fill(0, 255, 0);
                else fill(255, 0, 0);

                beginShape();
                vertex((i-1)*sx, (j-1)*sy, data[i-1][j-1]);
                vertex(i*sx, (j-1)*sy, data[i][j-1]);
                vertex((i-1)*sx, j*sy, data[i-1][j]);
                endShape();

                beginShape();
                vertex(i*sx, (j-1)*sy, data[i][j-1]);
                vertex(i*sx, j*sy, data[i][j]);
                vertex((i-1)*sx, j*sy, data[i-1][j]);
                endShape();
            }
        }
    }
}


// bicubic interpolation of 2D array.
void interp2d(int[][] x)
{
    int nrowx = x.length;
    int ncolx = x[0].length;
    int nrowy = out_interp2d.length;
    int ncoly = out_interp2d[0].length;

    int x1, x2, x3, x4, y1, y2, y3, y4;
    float v1, v2, v3, v4, v;
    float xx, yy, p, q;

    for (int i = 0; i < nrowy; i++)
    {
        for (int j = 0; j < ncoly; j++)
        {
            xx = (float)(ncolx*j)/(float)(ncoly);
            yy = (float)(nrowx*i)/(float)(nrowy);

            x2 = (int)xx;
            x1 = x2 - 1;
            if (x1 < 0) x1 = 0;
            x3 = x2 + 1;
            if (x3 >= ncolx) x3 = ncolx - 1;
            x4 = x2 + 2;
            if (x4 >= ncolx) x4 = ncolx - 1;
            p = xx - x2;

            y2 = (int)yy;
            y1 = y2 - 1;
            if (y1 < 0) y1 = 0;
            y3 = y2 + 1;
            if (y3 >= nrowx) y3 = nrowx - 1;
            y4 = y2 + 2;
            if (y4 >= nrowx) y4 = nrowx - 1;
            q = yy - y2;

            v1 = cubicci(float(x[y1][x1]), float(x[y1][x2]), float(x[y1][x3]), float(x[y1][x4]), p);
            v2 = cubicci(float(x[y2][x1]), float(x[y2][x2]), float(x[y2][x3]), float(x[y2][x4]), p);
            v3 = cubicci(float(x[y3][x1]), float(x[y3][x2]), float(x[y3][x3]), float(x[y3][x4]), p);
            v4 = cubicci(float(x[y4][x1]), float(x[y4][x2]), float(x[y4][x3]), float(x[y4][x4]), p);

            v = cubicci(v1, v2, v3, v4, q);

            if (v < 0) v = 0; // to avoid negative value.

            out_interp2d[i][j] = int(v);
        }
    }
}

// cubic Convolution Interpolation - called by interp2d().
float cubicci(float v1, float v2, float v3, float v4, float d)
{
    float v, p1, p2, p3, p4;

    p1 = v2;
    p2 = -v1 + v3;
    p3 = 2*(v1-v2) + v3 - v4;
    p4 = -v1 + v2 - v3 + v4;

    v = p1 + d*(p2 + d*(p3 + d*p4));

    return v;
}


void keyPressed()
{
    // grid fill
    if (key == 'f') fillGrid = !fillGrid;

    // background noise filtering
    if (key == 'n')
    {
        doBackgroundNoiseFiltering = !doBackgroundNoiseFiltering;
        if (doBackgroundNoiseFiltering == true)
        {
            for (int i = 0; i < data.length; i++)
            {
                for (int j = 0; j < data[0].length; j++)
                {
                    backgroundNoise[i][j] = data[i][j];
                }
            }
        }
    }

    // thresholding
    if (key == 't')
    {
        thresholdValueIndex++;
        if (thresholdValueIndex == nThresholdValue) thresholdValueIndex = 0;
    }

    // print debug output
    if (key == 'd') printDebugInfo = !printDebugInfo;

    // circulate plot method
    if (key == 'p')
    {
        plotMethod++;
        if (plotMethod == 3) plotMethod = 0;
    }

    if (key == 'g') drawGrid = !drawGrid;

    if (key == 'x') xDir = !xDir;

    if (key == 'y') yDir = !yDir;

    if (key == 'z') zDir = !zDir;

    if (key == CODED)
    {
        if (keyCode == UP) zscale = 2.0f * zscale;
        if (keyCode == DOWN) zscale = zscale / 2.0f;
    }

    if (key == '2') visualizationType = 2;

    if (key == '3') visualizationType = 3;

    if (key == 'h') drawHeatmap = !drawHeatmap;

    if (key == ' ') drawMessages = !drawMessages;
    
    if (key == 'm') showMeasurement = !showMeasurement;
}


// change applicaion icons
// http://forum.processing.org/one/topic/how-to-change-the-icon-of-the-app.html
void changeAppIcon(PImage img)
{
    final PGraphics pg = createGraphics(48, 48, JAVA2D);

    pg.beginDraw();
    pg.image(img, 0, 0, 48, 48);
    pg.endDraw();

    frame.setIconImage(pg.image);
}

void changeAppTitle(String title)
{
    surface.setTitle(title);
}

// draw cylider. this function is based on the code below:
// http://vormplus.be/blog/article/drawing-a-cylinder-with-processing
void drawCylinder( float x0, float y0, int sides, float r1, float r2, float h, int[] cylinderColor)
{
    fill(cylinderColor[0], cylinderColor[1], cylinderColor[2]);
    noStroke();
    float angle = 360 / sides;
    float halfHeight = h / 2;
    // top
    beginShape();
    for (int i = 0; i < sides; i++) {
        float x = cos( radians( i * angle ) ) * r1 + x0;
        float y = sin( radians( i * angle ) ) * r1 + y0;
        vertex( x, y, 0);
    }
    endShape(CLOSE);
    // bottom
    beginShape();
    for (int i = 0; i < sides; i++) {
        float x = cos( radians( i * angle ) ) * r2 + x0;
        float y = sin( radians( i * angle ) ) * r2 + y0;
        vertex( x, y, h);
    }
    endShape(CLOSE);
    // draw body
    beginShape(TRIANGLE_STRIP);
    for (int i = 0; i < sides + 1; i++) {
        float x1 = cos( radians( i * angle ) ) * r1 + x0;
        float y1 = sin( radians( i * angle ) ) * r1 + y0;
        float x2 = cos( radians( i * angle ) ) * r2 + x0;
        float y2 = sin( radians( i * angle ) ) * r2 + y0;
        vertex( x1, y1, 0);
        vertex( x2, y2, h);
    }
    endShape(CLOSE);
}

void stop()
{
    if (dataLogger.is_logging == true) dataLogger.stopLog();
}