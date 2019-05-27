/////////////////////////////////////////////////////////////
// IoTsemi_GW_XBee_Draw
// 2015/10/29 by K.Seo
// 2019/5/2 by K.Seo
/////////////////////////////////////////////////////////////
// ZigBee通信によるセンサデータ受信＋センサデータ表示プログラム
// ・M2Mデバイスから温度/照度センサデータの受信
//  （ZigBee受信パケットで複数センサデータを受信）
// ・温度/照度センサデータを温度計/照度計として図式表示
// ・M2Mデバイスを10個まで扱う
/////////////////////////////////////////////////////////////
import processing.serial.*; 

import com.rapplogic.xbee.api.ApiId;
import com.rapplogic.xbee.api.PacketListener;
import com.rapplogic.xbee.api.XBee;
import com.rapplogic.xbee.api.XBeeResponse;
import com.rapplogic.xbee.api.XBeeRequest;
import com.rapplogic.xbee.api.zigbee.ZNetRxIoSampleResponse;

// *** REPLACE WITH THE SERIAL PORT (COM PORT) FOR YOUR LOCAL XBEE ***
String mySerialPort = "COM5";

// used to record time of last data post
float lastUpdateDevice = 0.0;

int error=0;
int drawTempIllu=1;

// make an array list of m2mDevice objects for display
ArrayList m2mDevices = new ArrayList();
// create a font for display
PFont font;

// create and initialize a new xbee object
XBee xbee = new XBee();

////////////////////////////////////////////////////////////////////////
void setup() {
  size(800, 600); // screen size
//  noStroke();
  smooth(); // anti-aliasing for graphic display

  // You’ll need to generate a font before you can run this sketch.
  // Click the Tools menu and choose Create Font. Click Sans Serif,
  // choose a size of 10, and click OK.
  font =  loadFont("SansSerif-10.vlw");
  textFont(font); // use the font for text

  // The log4j.properties file is required by the xbee api library, and 
  // needs to be in your data folder. You can find this file in the xbee
  // api library you downloaded earlier
  PropertyConfigurator.configure(dataPath("")+"/log4j.properties"); 
  // Print a list in case the selected one doesn't work out
  println("Available serial ports:");
  println(Serial.list());
//
  try {
    // opens your serial port defined above, at 9600 baud
    xbee.open(mySerialPort, 9600);
  }
  catch (XBeeException e) {
    println("** Error opening XBee port: " + e + " **");
    println("Is your XBee plugged in to your computer?");
    println(
      "Did you set your COM port in the code?");
    error=1;
  }
  xbee.addPacketListener(new PacketListener() {
    SensorData m2mData;
    public void processResponse(XBeeResponse response) {
//      println ("processResponse");
      if ( !response.isError()) {
        int sensorDataGot = 0;
// check that this frame is a valid IO sample response.       
        if (response.getApiId() == ApiId.ZNET_IO_SAMPLE_RESPONSE ) { 
          m2mData=getDataXBeeDirect(response); sensorDataGot=1;
        }
// check that this frame is a valid RX response,
        else if (response.getApiId() == ApiId.ZNET_RX_RESPONSE) { 
          m2mData=getDataArduino(response); sensorDataGot = 1; 
        }   
// check that
        else if (response.getApiId() == ApiId.ZNET_TX_STATUS_RESPONSE) {  
          println ("ZNET_TX_STATUS_RESPONSE");
          ZNetTxStatusResponse txStatus = (ZNetTxStatusResponse) response;
          if (txStatus.getRemoteAddress16().equals(XBeeAddress16.ZNET_BROADCAST)) {
       // specify 16-bit address for faster routing?.. really only need to do this when it changes
           println ("Same 16bits Address");
          }
        }
      if (sensorDataGot == 1 ) {
       registM2mDevice(m2mData);
       }
     }      
    }
  });
}

///////////////////////////////////////////////////////////
// draw loop executes continuously
void draw() {
  fill(224);
// if error , system stop
  if (error == 1) { 
    println ("System stop"); 
    exit();
  }
//  Draw sensor data
  if ((millis() - lastUpdateDevice) >10000) {
    if ((drawTempIllu & 0x01) != 0) {
      background(224); // draw a light gray background
      drawM2mDevice(drawTempIllu);
      lastUpdateDevice = millis();              
    }
  }
// 
}// end of draw loop

