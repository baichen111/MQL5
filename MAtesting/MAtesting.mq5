//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "currDirectoryTradingFunctions.mqh"
#property link      "https://github.com/baichen111"

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
      string exitSignal = MA_ExitSignal(close1,close2,ma1,ma2);         // check exit signal "EXIT_LONG" or "EXIT_SHORT"
      if(exitSignal == "EXIT_LONG" || exitSignal == "EXIT_SHORT") {
         CloseTrades(MagicNumber,exitSignal);                          // execute exit trade
      }
      Sleep(1000);

      // entry signal and trade placement
      string entrySignal = MA_EntrySignal(close1,close2,ma1,ma2);   // check entry signal "LONG" or "SHORT"
      Comment("EA #",MagicNumber," | ",exitSignal," | ",entrySignal, " SIGNAL DETECTED!");

      if((entrySignal == "LONG" || entrySignal == "SHORT") && CheckPlacedPositions(MagicNumber) == false) {    // check signal and check if any placed positions
         ulong ticket = OpenTrades(entrySignal,MagicNumber,FixedVolume);              // execute entry trade

         //SL & TP Trade modification
         if(ticket > 0) {
            double stopLoss = CalculateStopLoss(entrySignal,SLFixedPoints,SLFixedPointsMA,ma1);
            double takeProfit = CalculateTakeProfit(entrySignal,TPFixedPoints);
            TradeModification(ticket,MagicNumber,stopLoss,takeProfit);
         }
      }
      //Position Management
      if(TSLFixedPoints > 0) TrailingStopLoss(MagicNumber,TSLFixedPoints);  // trailing stop loss
      if(BEFixedPoints > 0) BreakEven(MagicNumber,BEFixedPoints);  // break even
   }
}



