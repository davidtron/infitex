/* DataLogger.pde
 Log data in CSV format
 Copyright (c) 2014-2016 Kitronyx http://www.kitronyx.com
 contact@kitronyx.com
 GPL V3.0
 */
import java.io.BufferedWriter;
import java.io.FileWriter;

class DataLogger
{
    String filename_1d;
    String filename_2d;
    PrintWriter pw_1d = null;
    PrintWriter pw_2d = null;;
    boolean is_logging = false;
    int log_index = 0;
    
    void createFileNameBasedOnTime()
    {
        String date = String.format("%04d%02d%02dT%02d%02d%02d", year(), month(), day(), hour(), minute(), second());
        println(date);
        filename_1d = dataPath(date + "-1d.csv");
        filename_2d = dataPath(date + "-2d.csv");
    }
    
    void startLog(int nrow, int ncol)
    {
        try
        {
            pw_1d = new PrintWriter(new FileWriter(filename_1d, true));
            pw_2d = new PrintWriter(new FileWriter(filename_2d, true));
        }
        catch(IOException e)
        {
            e.printStackTrace();
        }
        finally
        {
            is_logging = true;
            log_index = 0;
            
            // make header for 1d log data
            pw_1d.print("Frame Index,");
            
            for (int i = 0; i < nrow-1; i++)
            {
                for (int j = 0; j < ncol; j++)
                {
                    pw_1d.print("R"+i+"C"+j+",");
                }
            }
            
            for (int j = 0; j < ncol-1; j++)
            {
                pw_1d.print("R"+(nrow-1)+"C"+j+",");
            }
            pw_1d.println("R"+(nrow-1)+"C"+(ncol-1));
        }
    }
    
    void logData(int[][] d)
    {
        if (is_logging == true)
        {
            pw_1d.println(log_index + "," + convert2DArrayTo1DString(d));
            pw_2d.println("Frame " + log_index);
            pw_2d.println(convert2DArrayTo2DString(d));
            log_index++;
        }
    }
    
    String convert2DArrayTo2DString(int[][] d)
    {
        String out = "";
        for (int i = 0; i < d.length-1; i++)
        {
            for (int j = 0; j < d[0].length-1; j++)
            {
                out = out + d[i][j] + ",";
            }
            out = out + d[i][d[0].length-1] + "\n";
        }
        
        for (int j = 0; j < d[0].length-1; j++)
        {
            out = out + d[d.length-1][j] + ",";
        }
        out = out + d[d.length-1][d[0].length-1];
        
        return out;
    }
    
    String convert2DArrayTo1DString(int[][] d)
    {
        String out = "";
        for (int i = 0; i < d.length-1; i++)
        {
            for (int j = 0; j < d[0].length; j++)
            {
                out = out + d[i][j] + ",";
            }
        }
        
        for (int j = 0; j < d[0].length-1; j++)
        {
            out = out + d[d.length-1][j] + ",";
        }
        out = out + d[d.length-1][d[0].length-1];
        
        return out;
    }
    
    void stopLog()
    {
        if (pw_1d != null)
        {
            pw_1d.flush();
            pw_1d.close();
        }
        
        if (pw_2d != null)
        {
            pw_2d.flush();
            pw_2d.close();
        }
        
        is_logging = false;
    }
}