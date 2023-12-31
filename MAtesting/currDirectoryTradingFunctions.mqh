//+------------------------------------------------------------------+
//|                                 stdDirectoryTradingFunctions.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Bai Chen"
#property link      "github.com/baichen111"
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
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_NO_CHANGES) {

      return result.order;                         // return order ticket
   }
   return 0;

}

//+-------------------------Trade Modification-----------------------------------------+
void TradeModification(ulong ticket,ulong pMagic,double pSLPrice,double pTPPrice) {
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   MqlTradeRequest request =  {};
   MqlTradeResult  result = {};

   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = _Symbol;
   request.sl = round(pSLPrice / tickSize) * tickSize;
   request.tp = round(pTPPrice / tickSize) * tickSize;
   request.comment = "MOD. "+" | "+_Symbol+ " | "+ string(pMagic) + ", SL: "+DoubleToString(request.sl,_Digits)+", TP: "+DoubleToString(request.tp,_Digits);

   if(request.sl > 0 || request.tp > 0) {
      Sleep(1000);
      bool sent = OrderSend(request,result);
      Print(result.comment);
      if(!sent) {
         Print("OrderSend Modification Error: ",GetLastError());
         Sleep(3000);

         sent = OrderSend(request,result);
         Print(result.comment);
         if(!sent)
            Print("OrderSend Modification 2nd try Error: ", GetLastError());

      }
   }
}




