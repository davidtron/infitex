/* gui.pde
 GUI controls
 Copyright (c) 2014-2016 Kitronyx http://www.kitronyx.com
 contact@kitronyx.com
 GPL V3.0
 */
import java.util.Arrays;

// gui controls
DropdownList dSerial;
Button bStartStop;
Button b2D3D;
Button bLog;
Button bConfig;

void setupControl()
{
    int controlXPos0 = 10;
    int controlYPos0 = 20;
    int controlWidth = 70;
    int controlHeight = 15;
    int controlXStep = controlWidth + 20;
    int controlYStep = controlHeight + 5;
    int row = 0;
    cp5 = new ControlP5(this);
    
    // 2nd row
    row = 2;
    bStartStop = cp5.addButton("Start (s)", 0, controlXPos0, controlYPos0 + (row-1)*controlYStep, controlWidth, controlHeight);
    
    // 3rd row
    row = 3;
    bLog = cp5.addButton("Start Logging", 0, controlXPos0, controlYPos0 + (row-1)*controlYStep, controlWidth, controlHeight);
    
    // 3rd row
    row = 4;
    bConfig = cp5.addButton("Load INI", 0, controlXPos0, controlYPos0 + (row-1)*(controlYStep), controlWidth, controlHeight); 
    
    // 1st row
    row = 1;
    dSerial = cp5.addDropdownList("Serial").setPosition(controlXPos0, controlYPos0).setWidth(controlWidth);
    dSerial.getCaptionLabel().set("Choose Port");
    for (int i=0; i<Serial.list ().length; i++)
    {
        dSerial.addItem(Serial.list()[i], i);
    }
    
    
    // to be compatible with PeasyCam
    // http://www.sojamo.de/libraries/controlP5/examples/extra/ControlP5withPeasyCam/ControlP5withPeasyCam.pde
    cp5.setAutoDraw(false);
}

void controlEvent(ControlEvent theEvent)
{
    if (theEvent.isFrom("Serial"))
    {
       // check if the Event was triggered from a ControlGroup
       comPort = (String) dSerial.getItem(int(theEvent.getValue())).get("name");
       println("Setting com port to: " + comPort);
    } 
    else if (theEvent.isController())
    {
        if (theEvent.controller() == bStartStop)
        {
            if (do_data_acquisition) stopDevice();
            else startDevice();
        }
        else if (theEvent.controller() == bLog)
        {
            if (do_data_log) stopLog();
            else startLog();
        }
        else if (theEvent.controller() == bConfig)
        {
            selectInput("Select INI file to load.", "selectINI");
        }
    }
}

void selectINI(File selection)
{
    if (selection != null)
    {
        if (do_data_log) stopLog();
        if (do_data_acquisition) stopDevice();
        readINI(selection);
        applyINI();
    }
}

void startDevice()
{
    bStartStop.setCaptionLabel("Stop (s)");
                
    if (!comPort.equals("Not Found"))
    {
        startSerial();
        do_data_acquisition = true;
    }
    else
    {
        do_data_acquisition = false;
    }
}

void stopDevice()
{
    bStartStop.setCaptionLabel("Start (s)");
    a_port.stop();
    do_data_acquisition = false;
}

void startLog()
{
    bLog.setCaptionLabel("Stop Logging");
    dataLogger.createFileNameBasedOnTime();
    dataLogger.startLog(data.length, data[0].length);
    do_data_log = true;
}

void stopLog()
{
    bLog.setCaptionLabel("Start Logging");
    dataLogger.stopLog();
    do_data_log = false;
}

void drawControl()
{
    // see http://processingjs.org/reference/hint_/
    // for details about hint().
    hint(DISABLE_DEPTH_TEST);
    cam.beginHUD();
    cp5.draw();
    cam.endHUD();
    hint(ENABLE_DEPTH_TEST);
}

void drawLogo()
{
    fill(255);
    rect(width/2-100, 0, 200, 50, 0, 0, 100, 100);
    textAlign(CENTER);
    textSize(25);
    fill(0);
    text("Infi-tex", width/2, 30);
    fill(255);
}