///////////////////////////////////////////////////////////
SensorData getDataArduino(XBeeResponse response) {
  SensorData data = new SensorData();
  float value0;      // returns an impossible value if there's an error
  float value1;     // 
  data.mode = 1; // Device(sensor) mode
  String address = "000000000000 "; // returns a null value if there's an error  
        ZNetRxResponse rxResponse = 
        (ZNetRxResponse)(XBeeResponse) response;
      // get the sender's 64-bit address
      int[] addressArray = rxResponse.getRemoteAddress64().getAddress();
      // parse the address int array into a formatted string
      String[] hexAddress = new String[addressArray.length];
      for (int i=0; i<addressArray.length;i++) {
        // format each address byte with leading zeros:
        hexAddress[i] = String.format("%02x", addressArray[i]);
      }
      // join the array together for a numeric address:
      long numericAddress = unhex(join(hexAddress,""));
      data.numericAddr = numericAddress;
      print("numeric address: " + numericAddress);
      // join the array together with colons for readability:
      String senderAddress = join(hexAddress, ":"); 
      print("  sender address: " + senderAddress);
      data.address = senderAddress;
      // get the rx data
      int [] rxValue = rxResponse.getData();
      // parse the address int array into a formatted string
      String[] hexResponse = new String[rxValue.length];
      for (int i=0; i<rxValue.length;i++) {
        hexResponse[i] = String.format("%02x", rxValue[i]);
      }
      print("  rx value: " + join(hexResponse,"")); 
      data.valid = 0;
      for ( int i=2; i<rxValue.length; i+=5){
        int attributeID = rxValue[i+1]*256+rxValue[i];
        int attributeType = rxValue[i+2];
        int attributeData = rxValue[i+4]*256+rxValue[i+3];
        switch(attributeID) { 
          case 1:
                data.value0 = attributeData;
                data.valid |= 1;
                break;
          case 2:
                data.value1 = attributeData;
                data.valid |= 2;
                break;
          case 3:
                data.value2 = attributeData;
                data.valid |= 4;
                break;        
          case 4:
                data.value3 = attributeData;
                data.valid |= 8;
                break;
          default: 
        }
        print("  Sensor value: " + attributeData ); 
      }
  return data; // sends the data back to the calling function
}
///////////////////////////////////////////////////////////
SensorData getDataXBeeDirect(XBeeResponse response) {
  SensorData data = new SensorData();
  float value0;      // returns an impossible value if there's an error
  float value1;     // 
  data.mode = 1; // Device(sensr) mode
  String address = "000000000000 "; // returns a null value if there's an error

      ZNetRxIoSampleResponse ioSample = 
        (ZNetRxIoSampleResponse)(XBeeResponse) response;

      // get the sender's 64-bit address
      int[] addressArray = ioSample.getRemoteAddress64().getAddress();
      // parse the address int array into a formatted string
      String[] hexAddress = new String[addressArray.length];
      for (int i=0; i<addressArray.length;i++) {
        // format each address byte with leading zeros:
        hexAddress[i] = String.format("%02x", addressArray[i]);
      }
      // join the array together for a numeric address:
      long numericAddress = unhex(join(hexAddress,""));
      data.numericAddr = numericAddress;
      print("numeric address: " + numericAddress);
      // join the array together with colons for readability:
      String senderAddress = join(hexAddress, ":"); 
      print("  sender address: " + senderAddress);
      data.address = senderAddress;
      // get the value of the first input pin

      value0 = ((ioSample.getAnalog0()/1024.0*1.2*3.0*100)-273.15)*100;
      print("  analog value0: " + value0 ); 
      data.value0 = value0;
      // get the value of the second input pin
      value1 = ((100/0.26) * ( ioSample.getAnalog1()/1024.0)*1.2/0.3)*100;
      print("  analog value1: " + value1 ); 
      data.value1 = value1;
      data.valid = 3;
  return data; // sends the data back to the calling function
}
///////////////////////////////////////////////////////////
void registM2mDevice(SensorData data) {
  float temperatureCelsius=0.0;
  float illuminance=0.0;  
  // check that actual data came in:
  if (data.value0 >=0 && data.address != null) { 
    // check to see if a m2mDevice object already exists for this sensor
    int i;
    boolean foundIt = false;
    for (i=0; i <m2mDevices.size(); i++) {
      if ( ((M2MDevice) m2mDevices.get(i)).address.equals(data.address) ) {
        foundIt = true;
        break;
      }
    }
    if (foundIt == false && m2mDevices.size() < 10) {
      m2mDevices.add(new M2MDevice(0,data.address,35,450,
      (m2mDevices.size()) * 75 + 80, 20, data.numericAddr));
      foundIt = true;      
    }  
    // update the m2mDevice if it exists, otherwise create a new one
    println (" i="+i+" foundIt "+foundIt+" valid="+data.valid);
    if (foundIt) {
      ((M2MDevice) m2mDevices.get(i)).mode = data.mode;  
      ((M2MDevice) m2mDevices.get(i)).valid = ((M2MDevice) m2mDevices.get(i)).valid | data.valid;      
      if ((data.valid & 0x01) != 0) {
        temperatureCelsius =data.value0/100;
        print(" temp: " + round(temperatureCelsius) + "?C");        
        ((M2MDevice) m2mDevices.get(i)).temp = temperatureCelsius;
      }
      if ((data.valid & 0x02) != 0) {
        illuminance =data.value1/100;
        println(" illu: " + round(illuminance));        
        ((M2MDevice) m2mDevices.get(i)).illu = illuminance;
      }
      // others1
      if ((data.valid & 0x04) != 0) {
        ((M2MDevice) m2mDevices.get(i)).others1 = data.value2;        
      }    
      // others2
      if ((data.valid & 0x08) != 0) {
        ((M2MDevice) m2mDevices.get(i)).others2 = data.value3;        
      }        
    }
  }
}
///////////////////////////////////////////////////////////
//
// draw the m2mDevices on the screen
//
void drawM2mDevice(int mode) {
    for (int j =0; j<m2mDevices.size(); j++) {
      int deviceMode = ((M2MDevice) m2mDevices.get(j)).mode;
      if ( (deviceMode & mode) !=0) {
       ((M2MDevice) m2mDevices.get(j)).render(j);
      }
    }
} 
///////////////////////////////////////////////////////////
// defines the data object
class SensorData {
  int mode;  // 0:Device mode, 1:Cloud mode
  int valid;
  float value0;
  float value1;
  float value2;
  float value3;
  String address;
  long numericAddr;
}
///////////////////////////////////////////////////////////
// defines m2mDevice objects
class M2MDevice {
  int mode; // 1:Device(sensor) mode, 2:Cloud mode
  int valid;
  int sizeX, sizeY, posX, posY;
  int maxTemp = 40; // max of scale in degrees Celsius
  int minTemp = -10; // min of scale in degress Celsius
  float temp; // stores the temperature locally
  float illu; // stores the illuminance locally
  float others1;
  float others2;
  String address; // stores the address locally
  long numAddr; // stores the numeric version of the address

