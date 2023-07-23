//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#property link      "https://github.com/baichen111"
#property version   "1.00"

//Enum

//Inputs & Global variables
sinput group                  "EA GENERAL SETTINGS"
input ulong                    MagicNumber = 101;

sinput group                  "MOVING AVERAGE SETTINGS"
input int                     MAPeriod = 30;
input ENUM_MA_METHOD          MAMethod = MODE_SMA;
input int                     MAShift = 0;
input ENUM_APPLIED_PRICE       MAPrice = PRICE_CLOSE;

sinput group "MONEY MANAGEMENT"
input double FixedVolume = 0.01;

sinput group "POSITION MANAGEMENT"
input ushort SLFixedPoints = 0;
input ushort SLFixedPointsMA = 200;
input ushort TPFixedPoints = 0;
input ushort TSLFixedPoints = 0; // trailing stop loss
input ushort BEFixedPoints = 0;  // break even point

datetime glTimeBarOpen;
int MAHandle;

// Event handlers
int OnInit() {
   glTimeBarOpen = D'1971.01.01 00.00';
   MAHandle = MA_Init(MAPeriod,MAShift,MAMethod,MAPrice);
   if(MAHandle == -1) {
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {


   Print("Expert removed");

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
// new bar control : check if new bar generated
   bool newBar = false;
   if(glTimeBarOpen != iTime(NULL,PERIOD_CURRENT,0)) {  // iTime: Returns the opening time of the bar (indicated by the 'shift' parameter) on the corresponding chart
      newBar = true;
      glTimeBarOpen = iTime(NULL,PERIOD_CURRENT,0);
   }

   if(newBar) {
      //price & indicators
      //price
      double close1 = Close(1);
      double close2 = Close(2);

      // Normalize close price to tick size; we can use NormalizeDouble method but recommended one is below to normalize prices
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);  //USDJPY 100.185 -> 0.001 ; TSL 85.74 -> 0.01
      close1 = round(close1/tickSize)*tickSize;
      close2 = round(close2/tickSize)*tickSize;

      // Moving Average
      double ma1 = ma(MAHandle,1);
      double ma2 = ma(MAHandle,2);

      // trade exit
      string exitSignal = MA_ExitSignal(close1,close2,ma1,ma2);
      if(exitSignal == "EXIT_LONG" || exitSignal == "EXIT_SHORT") {

      }
      Sleep(1000);

      // trade placement
      string entrySignal = MA_EntrySignal(close1,close2,ma1,ma2);
      if(entrySignal == "LONG" || entrySignal == "SHORT") {
         ulong ticket = OpenTrades(entrySignal,MagicNumber,FixedVolume);
      }
   }
}

// EA functions
//+------------------price functions------------------------------------------------+
double Close(int pShift) {                    // can also use iClose function
   MqlRates bar[];                            // array stores MqlRates objects
   ArraySetAsSeries(bar,true);                // it set array to a series array; so current bar is position 0, previous is 1 ,etc...
   CopyRates(_Symbol,PERIOD_CURRENT,0,3,bar); // copy bar price at 0,1,2 to our array
   return bar[pShift].close;
}
//+------------------------------------------------------------------+
double Open(int pShift) {
   MqlRates bar[];
   ArraySetAsSeries(bar,true);
   CopyRates(_Symbol,PERIOD_CURRENT,0,3,bar);
   return bar[pShift].open;
}
//+-------------Moving Average Functions-----------------------------------------------------+
int MA_Init(int pMAPeriod,int pMAShift,ENUM_MA_METHOD pMAMethod,ENUM_APPLIED_PRICE pMAPrice) {
   ResetLastError();

   int Handle = iMA(_Symbol,PERIOD_CURRENT,pMAPeriod,pMAShift,pMAMethod,pMAPrice);

   if(Handle == INVALID_HANDLE) {
      Print("Error creating MA indicator handle",GetLastError());
      return -1;

   }
   Print("MA indicator initialization successful !");
   return Handle;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ma(int pMAHandle,int pShift) {
   ResetLastError();

   double ma[];
   ArraySetAsSeries(ma,true);

//fill array with the 3 most recent ma values
   bool fillResult = CopyBuffer(pMAHandle,0,0,3,ma);
   if(fillResult == false) {
      Print("FILL ERROR: ", GetLastError());
   }

   double maValue = ma[pShift];

//normalize maValue
   maValue = NormalizeDouble(maValue,_Digits);

   return maValue;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string MA_EntrySignal(double pPrice1,double pPrice2, double pMA1,double pMA2) {
   string str;
   if(pPrice1 > pMA1 && pPrice2 <= pMA2) {
      str = "LONG";
   } else if(pPrice1 < pMA1 && pPrice2 >= pMA2) {
      str = "SHORT";
   } else {
      str = "NO_TRADE";
   }
   return str;

}
//+-------------MA Trade Exit Functions-----------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string MA_ExitSignal(double pPrice1,double pPrice2, double pMA1,double pMA2) {
   string str;
   if(pPrice2 >= pMA2 && pPrice1 < pMA1) {
      str = "EXIT_LONG";
   } else if(pPrice2 <= pMA2 && pPrice1 > pMA1) {
      str = "EXIT_SHORT";
   } else {
      str = "NO_EXIT";
   }
   return str;
}
//+-------------------------------------------------------------------------------------------+



//+-------------Bollinger Bands Functions-----------------------------------------------------+
int BB_Init(int pBBPeriod,int pBBShift,double pBBDeviation,ENUM_APPLIED_PRICE pBBPrice) {
   ResetLastError();

   int Handle = iBands(_Symbol,PERIOD_CURRENT,pBBPeriod,pBBShift,pBBDeviation,pBBPrice);

   if(Handle == INVALID_HANDLE) {
      Print("Error creating BB indicator handle",GetLastError());
      return -1;
   }
   Print("BB indicator initialization successful !");
   return Handle;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double BB(int pBBHandle,int pBBLineBuffer,int pShift) {
   ResetLastError();

   double bb[];
   ArraySetAsSeries(bb,true);

//fill array with the 3 most recent ma values
   bool fillResult = CopyBuffer(pBBHandle,pBBLineBuffer,0,3,bb);
   if(fillResult == false) {
      Print("FILL ERROR: ", GetLastError());
   }
   double bbValue = bb[pShift];

//normalize maValue
   bbValue = NormalizeDouble(bbValue,_Digits);

   return bbValue;
}

//+-------------Order Placement Functions-----------------------------------------------------+
ulong OpenTrades(string pEntrySignal,ulong pMagicNumber,double pFixedVol) {
   double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

// price must be normalized either to digits or ticksize
   askPrice = round(askPrice/tickSize)*tickSize;
   bidPrice = round(bidPrice/tickSize)*tickSize;

   string comment = pEntrySignal + " | " + _Symbol + " | " + string(pMagicNumber);

//Request and result Declaration and Initialization
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   if(pEntrySignal == "LONG") {
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = pFixedVol;
      request.type = ORDER_TYPE_BUY;
      request.price = askPrice;
      request.deviation = 10;
      request.magic = pMagicNumber;
      request.comment = comment;
      //Request send
      if(!OrderSend(request,result)) {
         Print("Order send trade placement error: ", GetLastError());  // if requet order not sent, print error code
      }
      Print("Open ",request.symbol," ",pEntrySignal," #",result.order," : ",result.retcode,", Volume: ",result.volume,", Price: ",DoubleToString(askPrice,_Digits));  // retcode 10018: market closed

   } else if(pEntrySignal == "SHORT") {
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.volume = pFixedVol;
      request.type = ORDER_TYPE_SELL;
      request.price = bidPrice;
      request.deviation = 10;
      request.magic = pMagicNumber;
      request.comment = comment;
      //Request send
      if(!OrderSend(request,result)) {
         Print("Order send trade placement error: ", GetLastError());  // if requet order not sent, print error code
      }
      Print("Open ",request.symbol," ",pEntrySignal," #",result.order," : ",result.retcode,", Volume: ",result.volume,", Price: ",DoubleToString(bidPrice,_Digits));  // retcode 10018: market closed
   }
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_NO_CHANGES){
      
      return result.order;                         // return order ticket
   }
   return 0;

}
//+------------------------------------------------------------------+