void drawHelp()
{
    textSize(10);
    textAlign(RIGHT, BOTTOM);
    String strHelp = "2/3: switch between 2D/3D\n" +
        "(3D only) Left Click: Rotate Camera\n" +
        //"(3D only) Right Click: Pan Camera\n" +
        "(3D only) Scroll Wheel: Zoom In/Out\n" +
        "Up/Down: Scale Z Axis\n" +
        //"(3D only) p: Plot Method (Full Interpolation, Separate Interpolation, Cylinder)\n" +
        "(3D only) f: Toggle Grid Fill\n" +
        "(3D only) g: Toggle Grid\n" +
        "(3D only) h: Toggle heatmap\n" +
        "n: Toggle Background Noise Filtering\n" +
        "t: Thresholding (Circulating 0, 10, 20, 30, 40, 50)\n" +
        "d: Toggle Debug Output\n" +
        "x: X direction (normal/reverse)\n" +
        "y: Y direction (normal/reverse)\n" +
        "z: Z direction (normal/reverse)\n" +
        "r: Reset Settings\n" +
        "space: Toggle message display";
        
    text(strHelp, width-10, height-10);
}


void drawInfo()
{
    textAlign(RIGHT, TOP); 
    fill(255);
    String strInfo = "Port: " + comPort + "\n" +
        "Baud Rate: " + baudRate + "\n" +
        "Frame Rate: " + sensorFrameRate + " (ms)\n" +
        "Data Size: (" + data.length + ", " + data[0].length + ")\n" +
        "Active Plot Range: (" + ACTIVERANGE[0] + ", " + ACTIVERANGE[1] + ", " + ACTIVERANGE[2] + ", " + ACTIVERANGE[3] + ")\n" +
        "Z Axis Scale: " + zscale + "\n" +
        "Minimum Value (Current Frame): " + minFrame + "\n" +
        "Maximum Value (Current Frame): " + maxFrame + "\n" +
        "Background Noise Filtering: " + doBackgroundNoiseFiltering + "\n" +
        "Threshold Value: " + thresholdValue[thresholdValueIndex] + "\n" +
        "Camera Eye: (" + eyeX + ", " + eyeY + ", " + eyeZ + ")\n" + 
        "Translate: (" + transX + ", " + transY + ",)\n" +
        "X direction normal: " + xDir + "\n" +
        "Y direction normal: " + yDir + "\n" +
        "Z direction normal: " + zDir;
    text(strInfo, width-10, 10);
}


void drawMeasurement()
{
    textSize(10);
    textAlign(LEFT, BOTTOM);
    // print ordered matrix data - coincident with the sensor structure
    // http://stackoverflow.com/questions/409784/whats-the-simplest-way-to-print-an-array
    text(Arrays.deepToString(data).replaceAll("],", "],\r\n"), 10, height-10);
}

void drawCopyright()
{
    fill(255);
    textAlign(CENTER, BOTTOM);
    textSize(12);
    // If this is GPL3 we can modify.
    text("", width/2, height-10);
}

void drawGraph()
{
    getDataToDraw();
    
    // data visualization.
    // these functions use `data_to_draw` as a base data.
    pushMatrix(); 
    if (visualizationType == 2)
    {
        cam.beginHUD(); // do not use peasycam.
        visualization2D();
        cam.endHUD();
    }
    else if (visualizationType == 3)
    {
        rotateX(radians(45));
        visualization3D();
    }
    popMatrix();
}

void getDataToDraw()
{
    // decorate data to visualize using obtained sensor data.
    // here data in the range of display is picked up and
    // stored in `data_to_draw`.
    int drive_index_to_draw;
    int sense_index_to_draw;
    for (int i = ACTIVERANGE[0]-1; i < ACTIVERANGE[1]; i++)
    {
        for (int j = ACTIVERANGE[2]-1; j < ACTIVERANGE[3]; j++)
        {
            if (xDir == false)
            {
                sense_index_to_draw = ACTIVERANGE[3]-1-j;
            }
            else sense_index_to_draw = j;
            
            if (yDir == false)
            {
                drive_index_to_draw = ACTIVERANGE[1]-1-i;
            }
            else drive_index_to_draw = i;
            
            data_to_draw[i - ACTIVERANGE[0] + 1][j - ACTIVERANGE[2] + 1] = int(zscale*float(data[drive_index_to_draw][sense_index_to_draw]));
        }
    }
}