  M2MDevice(int _mode, String _address, int _sizeX, int _sizeY, 
  int _posX, int _posY, long _numAddr) { // initialize m2mDevice object
    mode = _mode;
    address = _address;
    sizeX = _sizeX;
    sizeY = _sizeY;
    posX = _posX;
    posY = _posY;
    numAddr = _numAddr;
  }
//
  void render(int dNo) { // draw m2mDevice and luminometer on screen
    ellipseMode(CENTER); // center bulb
    // m2mDevice
    float displayTemp = round( temp);
    if (temp > maxTemp) {
      displayTemp = maxTemp + 1;
    }
    if ((int)temp < minTemp) {
      displayTemp = minTemp;
    }
    // size for variable red area:
    float mercury = ( 1 - ( (displayTemp-minTemp) / (maxTemp-minTemp) )); 
    // draw grey mercury background
    stroke(#000000);
    strokeWeight(1);
    rectMode(CORNER);
    fill(#B4B4B4);
//    println ("pos="+posX+" "+posY+" "+sizeX+" "+sizeY);
    rect(posX,posY,sizeX,sizeY);
    // draw mercury red areas
    fill(255,16,16);
    rect(posX,posY+(sizeY * mercury), sizeX, sizeY-(sizeY * mercury));

    // illuminance
    float logIllu = log10(int(illu));
    if (logIllu>4.0 ) logIllu =4.0; 
    if (logIllu<0.0 ) logIllu=0.0;
    fill(int(logIllu*256/4.0));
    ellipse(posX+sizeX/2,posY+sizeY+sizeX/2+10,sizeX+4,sizeX+4);
    // println(logIllu+" "+int(logIllu*256/4.0));

    // show text
    textAlign(LEFT);
    fill(0);
    textSize(10);

    // show maximum temperature: 
    text(maxTemp + "?C", posX+sizeX + 5, posY); 

    // show minimum temperature:
    text(minTemp + "?C", posX+sizeX + 5, posY + sizeY); 

    // show temperature:
    text(round(temp) + " ?C", posX+sizeX + 5,posY+(sizeY * mercury+ 14)); 
    
    // show illuminance
    text(nf(round(illu),4), posX+sizeX + 5, posY+sizeY+sizeX/2+12);    
    text("  lx", posX+sizeX + 5, posY+sizeY+sizeX/2+24);
    
       // show sensor address:
    text(address, posX-5, posY + sizeY + sizeX + 18, 65, 40);
  
    // show device no
    int deNo = dNo + 1;
    String deviceHeader =deNo+":";
    text(deviceHeader, posX, 15);
  }
}
///////////////////////////////////////////////////////////
// Calculates the base-10 logarithm of a number
float log10 (int x) {
  return (log(x) / log(10));
}