//+-------------------------Checked Positions-----------------------------------------+
bool CheckPlacedPositions(ulong pMagic) {
   bool placedPositions = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong positionTicket = PositionGetTicket(i);
      PositionSelectByTicket(positionTicket);

      ulong posMagic = PositionGetInteger(POSITION_MAGIC);

      if(posMagic == pMagic) {
         placedPositions = true;
         break;
      }
   }
   return placedPositions;
}
//+------------------------Close Positions------------------------------------------+
void CloseTrades(ulong pMagic,string pExitSignal) {
//Request and result declaration and initialization
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   for(int i = PositionsTotal() - 1; i>=0; i--) {
      //Reset request and result values
      ZeroMemory(request);
      ZeroMemory(result);

      ulong positionTicket = PositionGetTicket(i);
      PositionSelectByTicket(positionTicket);     // Selects an open position to work with based on the ticket number specified in the position

      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      ulong posType = PositionGetInteger(POSITION_TYPE);

      if(posMagic == pMagic && pExitSignal == "EXIT_LONG" && posType == ORDER_TYPE_BUY) {
         request.action = TRADE_ACTION_DEAL;
         request.type = ORDER_TYPE_SELL;
         request.symbol = _Symbol;
         request.position = positionTicket;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         request.deviation = 10;

         bool sent = OrderSend(request,result);
         if(sent == true) {
            Print("Position #",positionTicket," closed");
         }

      } else if(posMagic == pMagic && pExitSignal == "EXIT_SHORT" && posType == ORDER_TYPE_SELL) {
         request.action = TRADE_ACTION_DEAL;
         request.type = ORDER_TYPE_BUY;
         request.symbol = _Symbol;
         request.position = positionTicket;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         request.deviation = 10;

         bool sent = OrderSend(request,result);
         if(sent == true) {
            Print("Position #",positionTicket," closed");
         }
      }
   }
}
//+--------------------Position Management Functions----------------------------------------------+
double CalculateStopLoss(string pEntrySigal,int pSLFixedPoints,int pSLFixedPointsMA,double pMA) {
   double stopLoss = 0.0;
   double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   if(pEntrySigal == "LONG") {
      if(pSLFixedPoints > 0) {
         stopLoss = askPrice - pSLFixedPoints * _Point;
      } else if(pSLFixedPointsMA > 0) {
         stopLoss = pMA - pSLFixedPointsMA * _Point;
      }
      if(stopLoss > 0) stopLoss = AdjustBelowStopLevel(bidPrice,stopLoss);  //adjust stoploss price due to stop level
   } else if(pEntrySigal == "SHORT") {
      if(pSLFixedPoints > 0) {
         stopLoss = askPrice + pSLFixedPoints * _Point;
      } else if(pSLFixedPointsMA > 0) {
         stopLoss = pMA + pSLFixedPointsMA * _Point;
      }
      if(stopLoss > 0) stopLoss = AdjustAboveStopLevel(askPrice,stopLoss);  //adjust stoploss price due to stop level
   }
   stopLoss = round(stopLoss/tickSize)*tickSize;
   return stopLoss;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateTakeProfit(string pEntrySigal,int pTPFixedPoints) {
   double takeProfit = 0.0;
   double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   if(pEntrySigal == "LONG") {
      if(pTPFixedPoints > 0) {
         takeProfit = askPrice + pTPFixedPoints * _Point;
         if(takeProfit > 0) takeProfit = AdjustAboveStopLevel(bidPrice,takeProfit);   // adjust takeprofit price due to stop level
      }
   } else if(pEntrySigal == "SHORT") {
      if(pTPFixedPoints > 0) {
         takeProfit = askPrice - pTPFixedPoints * _Point;
         if(takeProfit > 0) takeProfit = AdjustBelowStopLevel(askPrice,takeProfit);    // adjust takeprofit price due to stop level
      }
   }
   takeProfit = round(takeProfit/tickSize)*tickSize;
   return takeProfit;
}
//+------------------------------------------------------------------+

//+---------------------------Trailing stop loss functions---------------------------------------+
void TrailingStopLoss(ulong pMagic,int pTSLFixedPoints) {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   for(int i = PositionsTotal()-1; i >= 0 ; i--) {
      ZeroMemory(request);
      ZeroMemory(result);

      ulong positionTicket = PositionGetTicket(i);
      PositionSelectByTicket(positionTicket);

      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      ulong posType = PositionGetInteger(POSITION_TYPE);
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double newStopLoss;

      if(posMagic == pMagic && posType ==ORDER_TYPE_BUY) {
         double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         newStopLoss = bidPrice - (pTSLFixedPoints * _Point);
         newStopLoss = AdjustBelowStopLevel(bidPrice,newStopLoss);   // adjust stoploss due to stop level
         newStopLoss = round(newStopLoss / tickSize)*tickSize;

         if(newStopLoss > currentStopLoss) {
            request.action = TRADE_ACTION_SLTP;
            request.position = positionTicket;
            request.comment = "TSL. "+ " | "+ _Symbol+" | "+ string(pMagic);
            request.sl = newStopLoss;

            bool sent  = OrderSend(request,result);
            if(!sent) Print("OrderSend TSL error: ",GetLastError());
         }
      } else if(posMagic == pMagic && posType == ORDER_TYPE_SELL) {
         double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         newStopLoss = askPrice + (pTSLFixedPoints * _Point);
         newStopLoss = AdjustAboveStopLevel(askPrice,newStopLoss);   // adjust stoploss due to stop level
         newStopLoss = round(newStopLoss / tickSize)*tickSize;

         if(newStopLoss < currentStopLoss) {
            request.action = TRADE_ACTION_SLTP;
            request.position = positionTicket;
            request.comment = "TSL. "+ " | "+ _Symbol+" | "+ string(pMagic);
            request.sl = newStopLoss;

            bool sent  = OrderSend(request,result);
            if(!sent) Print("OrderSend TSL error: ",GetLastError());
         }
      }
   }
}
//+------------------------------------------------------------------+
//+---------------------------Adjust stop level---------------------------------------+
double AdjustAboveStopLevel(double pCurrentPrice,double pPriceToAdjust,int pPointsToAdd = 10) {
   double adjustedPrice = pPriceToAdjust;
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   long stopsLevel = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 0) {
      double stopsLevelPrice = stopsLevel * point;
      stopsLevelPrice = pCurrentPrice + stopsLevelPrice;

      double addPoints = pPointsToAdd * point;
      if(adjustedPrice <= stopsLevelPrice + addPoints) {
         adjustedPrice = stopsLevelPrice + addPoints;
         Print("Price adjusted above stop level to "+string(adjustedPrice));
      }
   }
   return adjustedPrice;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AdjustBelowStopLevel(double pCurrentPrice,double pPriceToAdjust,int pPointsToAdd = 10) {
   double adjustedPrice = pPriceToAdjust;
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   long stopsLevel = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 0) {
      double stopsLevelPrice = stopsLevel * point;
      stopsLevelPrice = pCurrentPrice - stopsLevelPrice;

      double addPoints = pPointsToAdd * point;
      if(adjustedPrice >= stopsLevelPrice - addPoints) {
         adjustedPrice = stopsLevelPrice - addPoints;
         Print("Price adjusted below stop level to "+string(adjustedPrice));
      }
   }
   return adjustedPrice;
}
//+-----------------------Break Even-------------------------------------------+
void BreakEven(ulong pMagic,int pBEFixedPoints)
{	
	//Request and Result Declaration and Initialization
   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};
         	
	for(int i = PositionsTotal() - 1; i >= 0; i--)
	{
      //Reset of request and result values
      ZeroMemory(request);
      ZeroMemory(result);
         	   
	   ulong positionTicket = PositionGetTicket(i);
	   PositionSelectByTicket(positionTicket);

	   ulong posMagic = PositionGetInteger(POSITION_MAGIC);
	   ulong posType = PositionGetInteger(POSITION_TYPE);   
      double currentStopLoss = PositionGetDouble(POSITION_SL);   
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);	
	   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);      	   
	   double newStopLoss = round(openPrice/tickSize) * tickSize;
	   
	   if(posMagic == pMagic && posType == ORDER_TYPE_BUY)
	   {        
         double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);         
         double BEThreshold = openPrice + (pBEFixedPoints*_Point);
         
         if(newStopLoss > currentStopLoss && bidPrice > BEThreshold)
         {
            request.action = TRADE_ACTION_SLTP;
            request.position = positionTicket;
            request.comment  = "BE." + " | " + _Symbol + " | " + string(pMagic);
            request.sl = newStopLoss;
            request.tp = PositionGetDouble(POSITION_TP);
            
            bool sent = OrderSend(request,result);
      	   if(!sent) Print("OrderSend BE error: ", GetLastError());            
         }     
	   }
	   else if(posMagic == pMagic && posType == ORDER_TYPE_SELL)
	   {                 
         double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);                  
         double BEThreshold = openPrice - (pBEFixedPoints*_Point);
         
         if(newStopLoss < currentStopLoss && askPrice < BEThreshold)
         {
            request.action = TRADE_ACTION_SLTP;
            request.position = positionTicket;
            request.comment  = "BE." + " | " + _Symbol + " | " + string(pMagic);
            request.sl = newStopLoss;
            request.tp = PositionGetDouble(POSITION_TP);
            
            bool sent = OrderSend(request,result);
      	   if(!sent) Print("OrderSend BE error: ", GetLastError());
         }        
	   }    
	}
}
